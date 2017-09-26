# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2015-2016 Rohan Garg <rohan@garg.io>
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

require 'digest'

require_relative '../debian/changes'
require_relative '../debian/dsc'

module CI
  # Helps processing a deb822 for upload.
  class Deb822Lister
    def initialize(file)
      @file = File.absolute_path(file)
      @dir = File.dirname(file)
      @deb822 = open
    end

    def self.files_to_upload_for(file)
      new(file).files_to_upload
    end

    def files_to_upload
      files = []
      @deb822.fields.fetch('checksums-sha256', []).each do |sum|
        file = File.absolute_path(sum.file_name, @dir)
        raise "File #{file} has incorrect checksum" unless valid?(file, sum)
        files << file
      end
      files << @file if @deb822.is_a?(Debian::DSC)
      files
    end

    private

    def open
      deb822 = open_changes(@file)
      # Switch .changes to .dsc to make sure aptly will have everything it
      # expects, in particular the .orig.tar
      # https://github.com/smira/aptly/issues/370
      dsc = deb822.fields['files'].find { |x| x.name.end_with?('.dsc') }
      return deb822 unless dsc
      puts "Switching #{File.basename(@file)} to #{dsc.name} ..."
      @file = File.absolute_path(dsc.name, @dir)
      open_dsc(@file)
    end

    def valid?(file, checksum)
      raise "File not found #{file}" unless File.exist?(file)
      Digest::SHA256.hexdigest(File.read(file)) == checksum.sum
    end

    def open_changes(file)
      puts "Opening #{File.basename(file)}..."
      changes = Debian::Changes.new(file)
      changes.parse!
      changes
    end

    def open_dsc(file)
      puts "  -> Opening #{File.basename(file)}..."
      dsc = Debian::DSC.new(file)
      dsc.parse!
      dsc
    end
  end
end
