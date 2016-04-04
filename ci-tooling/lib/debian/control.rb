# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require_relative 'deb822'

module Debian
  # debian/control parser
  class Control < Deb822
    attr_reader :source
    attr_reader :binaries

    # FIXME: deprecate invocation without path
    def initialize(directory = Dir.pwd)
      @source = nil
      @binaries = nil
      @directory = directory
    end

    def parse!
      lines = File.new("#{@directory}/debian/control").readlines

      # Source Paragraph
      @source = parse_paragraph(lines, source_fields)

      # Binary Paragraphs
      @binaries = []
      until lines.empty?
        data = parse_paragraph(lines, binary_fields)
        @binaries << data if data
      end

      # TODO: Strip custom fields and add a Control::flags_for(entry) method.
    end

    def dump
      output = ''

      # Source Paragraph
      output += dump_paragraph(@source, source_fields)
      return output unless @binaries

      # Binary Paragraphs
      output += "\n"
      @binaries.each do |b|
        output += dump_paragraph(b, binary_fields)
      end

      output + "\n"
    end

    private

    def source_fields
      @source_fields ||= {}.tap do |fields|
        fields[:mandatory] = %w(source maintainer)
        fields[:relationship] = %w(
          build-depends
          build-depends-indep
          build-conflicts
          build-conflicts-indep
        )
        fields[:foldable] = ['uploaders'] + fields[:relationship]
      end
    end

    def binary_fields
      @binary_fields ||= {}.tap do |fields|
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
      end
    end
  end
end

# FIXME: deprecate
class DebianControl < Debian::Control; end
