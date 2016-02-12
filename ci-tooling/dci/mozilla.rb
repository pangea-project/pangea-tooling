require_relative '../lib/logger'
require_relative '../lib/debian/changelog'
require_relative '../lib/debian/control'
require_relative '../lib/dci'

require 'open-uri'
require 'thwait'
require 'date'

raise 'Need a mozilla product to build for!' unless ARGV[1]
raise 'Need a release to build for!' unless ARGV[2]

@logger = DCILogger.instance

PACKAGE = ARGV[1]

@logger.info("Building #{PACKAGE}")

def package_releases
  require 'nokogiri'
  threads = []
  ubuntu_versions = []
  upstream_versions = []

  threads << Thread.new do
    # Find the latest release from the Mozilla releases page
    begin
      doc_url = "https://www.mozilla.org/en-US/#{PACKAGE}/releases"
      doc = Nokogiri::HTML(open(doc_url))
    rescue
      sleep 30
      retry
    end

    doc.css('li').each do |node|
      text = node.text
      match_data = text.match('(\d+[.]\d+)')
      upstream_versions << match_data.string.to_f unless match_data.nil?
    end

    upstream_versions.uniq!
    upstream_versions.sort!
    @logger.info("Upstream #{upstream_versions}")
  end

  threads << Thread.new do
    rmadison = `rmadison -u ubuntu -a amd64 -s #{RELEASE} #{PACKAGE}`
    rmadison.to_str.each_line do |line|
      match_data = line.match('(\d+[.]\d+)')
      ubuntu_versions << match_data[0].to_f unless match_data.nil?
    end

    # Make sure we take the updates suite into account too
    rmadison = `rmadison -u ubuntu -a amd64 -s #{RELEASE}-updates #{PACKAGE}`
    rmadison.to_str.each_line do |line|
      match_data = line.match('(\d+[.]\d+)')
      ubuntu_versions << match_data[0].to_f unless match_data.nil?
    end

    ubuntu_versions.uniq!
    ubuntu_versions.sort!
    @logger.info("Ubuntu #{ubuntu_versions}")
  end

  ThreadsWait.all_waits(threads)
  { ubuntu: ubuntu_versions[-1], upstream: upstream_versions[-1] }
end

def bump_version
  changelog = Changelog.new
  changelog_epoch = changelog.version(Changelog::EPOCH)
  changelog_base = changelog.version(Changelog::BASE)
  version = "#{changelog_epoch}1000~#{changelog_base}"
  # Need to check if the original release is a debian release
  if (DEBIAN_RELEASES.include? ARGV[2]) && (PACKAGE == 'firefox')
    version += '-1'
    File.open('debian/config/mozconfig.in', 'a') do |f|
      f.puts("ac_add_options --enable-gstreamer=1.0\n")
    end
  else
    version += '-0ubuntu1'
  end
  version += "~#{DateTime.now.strftime('%Y%m%d.%H%M')}"
  @logger.info("New version is going to be #{version}")
  `dch -v "#{version}" "[CI Build] #{PACKAGE} with KDE integration"`

  new_changelog = Changelog.new
  # Rename orig
  new_changelog_base = new_changelog.version(Changelog::BASE)
  File.rename("../#{PACKAGE}_#{changelog_base}.orig.tar.bz2",
              "../#{PACKAGE}_#{new_changelog_base}.orig.tar.bz2")
end

def install_kde_js
  @logger.info('Modifying debian/rules')
  rules = File.read('debian/rules')
  rules.gsub!(/pre-build.*$/) do |m|
    m += "\n\tmkdir -p $(MOZ_DISTDIR)/bin/defaults/pref/\n\tcp $(CURDIR)/debian/kde.js $(MOZ_DISTDIR)/bin/defaults/pref/kde.js"
  end
  File.write('debian/rules', rules)
end

def add_dummy_package
  # Add dummy package
  control = File.read('debian/control.in')
  control += "\nPackage: @MOZ_PKG_NAME@-plasma
Architecture: any
Depends: @MOZ_PKG_NAME@ (= ${binary:Version}), mozilla-kde-support
Description: #{PACKAGE} package for integration with KDE
 Install this package if you'd like #{PACKAGE} with Plasma integration
