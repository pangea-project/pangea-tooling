#!/usr/bin/env ruby

require 'date'
require 'fileutils'
require 'json'
require 'net/http'
require 'timeout'

require_relative 'lib/apt'
require_relative 'lib/dpkg'
require_relative 'lib/lsb'

# TODO: remove
warn 'WARNING: kci/binarier.rb is deprecated, use lib/ci/build_binary instead' \
     ' (see nci/builder.rb for example)'

ENV['HOME'] = '/var/lib/jenkins'

Project = Struct.new(:series, :stability, :name)

$stdout = $stderr

# PWD
WORKSPACE_PATH = ARGV[1]
unless Dir.chdir(WORKSPACE_PATH)
  abort "Could not change dir to ARGV1 #{WORKSPACE_PATH}"
end

# Workaround for docker not having suidmaps. We run as root in the docker
# which will result in uid/gid of written things to be 0 rather than whatever
# jenkins has. So instead we have a fake jenkins user in the docker we can
# chmod to. This ultimately ensures that the owernship is using the uid of
# the host jenkins (equal to docker jenkins) such that we don't end up with
# stuff owned by others.
at_exit do
  FileUtils.chown_R('jenkins', 'jenkins', WORKSPACE_PATH, verbose: true)
end

dscs = Dir.glob('*.dsc')
raise "Too many dscs #{dscs}" if dscs.size > 1
raise "Too few dscs #{dscs}" if dscs.size < 1
dsc = dscs[0]

system('dpkg-source', '-x', dsc)
dirs = Dir.glob('*').select { |f| File.directory?(f) }
raise "Too many dirs #{dirs}" if dirs.size > 1
raise "Too few dirs #{dirs}" if dirs.size < 1

dir = dirs[0]

Dir.chdir(dir) do
  debline = "deb http://mobile.neon.pangea.pub #{LSB::DISTRIB_CODENAME} main"
  Apt::Repository.add(debline)
  Apt::Key.add("#{__dir__}/Pangea CI.gpg.key")
  Apt::Repository.add('ppa:plasma-phone/ppa')
  srcline = 'deb %<host>s %<series>s %<pockets>s'
  debline2 = format(srcline,
                    host: if DPKG::BUILD_ARCH == 'armhf'
                            'http://ports.ubuntu.com/ubuntu-ports'
                          else
                            'http://archive.ubuntu.com/ubuntu'
                          end,
                    series: "#{LSB::DISTRIB_CODENAME}-backports",
                    pockets: 'main restricted universe multiverse')
  Apt::Repository.add(debline2)
  Apt.update
  Apt.install('pbuilder')
  File.write('/etc/apt/apt.conf.d/debug', 'Debug::pkgProblemResolver "true";')
  system('/usr/lib/pbuilder/pbuilder-satisfydepends')
  build_args = [
    # Signing happens outside the container.
    '-us',
    '-uc',
    # Automatically decide how many concurrent build jobs we can support.
    '-jauto'
  ]
  if DPKG::BUILD_ARCH == 'amd64'
    # On arch:all only build the binaries, the source is already built.
    build_args << '-b'
  else
    # We only build arch:all on amd64, all other architectures must only build
    # architecture dependent packages. Otherwise we have confliciting checksums
    # when publishing arch:all packages of different architectures to the repo.
    build_args << '-B'
  end
  system('dpkg-buildpackage', *build_args)
end

debs = Dir.glob('*.deb')
Dir.mkdir('result/')
FileUtils.cp(debs, 'result/')
