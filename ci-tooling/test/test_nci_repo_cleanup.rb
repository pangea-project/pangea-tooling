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

require_relative 'lib/testcase'
require_relative '../nci/repo_cleanup'

require 'mocha/test_unit'
require 'webmock/test_unit'
require 'net/ssh/gateway' # so we have access to the const

class NCIRepoCleanupTest < TestCase
  def setup
    # Make sure $? is fine before we start!
    reset_child_status!
    # Disable all system invocation.
    Object.any_instance.expects(:`).never
    Object.any_instance.expects(:system).never

    WebMock.disable_net_connect!
  end

  def teardown
    WebMock.allow_net_connect!
  end

  def mock_repo
    repo = mock
    repo.expects(:Name)
  end

  def test_clean
    Aptly::Ext::Remote.expects(:neon).yields

    fake_unstable = mock('unstable')
    fake_unstable.stubs(:Name).returns('unstable')
    fake_unstable.expects(:packages)
                 .with(q: '$Architecture (source)')
                 .returns(['Psource kactivities-kf5 1 abc',
                           'Psource kactivities-kf5 3 ghi',
                           'Psource kactivities-kf5 4 jkl',
                           'Psource kactivities-kf5 2 def'])
    fake_unstable.expects(:packages)
                 .with(q: '!$Architecture (source)')
                 .returns([])
    fake_unstable.expects(:packages)
                 .with(q: '$Source (kactivities-kf5), $SourceVersion (1)')
                 .returns(['Pamd64 kactivy 1 abc',
                           'Pall kactivy-data 1 def'])
    fake_unstable.expects(:delete_packages)
                 .with(['Psource kactivities-kf5 1 abc',
                        'Pamd64 kactivy 1 abc',
                        'Pall kactivy-data 1 def'])
    fake_unstable.expects(:packages)
                 .with(q: '$Source (kactivities-kf5), $SourceVersion (2)')
                 .returns(['Pamd64 kactivy 2 abc',
                           'Pall kactivy-data 2 def'])
    fake_unstable.expects(:delete_packages)
                 .with(['Psource kactivities-kf5 2 def',
                        'Pamd64 kactivy 2 abc',
                        'Pall kactivy-data 2 def'])
    fake_unstable.expects(:packages)
                 .with(q: '$Source (kactivities-kf5), $SourceVersion (3)')
                 .returns(['Pamd64 kactivy 3 abc',
                           'Pall kactivy-data 3 def'])
    fake_unstable.expects(:delete_packages)
                 .with(['Psource kactivities-kf5 3 ghi',
                        'Pamd64 kactivy 3 abc',
                        'Pall kactivy-data 3 def'])
    fake_unstable.expects(:published_in)
                 .returns(mock.responds_like_instance_of(Aptly::PublishedRepository))
    # Highest version. must never be queried or we are considering to delete it!
    fake_unstable.expects(:packages)
                 .with(q: '$Source (kactivities-kf5), $SourceVersion (4)')
                 .never

    fake_stable = mock('stable')
    fake_stable.stubs(:Name).returns('stable')
    fake_stable.expects(:packages)
               .with(q: '$Architecture (source)')
               .returns(['Psource kactivities-src-kf5 4 jkl'])
    fake_stable.expects(:packages)
               .with(q: '!$Architecture (source)')
               .returns(['Pamd64 kactivities-kf5 1 abc',
                         'Pamd64 kactivities-kf5 3 ghi'])
    fake_stable.expects(:delete_packages)
               .with('Pamd64 kactivities-kf5 1 abc')
    fake_stable.expects(:published_in)
               .returns(mock.responds_like_instance_of(Aptly::PublishedRepository))

    fake_unstable_package = mock('kactivities-kf5')
    fake_unstable_package.stubs(:Package).returns('kactivities-kf5')
    fake_unstable_package.stubs(:Version).returns('3')
    fake_unstable_package.stubs(:Source).returns('kactivities-src-kf5 (4)')

    Aptly::Ext::Package
      .expects(:get)
      .with { |x| x.to_s == 'Pamd64 kactivities-kf5 3 ghi' }
      .returns(fake_unstable_package)
    Aptly::Repository.stubs(:list)
                     .returns([fake_unstable, fake_stable])
    {
      %w(1 gt 3) => 1 > 3,
      %w(1 lt 3) => 1 < 3,
      %w(4 gt 2) => 4 > 2,
      %w(1 gt 2) => 1 > 2,
      %w(1 lt 2) => 1 < 2,
      %w(3 gt 2) => 3 > 2,
      %w(3 gt 4) => 3 > 4,
      %w(3 lt 4) => 3 < 4
    }.each do |arg_array, return_value|
      Debian::Version
        .any_instance
        .expects(:system)
        .with('dpkg', '--compare-versions', *arg_array)
        .returns(return_value)
        .at_least_once

    end

    # RepoCleaner.clean(%w(unstable stable))
    ENV['PANGEA_TEST_EXECUTION'] = '1'
    load("#{__dir__}/../nci/repo_cleanup.rb")

  end

  def test_key_from_string
    key = Aptly::Ext::Package::Key.from_string('Psource kactivities-kf5 1 abc')
    assert_equal('source', key.architecture)
    assert_equal('kactivities-kf5', key.name)
    assert_equal('1', key.version)
    # FIXME: maybe this should be called hash?
    assert_equal('abc', key.uid)
  end

  def test_key_invalid
    assert_raises ArgumentError do
      Aptly::Ext::Package::Key.from_string('P kactivities-kf5 1 abc')
    end

    assert_raises ArgumentError do
      Aptly::Ext::Package::Key.from_string('Psource kactivities-kf5 1 abc asdf')
    end
  end

  def test_ssh_db_clean
    session = mock('session')
    Net::SSH.expects(:start).returns(session)
  end
end
