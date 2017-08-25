# frozen_string_literal: true
#
# Copyright (C) 2015-2017 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/debian/changelog'
require_relative 'lib/testcase'

# Test debian/changelog
class DebianChangelogTest < TestCase
  def test_parse
    c = Changelog.new(data)
    assert_equal('khelpcenter', c.name)
    assert_equal('', c.version(Changelog::EPOCH))
    assert_equal('5.2.1', c.version(Changelog::BASE))
    assert_equal('', c.version(Changelog::BASESUFFIX))
    assert_equal('-0ubuntu1', c.version(Changelog::REVISION))
    assert_equal('5.2.1-0ubuntu1', c.version(Changelog::ALL))
  end

  def test_with_suffix
    c = Changelog.new(data)
    assert_equal('', c.version(Changelog::EPOCH))
    assert_equal('5.2.1', c.version(Changelog::BASE))
    assert_equal('~git123', c.version(Changelog::BASESUFFIX))
    assert_equal('-0ubuntu1', c.version(Changelog::REVISION))
    assert_equal('5.2.1~git123-0ubuntu1', c.version(Changelog::ALL))
    # Test combination
    assert_equal('5.2.1~git123', c.version(Changelog::BASE | Changelog::BASESUFFIX))
  end

  def test_without_suffix
    c = Changelog.new(data)
    assert_equal('', c.version(Changelog::EPOCH))
    assert_equal('5.2.1', c.version(Changelog::BASE))
    assert_equal('~git123', c.version(Changelog::BASESUFFIX))
    assert_equal('', c.version(Changelog::REVISION))
    assert_equal('5.2.1~git123', c.version(Changelog::ALL))
  end

  def test_with_suffix_and_epoch
    c = Changelog.new(data)
    assert_equal('4:', c.version(Changelog::EPOCH))
    assert_equal('5.2.1', c.version(Changelog::BASE))
    assert_equal('~git123', c.version(Changelog::BASESUFFIX))
    assert_equal('-0ubuntu1', c.version(Changelog::REVISION))
    assert_equal('4:5.2.1~git123-0ubuntu1', c.version(Changelog::ALL))
  end

  def test_alphabase
    c = Changelog.new(data)
    assert_equal('4:', c.version(Changelog::EPOCH))
    assert_equal('5.2.1a', c.version(Changelog::BASE))
    assert_equal('', c.version(Changelog::BASESUFFIX))
    assert_equal('-0ubuntu1', c.version(Changelog::REVISION))
    assert_equal('4:5.2.1a-0ubuntu1', c.version(Changelog::ALL))
  end

  def test_read_file_directly
    # Instead of opening a dir, open a file path
    c = Changelog.new("#{data}/debian/changelog")
    assert_equal('khelpcenter', c.name)
    assert_equal('5.2.1-0ubuntu1', c.version(Changelog::ALL))
  end
end
