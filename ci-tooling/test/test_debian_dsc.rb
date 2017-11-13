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

require_relative '../lib/debian/dsc'
require_relative 'lib/testcase'

# Test debian .dsc
class DebianDSCTest < TestCase
  def setup
    # Change into our fixture dir as this stuff is read-only anyway.
    Dir.chdir(datadir)
  end

  def test_source
    c = Debian::DSC.new(data)
    c.parse!

    assert_equal(2, c.fields['checksums-sha1'].size)
    sum = c.fields['checksums-sha1'][1]
    assert_equal('d433a01bf5fa96beb2953567de96e3d49c898cce', sum.sum)
    # FIXME: should be a number maybe?
    assert_equal('2856', sum.size)
    assert_equal('gpgmepp_15.08.2+git20151212.1109+15.04-0.debian.tar.xz',
                 sum.file_name)

    assert_equal(2, c.fields['checksums-sha256'].size)
    sum = c.fields['checksums-sha256'][1]
    assert_equal('7094169ebe86f0f50ca145348f04d6ca7d897ee143f1a7c377142c7f842a2062',
                 sum.sum)
    # FIXME: should be a number maybe?
    assert_equal('2856', sum.size)
    assert_equal('gpgmepp_15.08.2+git20151212.1109+15.04-0.debian.tar.xz',
                 sum.file_name)

    assert_equal(2, c.fields['files'].size)
    file = c.fields['files'][1]
    assert_equal('fa1759e139eebb50a49aa34a8c35e383', file.md5)
    # FIXME: should be a number maybe?
    assert_equal('2856', file.size)
    assert_equal('gpgmepp_15.08.2+git20151212.1109+15.04-0.debian.tar.xz',
                 file.name)
  end
end
