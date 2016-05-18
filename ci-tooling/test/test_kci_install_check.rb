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
require_relative '../kci/install_check'

require 'mocha/test_unit'
require 'webmock/test_unit'

class KCICiPPATest < TestCase
  def setup
    # Make sure $? is fine before we start!
    reset_child_status!
    # Disable all system invocation.
    Object.any_instance.expects(:`).never
    Object.any_instance.expects(:system).never
    # Disable automatic update.
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
  end

  def test_init
    ppa = CiPPA.new('unstable', 'wily')
    assert_equal('unstable', ppa.type)
    assert_equal('wily', ppa.series)
  end

  def test_remove
    repo = mock('mock_repo') do
      expects(:remove).returns(true)
    end

    Apt::Repository.expects(:new).with('ppa:kubuntu-ci/unstable').returns(repo)
    Apt.expects(:update).returns(true)

    ppa = CiPPA.new('unstable', 'wily')
    ppa.remove
  end

  def test_add
    repo = mock('mock_repo') do
      expects(:add).returns(true)
    end

    Apt::Repository.expects(:new).with('ppa:kubuntu-ci/unstable').returns(repo)
    Apt.expects(:update).returns(true)

    ppa = CiPPA.new('unstable', 'wily')
    ppa.add
  end

  def test_add_fail
    add_repo = mock('add_mock_repo') do
      expects(:add).returns(true)
    end

    remove_repo = mock('remove_mock_repo') do
      expects(:remove).returns(true)
    end

    seq = sequence('new_sequence')
    Apt::Repository
      .expects(:new)
      .in_sequence(seq)
      .with('ppa:kubuntu-ci/unstable')
      .returns(add_repo)
    Apt.expects(:update).returns(false).twice
    Apt::Repository
      .expects(:new)
      .in_sequence(seq)
      .with('ppa:kubuntu-ci/unstable')
      .returns(remove_repo)

    ppa = CiPPA.new('unstable', 'wily')
    ppa.add
  end
end

class KCIInstallCheckTest < TestCase
  def setup
    # Make sure $? is fine before we start!
    reset_child_status!
    # Disable all system invocation.
    Object.any_instance.expects(:`).never
    Object.any_instance.expects(:system).never
  end

  def test_run
    daily_ppa = mock('daily_ppa')
    daily_ppa.responds_like_instance_of(CiPPA)

    live_ppa = mock('live_ppa')
    live_ppa.responds_like_instance_of(CiPPA)

    check_seq = sequence('check_sequence')
    live_ppa
      .expects(:remove)
      .in_sequence(check_seq)
      .returns(true)
    daily_ppa
      .expects(:add)
      .in_sequence(check_seq)
      .returns(true)
    daily_ppa
      .expects(:install)
      .in_sequence(check_seq)
      .returns(true)
    live_ppa
      .expects(:add)
      .in_sequence(check_seq)
      .returns(true)
    live_ppa
      .expects(:install)
      .in_sequence(check_seq)
      .returns(true)
    live_ppa
      .expects(:purge)
      .in_sequence(check_seq)
      .returns(true)
    live_ppa
      .expects(:sources)
      .in_sequence(check_seq)
      .returns([])

    checker = InstallCheck.new
    checker.run(daily_ppa, live_ppa)

    assert_path_exist('sources-list.json')
  end
end
