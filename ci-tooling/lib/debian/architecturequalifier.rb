require_relative 'architecture'

module Debian
  class ArchitectureQualifier
    attr_accessor :architectures

    def initialize(architectures)
      @architectures = []
      architectures.split.each do |arch|
        @architectures << Architecture.new(arch)
      end
    end

    def qualifies?(other)
      @architectures.any? { |x| x.qualify?(other) }
    end
  end
end
