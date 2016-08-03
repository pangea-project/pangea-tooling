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
end
