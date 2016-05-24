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

require 'insensitive_hash/minimal'

require_relative 'deb822'

module Debian
  # Debian Release (repo) parser
  class Release < Deb822
    # FIXME: lazy read automatically when accessing fields
    attr_reader :fields

    Checksum = Struct.new(:sum, :size, :file_name) do
      def to_s
        "#{sum} #{size} #{file_name}"
      end
    end

    # FIXME: pretty sure that should be in the base
    def initialize(file)
      @file = file
      @fields = InsensitiveHash.new
      @spec = { mandatory: %w(),
                relationship: %w(),
                multiline: %w(md5sum sha1 sha256 sha512) }
      @spec[:foldable] = %w() + @spec[:relationship]
    end

    def parse!
      lines = ::File.new(@file).readlines
      @fields = parse_paragraph(lines, @spec)
      post_process

      # FIXME: signing verification not implemented
    end

    def dump
      output = ''
      output += dump_paragraph(@fields, @spec)
      output + "\n"
    end

    private

    def post_process
      return unless @fields

      # NB: need case sensitive here, or we overwrite the correct case with
      #     a bogus one.
      %w(MD5Sum SHA1 SHA256 SHA512).each do |key|
        @fields[key] = parse_types(fields[key], Checksum)
      end
    end

    def parse_types(lines, klass)
      lines.split($/).collect do |line|
        klass.new(*line.split(' '))
      end.unshift(klass.new)
      # Push an empty isntance in to make sure output is somewhat sane
    end
  end
end
