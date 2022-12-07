# frozen_string_literal: true
# SPDX-FileCopyrightText: 2015-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/debian/changelog'
require_relative 'lib/testcase'

require 'tty/command'

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

  def test_new_version
    omit # adding changelog hands on deploy in spara
    # we'll do a test using dch since principally we need its new entry
    # to be valid, simulation through mock doesn't really cut it
    require_binaries('dch')

    FileUtils.cp_r("#{@datadir}/template/debian", '.')

    assert_equal('5.2.1-0ubuntu1', Debian::Changelog.new.version)
    Changelog.new_version!('123', distribution: 'dist', message: 'msg')
    assert_equal('123', Debian::Changelog.new.version)
  end

  def test_new_version_with_reload
    require_binaries('dch')

    FileUtils.cp_r("#{@datadir}/template/debian", '.')

    c = Debian::Changelog.new
    assert_equal('5.2.1-0ubuntu1', c.version)
    c.new_version!('123', distribution: 'dist', message: 'msg')
    assert_equal('123', c.version)
  end
end
