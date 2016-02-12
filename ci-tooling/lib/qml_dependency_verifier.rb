require 'logger'
require 'logger/colors'

require_relative 'apt'
require_relative 'ci/source'
require_relative 'dpkg'
require_relative 'lp'
require_relative 'lsb'
require_relative 'qml/ignore_rule'
require_relative 'qml/module'
require_relative 'qml/static_map'

# A QML dependency verifier. It verifies by installing each built package
# and verifying the deps of the installed qml files are met.
# This depends on Launchpad at the time of writing.
class QMLDependencyVerifier
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
    @log.progname = self.class.to_s
  end

  def source
    ## Read source defintion
    @source ||= CI::Source.from_json(File.read('source.json'))
  end

  def binaries
    ## Build binary package list from source defintion
    # FIXME: lots of logic dup from install_check
    ppa_base = '~kubuntu-ci/+archive/ubuntu'
    series = Launchpad::Rubber.from_path("ubuntu/#{LSB::DISTRIB_CODENAME}")
    series = series.self_link
    host_arch = Launchpad::Rubber.from_url("#{series}/#{DPKG::HOST_ARCH}")
    ppa = Launchpad::Rubber.from_path("#{ppa_base}/#{source.type}")

    sources = ppa.getPublishedSources(status: 'Published',
                                      source_name: source.name,
                                      version: source.version)
    raise 'more than one source package match on launchpad' if sources.size > 1
    raise 'no source package match on launchpad' if sources.size < 1
    source = sources[0]
    binaries = source.getPublishedBinaries
    packages = {}
    binaries.each do |binary|
      next if binary.binary_package_name.end_with?('-dbg')
      next if binary.binary_package_name.end_with?('-dev')
      if binary.architecture_specific
        next unless binary.distro_arch_series_link == host_arch.self_link
      end
      packages[binary.binary_package_name] = binary.binary_package_version
    end
    @log.info "Built package hash: #{packages}"
    # Sort packages such that * > -data > -dev to make time saved from
    # partial-autoremove most likely.
    packages.sort_by do |package, _version|
      next 2 if package.end_with?('-dev')
      next 1 if package.end_with?('-data')
      0
    end.to_h
  end

  def add_ppa
    ## Add correct PPA
    Apt.update
    Apt::Repository.new("ppa:kubuntu-ci/#{source.type}").add
    Apt.update
  end

  def missing_modules
    ## Build list of missing QML modules
    ## The notion here is that installing $package should pull in *all*
    ## qml dependencies leading to the following sequence:
    ## - Install package
    ## - Look for all .qml files in the package
    ## - Parse each line and extract module information
    ## - For each module check if it is available
    ##   - Modules can be static mapped in which case we verify its static
    ##     package is installed
    ##   - If it is not in the static map we do a path based lookup for the
    ##     module. This is limited to a list of hardcoded possible search paths
    ##   The entire thing pretty much disregards version requiements at this
    ##   time
    ## - Purge the package and purge the now autoremovable sources. This should
    ##   lead to an almost prestine environment again for the next package.
    ##   Ideally we'd spin up a new container but that appears a bit of a waste
    ##   of time.
    static_map = QML::StaticMap.new
    missing_modules = {}
    binaries.each do |package, version|
      next if package.end_with?('-dbg') || package.end_with?('-dev')
      @log.info "Checking #{package}: #{version}"
      # FIXME: need to fail otherwise, the results will be skewed
      Apt.install("#{package}=#{version}")
      Apt::Get.autoremove(args: '--purge')

      ignores = []
      ignore_file = "packaging/debian/#{package}.qml-ignore"
      ignores = QML::IgnoreRule.read(ignore_file) if File.exist?(ignore_file)

      files = DPKG.list(package).select { |f| File.extname(f) == '.qml' }

      # TODO: THREADING!

      modules = []
      files.each do |file|
        modules += QML::Module.read_file(file)
      end
      @log.info "Imported modules: #{modules}"

      modules.each do |mod|
        next if ignores.include?(mod)
        found = false
        static_package = static_map.package(mod)
        if static_package
          # FIXME: move to dpkg module
          # FIXME: instead of calling -s this probably should manually check
          #   /var/lib/dpkg/info as -s is rather slow
          if static_package == 'fake-global-ignore'
            found = true
          else
            found = system("dpkg -s #{static_package} 2>&1 > /dev/null")
          end
        else
          # FIXME: beyond path this currently doesn't take version into account
          QML::SEARCH_PATHS.each do |search_path|
            mod.import_paths.each do |import_path|
              path = File.join(search_path, import_path, 'qmldir')
              @log.info "Looking in #{path}"
              found = File.exist?(path) && File.file?(path)
              @log.info "  #{found}"
              break if found
            end
            break if found
          end
        end
        next if found
        missing_modules[package] ||= []
        missing_modules[package] << mod
      end

      # FIXME: need to fail otherwise, the results will be skewed
      Apt.purge(package)
    end
    @log.info 'Done looking for missing modules'
    @log.info missing_modules
    missing_modules
  end
end
