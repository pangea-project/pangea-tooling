#!/usr/bin/env ruby

require 'date'
require 'fileutils'
require 'json'
require 'net/http'
require 'open-uri'
require 'timeout'

require_relative 'lib/apt'
require_relative 'lib/dpkg'
require_relative 'lib/lsb'

$stdout = $stderr

dscs = Dir.glob('*.dsc')
if dscs.size > 1
  fail "Too many dscs #{dscs}"
elsif dscs.size < 1
  fail "Too few dscs #{dscs}"
end
dsc = dscs[0]

system('dpkg-source', '-x', dsc)
dirs = Dir.glob('*').select { |f| File.directory?(f) }
if dirs.size > 1
  fail "Too many dirs #{dirs}"
elsif dirs.size < 1
  fail "Too few dirs #{dirs}"
end
dir = dirs[0]

Dir.chdir(dir) do
  debline = "deb http://archive.neon.kde.org.uk/unstable #{LSB::DISTRIB_CODENAME} main"
  Apt::Repository.add(debline)
  # FIXME: this needs to be in the module!
  IO.popen(['apt-key', 'add', '-'], 'w') do |io|
    io.puts open('http://archive.neon.kde.org.uk/public.key').read
    io.close_write
    puts io
  end
  abort 'Failed to import key' unless $? == 0
  Apt.update
  Apt.install('pkg-kde-tools')

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
