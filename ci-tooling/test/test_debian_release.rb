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

require_relative '../lib/debian/release'
require_relative 'lib/testcase'

# Test debian Release repo file
class DebianReleaseTest < TestCase
  def setup
    # Change into our fixture dir as this stuff is read-only anyway.
    Dir.chdir(@datadir)
  end

  def test_dump
    r = Debian::Release.new(data)
    r.parse!

    # Insert some stuff.
    r.fields['SHA512'] << Debian::Release::Checksum.new('1', '2', '3')

    # we mess up the format a bit, so we need our own ref file
    assert_equal(File.read("#{data}.ref"), r.dump)
  end
end
