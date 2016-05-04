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
  # Debian .dsc parser
  class DSC < Deb822
    # FIXME: lazy read automatically when accessing fields
    attr_reader :fields

    File = Struct.new(:md5, :size, :name)
    Checksum = Struct.new(:sum, :size, :file_name)

    # FIXME: pretty sure that should be in the base
    def initialize(file)
      @file = file
      @fields = InsensitiveHash.new
    end

    def parse!
      lines = ::File.new(@file).readlines

      fields = { mandatory: %w(format source version maintainer
                               checksums-sha1 checksums-sha256 files),
                 relationship: %w(build-depends build-depends-indep
                                  build-conflicts build-conflicts-indep),
                 multiline: %w(checksums-sha1 checksums-sha256 files) }
      fields[:foldable] = %w(package-list binary) + fields[:relationship]
      @fields = parse_paragraph(lines, fields)
      post_process

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

    def post_process
      return unless @fields
      if @fields['files']
        # Mangle list fields into structs.
        @fields['files'] = parse_types(@fields['files'], File)
        %w(checksums-sha1 checksums-sha256).each do |key|
          @fields[key] = parse_types(fields[key], Checksum)
        end
      end

      return unless @fields.key?('package-list')
      @fields['package-list'].reject! { |x| x.respond_to?(:empty?) && x.empty? }
    end

    def parse_types(lines, klass)
      lines.split($/).collect do |line|
        klass.new(*line.split(' '))
      end
    end
  end
end
