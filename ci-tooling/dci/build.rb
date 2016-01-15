require 'tmpdir'
require 'fileutils'
require 'optparse'
require 'json'
require_relative '../lib/debian/control'
require_relative '../lib/logger'
require_relative '../lib/dci'

## Some notes :
##      * All builds happen in /tmp/<tmp dir>
##      * All resulting debs are put in /build/
##      * Copy resulting files using dcmd cp /build/*/package_name*.changes

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
end.parse!

RESULT_DIR = '/build/'

logger = DCILogger.instance

dpkg_buildopts = %w(-us -uc -sa)
dpkg_buildopts << '-B' unless RbConfig::CONFIG['host_cpu'] == 'x86_64'

if !ARGV[1].end_with? '.changes'
  logger.fatal("#{ARGV[1]} is not an actual changes file. Abort!")
else
  package_name = `grep Source #{ARGV[1]}`.split(':')[-1].strip
  # package_version = `grep Version #{ARGV[1]}`.split(':')[-1].strip
  package_release = `grep Distribution #{ARGV[1]}`.split(':')[-1].strip

  logger.info("Starting build for #{package_name}")
  logger.info("Adding custom repos #{options[:repos]}")
  # Skip if there is only one repo in the options, since
  # thats the 'default' config
  # FIXME: This is a workaround till I figure out how to make ruby parse
  # empty values for options
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

  logger.info('Updating chroot')
  dci_run_cmd('apt-get update')
  system('apt-get -y dist-upgrade')

  logger.info('Installing some extra tools')
  packages = %w(
    aptitude
    devscripts
    pbuilder
    ubuntu-dev-tools
    libdistro-info-perl
  )
  system("apt-get -y install #{packages}")

  logger.info('Extracting source')
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      fail "Can't copy changes!" unless system("dcmd cp -v #{ARGV[1]} #{dir}")
      fail "Can't extract dsc!" unless system('dpkg-source -x *.dsc')

      package_folder = Dir.glob("#{package_name}*").select do |fn|
        File.directory?(fn)
      end
      Dir.chdir(package_folder[0]) do
        system('/usr/lib/pbuilder/pbuilder-satisfydepends')
        fail "Can't install build deps!" unless $?.success?
        logger.info('Finished installing build deps')

        logger.info('Start building the package')
        system("dpkg-buildpackage -jauto #{dpkg_buildopts.join(' ')}")
        if RbConfig::CONFIG['host_cpu'] == 'x86_64'
          system('dh_install --fail-missing')
          logger.error('Not all files have been installed!') unless $?.success?
        end
      end
      FileUtils.mkdir_p(RESULT_DIR) unless Dir.exist? RESULT_DIR
      changes_files = Dir.glob('*changes').select do |changes|
        !changes.end_with? '_source.changes'
      end

      logger.warn('No changes file found!') if changes_files.empty?

      changes_files.each do |changes_file|
        logger.info("Copying #{changes_file} ...")
        system("dcmd chmod 666 #{changes_file}")
        logger.info('Running lintian checks ...')

        # Lintian checks
        if RbConfig::CONFIG['host_cpu'] == 'x86_64'
          system('lintian -iI --pedantic --show-overrides --color auto ' \
                 "#{changes_file}")
          logger.warn('Lintian check failed!') unless $?.success?
          logger.info('Finished running lintian checks')
        end

        # Content of debs
        logger.info('Contents of debs')
        Dir.glob('*.deb') do |deb|
          system("lesspipe #{deb}")
        end

        system("dcmd mv #{changes_file} #{RESULT_DIR}")
        system("chmod 2770 #{RESULT_DIR}") unless File.stat(RESULT_DIR).setgid?
      end
      logger.info('Build finished!')
    end
  end
end

logger.close
