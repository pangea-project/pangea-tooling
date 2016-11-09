# frozen_string_literal: true
#
# Copyright (C) 2016 Rohan Garg <rohan@kde.org>
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

require 'fileutils'

module CI
  class NotExactlyOneOrigFound < RuntimeError; end
  # Class to generate packaging for kde-l10n packages
  class LangPack
    class << self
      def generate_packaging!(lang)
        @lang = lang.gsub(/@|_/, '-').downcase
        match_pattern = /aaa(KDELANGNAME|UBUNTULANGCODE|KDELANGCODE|UBUNTULANGDEP)bbb/
        Dir.glob('debian/*').each do |file|
          next unless File.file? file
          subbed = File.open(file).read.gsub(match_pattern, @lang)
          File.write(file, subbed)
        end

        if File.exist?('debian/substvars')
          substvars = File.open('debian/substvars').read
          substvars.gsub!(/aaaADDITIONALDEPSbbb/, '')
          File.write('debian/substvars', substvars)
        end
        self.rename_orig(lang)
      end

      # Rename orig tar
      def rename_orig(lang)
        orig_tars = Dir.glob("../source/kde-l10n-#{lang}*")
        raise NotExactlyOneOrigFound unless orig_tars.count == 1

        orig_tar = orig_tars[0]
        renamed_orig_tar = orig_tar.gsub(/@|_/, '-').downcase
        FileUtils.mv(orig_tar, renamed_orig_tar)
      end
    end
  end
end
