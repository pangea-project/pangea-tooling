# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require 'tmpdir'

module CI
  # Validator wrapper to ensure targets that intended to link aginst kcrash
  # indeed ended up linked.
  # https://markmail.org/thread/zv5pheijaze72bzs
  class KCrashLinkValidator
    BLACKLIST = [
      # Uses the same link list for the bin and a plugin. Unreasonable to expect
      # a change there.
      '_kmail-account-wizard_',
    ].freeze

    def self.run(&block)
      new.run(&block)
    end

    def run(&block)
      if ENV['TYPE'] != 'unstable' ||
         !File.exist?('CMakeLists.txt') ||
         BLACKLIST.any? { |x| ENV.fetch('JOB_NAME').include?(x) }
        yield
        return
      end

      warn 'Extended CMakeLists with KCrash link validation.'
      mangle(&block)
    end

    private

    def data
      File.read(File.join(__dir__, 'kcrash_link_validator.cmake'))
    end

    def mangle
      Dir.mktmpdir do |tmpdir|
        begin
          backup = File.join(tmpdir, 'CMakeLists.txt')
          FileUtils.cp('CMakeLists.txt', backup, verbose: true)
          File.open('CMakeLists.txt', 'a') { |f| f.write(data) }
          yield
        ensure
          FileUtils.cp(backup, Dir.pwd, verbose: true)
        end
      end
    end
  end
end
