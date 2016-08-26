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
require_relative '../lib/repo_abstraction'

require 'mocha/test_unit'
require 'webmock/test_unit'

class RepoAbstractionAptlyTest < TestCase
  required_binaries('dpkg')

  def setup
    WebMock.disable_net_connect!

    # More slective so we can let DPKG through.
    Apt::Repository.expects(:system).never
    Apt::Repository.expects(:`).never
    Apt::Abstrapt.expects(:system).never
    Apt::Abstrapt.expects(:`).never
    Apt::Cache.expects(:system).never
    Apt::Cache.expects(:`).never

    Apt::Repository.send(:reset)
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
  end

  def test_init
    AptlyRepository.new('repo', 'prefix')
  end

  def test_sources
    repo = mock('repo')
    repo
      .stubs(:packages)
      .with(:q => '$Architecture (source)')
      .returns(['Psource kactivities-kf5 3 ghi',
                'Psource kactivities-kf5 4 jkl',
                'Psource kactivities-kf5 2 def']) # Make sure this is filtered


    r = AptlyRepository.new(repo, 'prefix')
    assert_equal(["Psource kactivities-kf5 4 jkl"], r.sources.collect(&:to_s))
  end

  def test_install # implicitly tests #packages
    repo = mock('repo')
    repo
      .stubs(:packages)
      .with(:q => '$Architecture (source)')
      .returns(['Psource kactivities-kf5 4 jkl']) # Make sure this is filtered
    repo
      .stubs(:packages)
      .with(:q => '!$Architecture (source), $Source (kactivities-kf5), $SourceVersion (4)')
      .returns(['Pamd64 libkactivites 4 abc'])

    Apt::Abstrapt.expects(:system).with do |*x|
      x.include?('install') && x.include?('libkactivites=4')
    end.returns(true)

    r = AptlyRepository.new(repo, 'prefix')
    r.install
  end

  def test_purge_exclusion
    repo = mock('repo')
    repo
      .stubs(:packages)
      .with(:q => '$Architecture (source)')
      .returns(['Psource kactivities-kf5 4 jkl'])
    repo
      .stubs(:packages)
      .with(:q => '!$Architecture (source), $Source (kactivities-kf5), $SourceVersion (4)')
      .returns(['Pamd64 libkactivites 4 abc', 'Pamd64 kitteh 5 efd', 'Pamd64 base-files 5 efd'])
    # kitteh we filter, base-files should be default filtered
    Apt::Abstrapt
      .expects(:system)
      .with('apt-get', '-y', '-o', 'APT::Get::force-yes=true', '-o', 'Debug::pkgProblemResolver=true', 'purge', 'libkactivites')
      .returns(true)

    r = AptlyRepository.new(repo, 'prefix')
    r.purge_exclusion << 'kitteh'
    r.purge
  end
end

class RepoAbstractionRootOnAptlyTest < TestCase
  required_binaries('dpkg')

  def setup
    WebMock.disable_net_connect!

    # More slective so we can let DPKG through.
    Apt::Repository.expects(:system).never
    Apt::Repository.expects(:`).never
    Apt::Abstrapt.expects(:system).never
    Apt::Abstrapt.expects(:`).never
    Apt::Cache.expects(:system).never
    Apt::Cache.expects(:`).never

    Apt::Repository.send(:reset)
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
    Apt::Cache.send(:instance_variable_set, :@last_update, Time.now)
  end

  def test_init
    repo = RootOnAptlyRepository.new
    assert_empty(repo.send(:packages))
    # Should not hit mocha never-expectations.
    repo.add
    repo.remove
  end

  def test_packages
    mock_repo1 = mock('mock_repo1')
    mock_repo1
      .stubs(:packages)
      .with(:q => '$Architecture (source)')
      .returns(['Psource kactivities-kf5 4 jkl'])
    mock_repo1
      .stubs(:packages)
      .with(:q => '!$Architecture (source), $Source (kactivities-kf5), $SourceVersion (4)')
      .returns(['Pamd64 libkactivites 4 abc'])

    mock_repo2 = mock('mock_repo2')
    mock_repo2
      .stubs(:packages)
      .with(:q => '$Architecture (source)')
      .returns(['Psource kactivities-kf5 4 jkl', 'Psource trollomatico 3 abc'])
    mock_repo2
      .stubs(:packages)
      .with(:q => '!$Architecture (source), $Source (kactivities-kf5), $SourceVersion (4)')
      .returns(['Pamd64 libkactivites 4 abc'])
    mock_repo2
      .stubs(:packages)
      .with(:q => '!$Architecture (source), $Source (trollomatico), $SourceVersion (3)')
      .returns(['Pamd64 trollomatico 3 edf', 'Pamd64 unicornsparkles 4 xyz'])

    # This libkactivies actually would be called twice if optizmiation is
    # not working as expected. apt-cache calls are fairly expensive, so they
    # should be avoided when possible.
    Apt::Cache.expects(:system)
      .with('apt-cache', '-q', 'show', 'libkactivites', {[:out, :err]=>"/dev/null"})
      .returns(true)
    Apt::Cache.expects(:system)
      .with('apt-cache', '-q', 'show', 'trollomatico', {[:out, :err]=>"/dev/null"})
      .returns(true)
    # Exclude this.
    Apt::Cache.expects(:system)
      .with('apt-cache', '-q', 'show', 'unicornsparkles', {[:out, :err]=>"/dev/null"})
      .returns(false)

    aptly_repo1 = AptlyRepository.new(mock_repo1, 'mock1')
    aptly_repo2 = AptlyRepository.new(mock_repo2, 'mock2')

    Apt::Abstrapt
      .expects(:system)
      .with('apt-get', '-y', '-o', 'APT::Get::force-yes=true', '-o', 'Debug::pkgProblemResolver=true', 'install', 'ubuntu-minimal', 'libkactivites', 'trollomatico')
    RootOnAptlyRepository.new([aptly_repo1, aptly_repo2]).install
  end
end
