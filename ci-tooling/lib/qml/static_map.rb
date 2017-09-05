require 'yaml'

require_relative 'module'

module QML
  # Statically maps specific QML modules to fixed packages.
  class StaticMap
    @base_dir = File.expand_path("#{__dir__}/../../")
    @data_file = File.join(@base_dir, 'data', 'qml-static-map.yml')

    class << self
      # @return [String] path to the yaml data file with mapping information
      attr_accessor :data_file
    end

    def initialize(data_file = nil)
      data_file ||= self.class.data_file
      data = YAML.load(File.read(data_file))
      return if data.nil? || !data || data.empty?
      parse(data)
    end

    # Get the mapped package for a QML module, or nil.
    # @param qml_module [QML::Module] module to map to a package. Do note that
    #   version is ignored if the reference map has no version defined. Equally
    #   qualifier is entirely ignored as it has no impact on mapping
    # @return [String, nil] package name if it maps to a package statically
    def package(qml_module)
      # FIXME: kinda slow, perhaps the interal structures should change to
      # allow for faster lookup
      @hash.each do |mod, package|
        next unless mod.identifier == qml_module.identifier
        next unless version_match?(mod.version, qml_module.version)
        return package
      end
      nil
    end

    private

    def version_match?(constraint, version)
      # If we have a fully equal match we are happy (this can be both empty.)
      return true if constraint == version
      # Otherwise we'll want a version to verify aginst.
      return false unless version
      Gem::Dependency.new('', constraint).match?('', version)
    end

    def parse_module(mod)
      return QML::Module.new(mod) if mod.is_a?(String)
      mod.each do |name, version|
        return QML::Module.new(name, version)
      end
    end

    def parse(data)
      @hash = {}
      data.each do |package, modules|
        modules.each do |mod|
          qml_mod = parse_module(mod)
          @hash[qml_mod] = package
        end
      end
    end
  end
end
