require_relative 'deb822'

module Debian
  # Debian .changes parser
  class Changes < Deb822
    # FIXME: lazy read automatically when accessing fields
    attr_reader :fields

    File = Struct.new(:md5, :size, :section, :priority, :name)
    Checksum = Struct.new(:sum, :size, :file_name)

    def initialize(file)
      @file = file
      @fields = CaseHash.new
    end

    def parse!
      lines = ::File.new(@file).readlines

      # Source Paragraph
      fields = {
        mandatory: %w(format date source binary architecture version distribution maintainer description changes checksums-sha1 checksums-sha256 files),
        relationship: %w(),
        foldable: %w() + %w(),
        multiline: %w(description changes checksums-sha1 checksums-sha256 files)
      }
      @fields = parse_paragraph(lines, fields)

      if @fields
        if @fields['files']
          # Mangle list fields into structs.
          @fields['files'] = parse_types(@fields['files'], File)
          %w(checksums-sha1 checksums-sha256).each do |key|
            @fields[key] = parse_types(@fields[key], Checksum)
          end
        end
      end

      # FIXME: gpg
      # TODO: Strip custom fields and add a Control::flags_for(entry) method.
    end

    private

    def parse_types(lines, klass)
      lines.split($/).collect do |line|
        klass.new(*line.split(' '))
      end
    end
  end
end
