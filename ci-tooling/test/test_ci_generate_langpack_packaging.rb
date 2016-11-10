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

require_relative '../lib/ci/generate_langpack_packaging'
require_relative '../lib/debian/control'
require_relative '../lib/debian/changelog'
require_relative 'lib/testcase'

module CI
  class LangPackTest < TestCase
    def setup
      FileUtils.cp_r(Dir.glob("#{data}/."), Dir.pwd)
    end

    def test_generation
      Dir.chdir('kde-l10n-ca-valencia-15.12.3') do
        CI::LangPack.generate_packaging!('ca@VALENCIA')
        control = Debian::Control.new
        control.parse!
        assert(control.binaries.map {|x| x['Package']}.include? 'kde-l10n-ca-valencia')

        changelog = Changelog.new
        assert_equal('kde-l10n-ca-valencia', changelog.name)
      end
    end
  end
end
