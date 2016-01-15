require_relative 'module'

module QML
  # Sepcifies an ignore rule for a qml module.
  class IgnoreRule
    # Identifier of the rule. This is a {File#fnmatch} pattern.
    attr_reader :identifier
    attr_reader :version

    # Checks whether this ignore rule matches an input {Module}.
    # An ignore rule matches if:
    # - {IgnoreRule#identifier} matches {Module#identifier}
    # - {IgnoreRule#version} is nil OR matches {Module#version}
    # @param qml_module [QML::Module] module to check for ignore match
    def ignore?(qml_module)
      match_version?(qml_module) && match_identifier?(qml_module)
    end

    # @return [Array<QML::IgnoreRule>] array of ignore rules read from path
    def self.read(path)
      rules = File.read(path).split($/)
      rules.collect! do |line|
        line = line.split('#')[0]
        next if line.nil? || line.empty?
        parts = line.split(/\s+/)
        next unless parts.size.between?(1, 2)
        new(*parts)
      end
      rules.compact
    end

    # Helper overload for {Array#include?} allowing include? checks with a
    # {Module} resulting in {#ignore?} checks of the rule (i.e. Array#include?
    # is equal to iterating over the array and calling ignore? on all rules).
    # If the rule is compared to anything but a {Module} instance it will
    # yield to super.
    def ==(other)
      return ignore?(other) if other.is_a?(QML::Module)
      super(other)
    end

    private

    def initialize(identifier, version = nil)
      @identifier = identifier
      @version = version
      unless @version.nil? || @version.is_a?(String)
        fail 'Version must either be nil or a string'
      end
      return unless @identifier.nil? || @identifier.empty?
      fail 'No valid identifier set. Needs to be a string and not empty'
    end

    def match_version?(qml_module)
      @version.nil? || @version == qml_module.version
    end

    def match_identifier?(qml_module)
      File.fnmatch(@identifier, qml_module.identifier)
    end
  end
end
