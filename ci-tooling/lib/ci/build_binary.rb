require 'fileutils'

require_relative 'source'
require_relative '../dpkg'
require_relative '../os'
require_relative '../retry'

module CI
  class PackageBuilder
    BUILD_DIR  = 'build'.freeze
    RESULT_DIR = 'result'.freeze

    class DependencyResolver
      RESOLVER_BIN = '/usr/lib/pbuilder/pbuilder-satisfydepends'.freeze

      def self.resolve(dir)
        unless File.executable?(RESOLVER_BIN)
          raise "Can't find #{RESOLVER_BIN}!"
        end

        Retry.retry_it(times: 5) do
          system('sudo', RESOLVER_BIN, '--control', "#{dir}/debian/control")
          raise 'Failed to satisfy depends' unless $? == 0
        end
      end
    end

    def extract
      FileUtils.rm_rf(BUILD_DIR, verbose: true)
      unless system('dpkg-source', '-x', @dsc, BUILD_DIR)
        raise 'Something went terribly wrong with extracting the source'
      end
    end

    def build_package
      # FIXME: buildpackage probably needs to be a method on the DPKG module
      #   for logging purposes and so on and so forth
      dpkg_buildopts = [
        # Signing happens outside the container. So disable all signing.
        '-us',
        '-uc'
      ]
      # Automatically decide how many concurrent build jobs we can support.
      # NOTE: special cased for trusty master servers to pass
      dpkg_buildopts << '-j1' unless pretty_old_system?

      if DPKG::BUILD_ARCH == 'amd64'
        # On arch:all only build the binaries, the source is already built.
        dpkg_buildopts << '-b'
      else
        # We only build arch:all on amd64, all other architectures must only
        # build architecture dependent packages. Otherwise we have confliciting
        # checksums when publishing arch:all packages of different architectures
        # to the repo.
        dpkg_buildopts << '-B'
      end

      Dir.chdir(BUILD_DIR) do
        system('dpkg-buildpackage', *dpkg_buildopts)
      end
    end

    def print_contents
      Dir.chdir(RESULT_DIR) do
        debs = Dir.glob('*.deb')
        debs.each do |deb|
          system('lesspipe', deb)
        end
      end
    end

    def copy_binaries
      Dir.mkdir(RESULT_DIR) unless Dir.exist?(RESULT_DIR)
      changes = Dir.glob("#{BUILD_DIR}/../*.changes")

      changes.select! { |e| !e.include? 'source.changes' }

      unless changes.size == 1
        raise "Not exactly one changes file WTF -> #{changes}"
      end

      system('dcmd', 'cp', '-v', *changes, 'result/')
    end

    def build
      raise 'Not exactly one dsc!' unless Dir.glob('*.dsc').count == 1

      @dsc = Dir.glob('*.dsc')[0]

      extract
      DependencyResolver.resolve(BUILD_DIR)

      build_package
      copy_binaries
      print_contents
    end

    private

    def pretty_old_system?
      OS::VERSION_ID == '14.04'
    rescue
      false
    end
  end
end
