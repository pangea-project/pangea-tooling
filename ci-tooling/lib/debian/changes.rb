# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
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
  # Debian .changes parser
  class Changes < Deb822
    # FIXME: lazy read automatically when accessing fields
    attr_reader :fields

    File = Struct.new(:md5, :size, :section, :priority, :name)
    Checksum = Struct.new(:sum, :size, :file_name)

    # FIXME: pretty sure that should be in the base
    def initialize(file)
      @file = file
      @fields = InsensitiveHash.new
    end

    def parse!
      lines = ::File.new(@file).readlines

      # Source Paragraph
      fields = {
        mandatory: %w(format date source binary architecture version distribution maintainer description changes checksums-sha1 checksums-sha256 files),
        relationship: %w(),
        foldable: %w(binary) + %w(),
        multiline: %w(description changes checksums-sha1 checksums-sha256 files)
      }
      @fields = parse_paragraph(lines, fields)
      mangle_fields! if @fields

      # TODO: Strip custom fields and add a Control::flags_for(entry) method.

      # FIXME: signing verification not implemented
      #   this code works; needs to be somewhere generic
      #   also needs to rescue GPGME::Error::NoData
      #   in case the file is not signed
      # crypto = GPGME::Crypto.new
      # results = []
      # crypto.verify(data) do |signature|
      #   results << signature.valid?
      #
      # !results.empty? && results.all?
    end

    private

    def mangle_files
      # Mangle list fields into structs.
      # FIXME: this messes up field order, files and keys will be appended
      # to the hash as injecting new things into the hash does not
      # replace the old ones in-place, but rather drops the old ones and
      # adds the new ones at the end.
      @fields['files'] = parse_types(@fields['files'], File)
      %w(checksums-sha1 checksums-sha256).each do |key|
        @fields[key] = parse_types(@fields[key], Checksum)
      end
    end

    def mangle_binary
      # FIXME: foldable fields are arrays but their values are split by
      # random crap such as commas or spaces. In changes Binary is a
      # foldable field separated by spaces, so we need to make sure this
      # is the case.
      # This is conducted in-place so we don't mess up field order.
      @fields['binary'].replace(@fields['binary'][0].split(' '))
    end

    # Calls all defined mangle_ methods. Mangle methods are meant to suffix
    # the field they mangle. They only get run if that field is in the hash.
    # So, mangle_binary checks the Binary field and is only run when it is
    # defined in the hash.
    def mangle_fields!
      private_methods.each do |meth, str = meth.to_s|
        next unless str.start_with?('mangle_')
        next unless @fields.include?(str.split('_', 2)[1])
        send(meth)
      end
    end

    def parse_types(lines, klass)
      lines.split($/).collect do |line|
        klass.new(*line.split(' '))
      end
    end
  end
end
