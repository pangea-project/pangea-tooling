require_relative 'deb822'

module Debian
  # debian/control parser
  class Control < Deb822
    attr_reader :source
    attr_reader :binaries

    def initialize
      @source = nil
      @binaries = nil
    end

    def parse!
      lines = File.new('debian/control').readlines

      # Source Paragraph
      fields = {}
      fields[:mandatory] = %w(
        source
        maintainer
      )
      fields[:relationship] = %w(
        build-depends
        build-depends-indep
        build-conflicts
        build-conflicts-indep
      )
      fields[:foldable] = ['uploaders'] + fields[:relationship]
      @source = parse_paragraph(lines, fields)

      # Binary Paragraphs
      fields = {}
      fields[:mandatory] = %w(
        package
        architecture
        description
      )
      fields[:multiline] = ['description']
      fields[:relationship] = %w(
        depends
        recommends
        suggests
        enhances
        pre-depends
        breaks
        replaces
        conflicts
        provides
      )
      fields[:foldable] = fields[:relationship]
      @binaries = []
      until lines.empty?
        data = parse_paragraph(lines, fields)
        @binaries << data if data
      end

      # TODO: Strip custom fields and add a Control::flags_for(entry) method.
    end
  end
end

class DebianControl < Debian::Control; end
