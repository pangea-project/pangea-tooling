require 'date'
require 'fileutils'
require 'optparse'
require 'json'
require 'tmpdir'
require_relative '../lib/debian/changelog'
require_relative '../lib/debian/control'
require_relative '../lib/debian/source'
require_relative '../lib/logger'
require_relative '../lib/dci'
require_relative '../lib/ci/build_version'

abort 'No workspace dir defined!' unless ARGV[1]

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: dci.rb build -c repo1,repo2 file.changes'
  opts.on('-r r1,r2,r3', '--repos REPOS', Array,
          'Comma separated repos to add to the schroot before build') do |repos|
    options[:repos] = repos
  end

  opts.on('-w dir', '--workspace dir',
          'Workspace dir to find repository mappings') do |dir|
    options[:workspace] = dir
  end

  opts.on('-R release', '--release release', 'Build for release') do |release|
    options[:release] = release
  end
end.parse!

abort 'Release is not optional!' unless options[:release]

logger = DCILogger.instance

logger.info("Arguments passed were #{ARGV}")
logger.info("Parsed #{options}")

logger.info("Adding custom repos #{options[:repos]}")

# Skip if there is only one repo in the options, since thats the 'default'
#   config
# FIXME: This is a workaround till I figure out how to make ruby parse empty
#   values for options
if !options[:repos].nil? && options[:repos].count > 1
  extra_file = '/etc/apt/sources.list.d/extra_repos.list'
  File.delete(extra_file) if File.exist?(extra_file)

  Dir.chdir(options[:workspace]) do
    EXTRA_REPOS = 'extra_repos.json'
    next unless File.exist? EXTRA_REPOS
    extra_repos = JSON.parse(File.read(EXTRA_REPOS))
    options[:repos].each do |repo|
      # Default repos are ignored since they should already be in the chroot
      next if repo == 'default'
      url = extra_repos[repo]['url']
      key = extra_repos[repo]['key']
      system("echo 'deb #{url} #{package_release} main' >> #{extra_file}")
      system("echo '#{key}' | apt-key add -")
      logger.info("Added deb #{url} #{package_release} main to the sources")
    end
  end
end

# These should never fail
dci_run_cmd('apt-get update && apt-get -y dist-upgrade')
packages = %w(
  devscripts
  lsb-release
  locales
  libdistro-info-perl
  pbuilder
  aptitude
)
dci_run_cmd("apt-get -y install #{packages}")

Dir.chdir(ARGV[1]) do
  # Get source name and what not

  PACKAGING_DIR = 'packaging'
  source_dir = 'source'
  s = nil
  Dir.chdir(PACKAGING_DIR) do
    s = Debian::Source.new(Dir.pwd)
    logger.info "Building package of #{s.format.type} type"
    source_dir = PACKAGING_DIR if s.format.type == :native
  end

  unless defined? PACKAGING_DIR
    fail 'Source contains packaging but is not a native package'
  end

  cl = nil
  Dir.chdir(PACKAGING_DIR) do
    cl = Changelog.new
    system('/usr/lib/pbuilder/pbuilder-satisfydepends')
    fail "Can't install build deps!" unless $?.success?
  end

  source_name = cl.name
  bv = CI::BuildVersion.new(cl)
  version = bv.full
  version = bv.base if s.format.type == :native

  Dir.chdir(source_dir) do
    FileUtils.rm_rf(Dir.glob('**/.bzr'))
    FileUtils.rm_rf(Dir.glob('**/.git'))
    FileUtils.rm_rf(Dir.glob('**/.svn'))
    FileUtils.rm_rf(Dir.glob('**/debian'))
  end

  # create orig tar
  tar = "#{source_name}_#{bv.tar}.orig.tar"
  File.delete(tar) if File.exist? tar
  unless system("tar -cf #{tar} #{source_dir}")
    fail 'Failed to create a tarball'
  end
  fail 'Failed to compress the tarball' unless system("xz -6 #{tar}")

  if s.format.type == :quilt
    system("cp -aR #{PACKAGING_DIR}/debian #{source_dir}")
  end

  Dir.chdir(source_dir) do
    env = { 'DEBFULLNAME' => 'Debian CI',
            'DEBEMAIL' => 'null@debian.org' }
    cmd = "dch -b -v #{version} -D #{options[:release]}" \
          " 'Automatic Debian Build'"
    fail 'Failed to create changelog entry' unless system(env, cmd)
    # Rip out locale install and upstream patches
    Dir.glob('debian/*.install').each do |install_file_path|
      # Strip localized manpages
      # e.g.  usr /share /man /  *  /man 7 /kf5options.7
      man_regex = %r{^.*usr/share/man/(\*|\w+)/man\d/.*$}
      subbed = File.open(install_file_path).read.gsub(man_regex, '')
      File.open(install_file_path, 'w') do |f|
        f << subbed
      end

      # FIXME: bloody workaround for kconfigwidgets and kdelibs4support
      # containing legit locale data
      next if %w(kconfigwidgets kdelibs4support).include?(source_name)
      locale_regex = %r{^.*usr/share/locale.*$}
      subbed = File.open(install_file_path).read.gsub(locale_regex, '')
      File.open(install_file_path, 'w') do |f|
        f << subbed
      end
    end

    # If the package is now empty, lintian override the empty warning to avoid
    # false positives
    Dir.glob('debian/*.install').each do |install_file_path|
      next unless File.open(install_file_path, 'r').read.strip.empty?
      package_name = File.basename(install_file_path, '.install')
      lintian_overrides_path = install_file_path.gsub('.install',
                                                      '.lintian-overrides')
      logger.info("#{package_name} is now empty, trying to add lintian" \
                   ' override')
      File.open(lintian_overrides_path, 'a') do |file|
        file.write("#{package_name}: empty-binary-package\n")
      end
    end

    # Rip out upstream patches
    if File.exist? 'debian/patches/series'
      series = File.read('debian/patches/series')
      series.gsub!(/^upstream_.*/, '')
      File.write('debian/patches/series', series)
    end

    # Rip out symbols files
    # Symbol tracking is done in Kubuntu CI
    # FIXME: Take debian/symbols into account too
    Dir.glob('debian/*.symbols*').each do |f|
      File.delete(f)
    end
  end

  Dir.mktmpdir do |dir|
    FileUtils.cp_r("#{ARGV[1]}/#{source_dir}", dir)
    FileUtils.cp_r("#{tar}.xz", dir)
    Dir.chdir("#{dir}/#{source_dir}") do
      # dpkg-buildpackage
      unless system('dpkg-buildpackage -S -uc -us')
        fail 'Failed to build source package'
      end
    end

    Dir.chdir(dir) do
      system("dcmd mv #{source_name}*_source.changes /build/")
      system("dcmd chmod 666 /build/#{source_name}*_source.changes")
    end
  end
end

logger.close
