#!/usr/bin/env ruby

require 'date'
require 'fileutils'
require 'json'
require 'timeout'
require 'net/http'

require_relative 'lib/apt'
require_relative 'lib/ci/build_version'
require_relative 'lib/debian/changelog'
require_relative 'lib/lsb'

ENV['HOME'] = '/var/lib/jenkins'

Project = Struct.new(:series, :stability, :name)

$stdout = $stderr

# get basename, distro series, unstable/stable
p ARGV
components = ARGV[0].split('_')
p components
unless components.size == 4
  abort 'Did not get a valid project identifier via ARGV0'
end
project = Project.new(components[0], components[1], components[2])

# PWD
abort 'Could not change dir to ARGV1' unless Dir.chdir(ARGV[1])

WORKSPACE_PATH = ARGV[1]

# Workaround for docker not having suidmaps. We run as root in the docker
# which will result in uid/gid of written things to be 0 rather than whatever
# jenkins has. So instead we have a fake jenkins user in the docker we can
# chmod to. This ultimately ensures that the owernship is using the uid of
# the host jenkins (equal to docker jenkins) such that we don't end up with
# stuff owned by others.
at_exit do
  FileUtils.chown_R('jenkins', 'jenkins', WORKSPACE_PATH, verbose: true)
end

# version
changelog = Changelog.new('packaging')
version = CI::BuildVersion.new(changelog)
source_name = changelog.name

FileUtils.rm_r('build') if File.exist?('build')
FileUtils.mkpath('build/source/')

# copy upstream sources around
if Dir.exist?('source') && !Dir.glob('source/*').empty?
  abort 'Failed to copy source' unless system('cp -r source/* build/source/')
  Dir.chdir('build/source') do
    FileUtils.rm_rf(Dir.glob('**/.bzr'))
    FileUtils.rm_rf(Dir.glob('**/.git'))
    FileUtils.rm_rf(Dir.glob('**/.svn'))
  end

  # create orig tar
  Dir.chdir('build/') do
    tar = "#{source_name}_#{version.tar}.orig.tar"
    abort 'Failed to create a tarball' unless system("tar -cf #{tar} source")
    abort 'Failed to compress the tarball' unless system("xz -1 #{tar}")
  end

  # Copy packaging
  unless system('cp -r packaging/debian build/source/')
    abort 'Failed to copy packaging'
  end
else
  # This is a native package as we have no upstream source directory.
  # TODO: quite possibly this should be porperly validated via source format and
  #       or changelog version format.
  unless system('cp -r packaging/* build/source/')
    abort 'Failed to copy packaging'
  end
end

# Create changelog entry
Dir.chdir('build/source/') do
  env = {
    'DEBFULLNAME' => 'Kubuntu CI',
    'DEBEMAIL' => 'kubuntu-ci@lists.launchpad.net'
  }
  args = []
  args << '-b'
  args << '-v' << version.full
  args << '-D' << project.series
  args << '"Automatic Kubuntu Build"'
  abort 'Failed to create changelog entry' unless system(env, 'dch', *args)
end

# Rip out locale install
Dir.chdir('build/source/') do
  Dir.glob('debian/*.install').each do |install_file_path|
    # Strip localized manpages
    # e.g.  usr /share /man /  *  /man 7 /kf5options.7
    man_regex = %r{^.*usr/share/man/(\*|\w+)/man\d/.*$}
    subbed = File.open(install_file_path).read.gsub(man_regex, '')
    File.open(install_file_path, 'w') do |f|
      f << subbed
    end

    # FIXME: bloody workaround for kconfigwidgets and kdelibs4support containing
    # legit locale data
    next if source_name == 'kconfigwidgets' || source_name == 'kdelibs4support'
    locale_regex = %r{^.*usr/share/locale.*$}
    subbed = File.open(install_file_path).read.gsub(locale_regex, '')
    File.open(install_file_path, 'w') do |f|
      f << subbed
    end
  end
  # If the package is now empty, lintian override the empty warning to avoid
  # false positives
  Dir.glob('debian/*.install').each do | install_file_path |
    next unless File.open(install_file_path, 'r').read.strip.empty?
    package_name = File.basename(install_file_path, '.install')
    lintian_overrides_path = install_file_path.gsub('.install',
                                                    '.lintian-overrides')
    puts "#{package_name} is now empty, trying to add lintian override"
    File.open(lintian_overrides_path, 'a') do |file|
      file.write("#{package_name}: empty-binary-package\n")
    end
  end
  # Rip out symbol files, we don't care about them for now.
  symbols = Dir.glob('debian/symbols') +
            Dir.glob('debian/*.symbols') +
            Dir.glob('debian/*.symbols.*')
  symbols.each { |s| FileUtils.rm(s) }
end

# dpkg-buildpackage
Dir.chdir('build/source/') do
  debline = "deb http://46.101.170.116 #{LSB::DISTRIB_CODENAME} main"
  Apt::Repository.add(debline)
  Net::HTTP.start('46.101.170.116') do |http|
    response = http.get('/Pangea CI.gpg.key')
    File.open('/tmp/key', 'w') do |file|
      file.write(response.body)
    end
  end
  Apt::Key.add('/tmp/key')
  Apt::Repository.add('ppa:plasma-phone/ppa')
  if DPKG::BUILD_ARCH == 'armhf'
    debline2 = "deb http://ports.ubuntu.com/ubuntu-ports #{LSB::DISTRIB_CODENAME}-backports main restricted universe multiverse"
  else
    debline2 = "deb http://archive.ubuntu.com/ubuntu #{LSB::DISTRIB_CODENAME}-backports main restricted universe multiverse"
  end
  Apt::Repository.add(debline2)
  Apt.update

  # Install some minimal build dependencies to make sure we can get past the
  # clean step
  Apt.install(%w(dh-autoreconf dh-acc pkg-kde-tools germinate dh-translations pbuilder))
  system('update-maintainer')
  system('/usr/lib/pbuilder/pbuilder-satisfydepends')
  unless system('dpkg-buildpackage -us -uc -S')
    abort 'Failed to build source package'
  end
end

# Write upload data to file, we perhaps want to do something outside
# build container.
data = { name: changelog.name,
         version: changelog.version,
         type: project.stability }
File.write('source.json', JSON.generate(data))