"
  File.write('debian/control.in', control)
  system('debian/rules debian/control')

  File.open("debian/#{PACKAGE}-plasma.pref", 'w') do |f|
    f.puts("Package: *
Pin: release o=LP-PPA-plasmazilla-builds
Pin-Priority: 1000

Package: *
Pin: release o=LP-PPA-plasmazilla-releases
Pin-Priority: 1000
")
  end

  File.open("debian/#{PACKAGE}-plasma.install", 'w') do |f|
    f.puts("debian/#{PACKAGE}-plasma.pref etc/apt/preferences.d/")
  end
end

def build_firefox(release_info)
  release_version = release_info[:ubuntu].to_i
  hg_url = "http://www.rosenauer.org/hg/mozilla/#firefox#{release_version}"
  system("hg clone #{hg_url} suse")
  raise 'Could not clone mercurial repo!' unless $?.success?

  firefox_dir = Dir['firefox-*'][0]
  Dir.chdir(firefox_dir) do
    bump_version

    `cp ../suse/firefox-kde.patch ../suse/mozilla-kde.patch debian/patches/`
    `cp ../suse/MozillaFirefox/kde.js debian/`

    system('quilt pop -a')
    # Need to remove unity menubar from patches first since it interferes with
    # the KDE patches
    system('quilt delete unity-menubar.patch')

    @logger.info('Adding Firefox KDE patches')
    File.open('debian/patches/series', 'a') do |f|
      # Please preserve this order of patch
      f.puts("mozilla-kde.patch\nfirefox-kde.patch\nunity-menubar.patch\n")
    end

    system('quilt push -fa')
    system('quilt refresh')

    # Make sure marking firefox for upgrade, also upgrades the langpack
    langpack = File.read('debian/control.langpacks')
    langpack.gsub!(/Depends:.+/, '\0, @MOZ_PKG_NAME@ (>= ${source:Version}), @MOZ_PKG_NAME@ (<< ${source:Version}.1~)')
    File.write('debian/control.langpacks', langpack)

    install_kde_js
    add_dummy_package
  end
end

def build_thunderbird(_release_info)
  thunderbird_dir = Dir['thunderbird-*'][0]
  Dir.chdir(thunderbird_dir) do
    bump_version

    patch_path = 'debian/patches/mozilla-kde.patch'
    open(patch_path, 'wb') do |file|
      file << open('https://build.opensuse.org/source/openSUSE:Factory/MozillaThunderbird/mozilla-kde.patch').read
    end
    filterdiff = `filterdiff --addprefix=a/mozilla/ --strip 1 #{patch_path}`
    system('quilt pop -fa')
    File.write('debian/patches/mozilla-kde.patch', filterdiff)
    File.write('debian/patches/series', "mozilla-kde.patch\n", mode: 'a')
    system('quilt push -fa')
    system('quilt refresh')

    open('debian/kde.js', 'wb') do |file|
      file << open('https://build.opensuse.org/source/openSUSE:Factory/MozillaThunderbird/kde.js').read
    end
    install_kde_js
    add_dummy_package
  end
end

dci_run_cmd('apt-get update')
packages = %w(ubuntu-dev-tools mercurial ruby-nokogiri distro-info cdbs
              debhelper)
system("apt-get -y install #{packages.join(' ')}")

# TODO: Fix the control file parser to take optional build-deps into account
# control = DebianControl.new
# control.parse!
# build_depends = []
# control.source['build-depends'].each do |dep|
#     build_depends << dep.name
# end
# unless system("apt-get -y install #{build_depends.join(' ')}")
#   fail 'Failed to install build deps!'
# end

UBUNTU_RELEASES = `ubuntu-distro-info -a`.split
DEBIAN_RELEASES = `debian-distro-info -a`.split

# Take the stable release, not the dev release from Ubuntu
RELEASE = (DEBIAN_RELEASES.include? ARGV[2]) ? UBUNTU_RELEASES[-2] : ARGV[2]

release_info = package_releases
if release_info[:ubuntu] < release_info[:upstream]
  @logger.warn("Building #{PACKAGE} while Ubuntu hasn't updated the package!")
end

`rm -rf build`
Dir.mkdir('build')
Dir.chdir('build') do
  dci_run_cmd("pull-lp-source -m http://127.0.0.1:3142/ubuntu #{PACKAGE}" \
              " #{RELEASE}")

  build_firefox(release_info) if PACKAGE == 'firefox'
  build_thunderbird(release_info) if PACKAGE == 'thunderbird'

  src_dir = Dir["#{PACKAGE}-*"][0]
  Dir.chdir(src_dir) do
    `dch --release --distribution #{ARGV[2]} ""`
    # Needs full source upload because version 1000 doesn't exist in Ubuntu
    dci_run_cmd('dpkg-buildpackage -S -sa -uc -us -d')
  end
  system("dcmd cp #{PACKAGE}*.changes /build/")
end
