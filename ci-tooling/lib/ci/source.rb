require 'json'
require 'yaml'

require_relative 'build_version'

module CI
  # Build source descriptor
  class Source
    attr_accessor :name
    attr_accessor :version
    attr_accessor :type
    attr_accessor :dsc

    # Only used in KCIBuilder and only supported at source generation.
    # This holds the instance of CI::BuildVersion that was used to construct
    # the version information.
    attr_accessor :build_version

    def []=(key, value)
      var = "@#{key}".to_sym
      instance_variable_set(var, value)
    end

    def self.from_json(json)
      JSON.parse(json, object_class: self)
    end

    def to_json(*args)
      ret = {}
      instance_variables.each do |var|
        value = instance_variable_get(var)
        key = var.to_s
        key.slice!(0) # Nuke the @
        ret[key] = value
      end
      ret.to_json(*args)
    end

    def ==(other)
      name == other.name && version == other.version && type == other.type
    end
  end
end
