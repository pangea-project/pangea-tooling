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

  def test_purge
    ppa = CiPPA.new('unstable', 'wily')
    ppa.expects(:packages).returns('pkg1' => '1.0', 'pkg2' => '2.0').twice
    Apt.expects(:purge).with(%w(pkg1 pkg2)).returns(true)
    assert(ppa.purge)
  end

  def test_purge_false
    ppa = CiPPA.new('unstable', 'wily')
    ppa.expects(:packages).returns({})
    assert_false(ppa.purge)
  end

  def test_install
    ppa = CiPPA.new('unstable', 'wily')
    ppa.expects(:packages).returns('pkg1' => '1.0', 'pkg2' => '2.0').twice
    superpin_io = StringIO.new
    File.expects(:open)
        .with('/etc/apt/preferences.d/superpin', 'w')
        .yields(superpin_io)
    Apt.expects(:install)
       .with(%w(ubuntu-minimal pkg1=1.0 pkg2=2.0))
       .returns(true)
    assert(ppa.install)
    assert_equal("Package: *\nPin: release o=LP-PPA-kubuntu-ci-unstable\nPin-Priority: 999\n", superpin_io.string)
  end

  def test_sources
    src1 = mock('src1') do
      stubs(:source_package_name).returns('src1')
      stubs(:source_package_version).returns('1.0')
    end
    src2 = mock('src2') do
      stubs(:source_package_name).returns('src2')
      stubs(:source_package_version).returns('2.0')
    end

    mock_series = mock('mock_series') do
    end

    Launchpad::Rubber
      .expects(:from_path)
      .with('ubuntu/wily')
      .returns(mock_series)

    mock_ppa = mock('mock_ppa') do
      expects(:getPublishedSources)
        .with(status: 'Published', distro_series: mock_series)
        .returns([src1, src2])
    end

    Launchpad::Rubber
      .expects(:from_path)
      .with('~kubuntu-ci/+archive/ubuntu/unstable')
      .returns(mock_ppa)


    ppa = CiPPA.new('unstable', 'wily')
    assert_equal({"src1"=>"1.0", "src2"=>"2.0"}, ppa.sources)
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
    daily_ppa
      .expects(:remove)
      .in_sequence(check_seq)
      .returns(true)
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
    checker.run(live_ppa, daily_ppa)

    assert_path_exist('sources-list.json')
  end
end

class NCIRootInstallCheckTest < TestCase
  def setup
    # Make sure $? is fine before we start!
    reset_child_status!
    # Disable all system invocation.
    Apt::Abstrapt.expects(:system).never
    Apt::Abstrapt.expects(:`).never
    Apt::Cache.expects(:system).never
    Apt::Cache.expects(:`).never
  end

  def test_run
    root = mock('root')
    proposed = mock('proposed')

    seq = sequence(__method__)
    proposed.expects(:remove).returns(true).in_sequence(seq)
    root.expects(:install).returns(true).in_sequence(seq)
    proposed.expects(:install).returns(true).in_sequence(seq)
    proposed.expects(:purge).returns(true).in_sequence(seq)

    checker = RootInstallCheck.new
    assert(checker.run(proposed, root))
  end

  def test_run_bad_root
    root = mock('root')
    proposed = mock('proposed')

    seq = sequence(__method__)
    proposed.expects(:remove).returns(true).in_sequence(seq)
    root.expects(:install).returns(false).in_sequence(seq)

    checker = RootInstallCheck.new
    assert_raises { checker.run(proposed, root) }
  end

  def test_run_bad_proposed_add
    root = mock('root')
    proposed = mock('proposed')

    seq = sequence(__method__)
    proposed.expects(:remove).returns(true).in_sequence(seq)
    root.expects(:install).returns(true).in_sequence(seq)
    proposed.expects(:add).returns(false).in_sequence(seq)

    checker = RootInstallCheck.new
    assert_raises { checker.run(proposed, root) }
  end

  def test_run_bad_proposed
    root = mock('root')
    proposed = mock('proposed')

    seq = sequence(__method__)
    proposed.expects(:remove).returns(true).in_sequence(seq)
    root.expects(:install).returns(true).in_sequence(seq)
    proposed.expects(:add).returns(true).in_sequence(seq)
    proposed.expects(:install).returns(false).in_sequence(seq)

    checker = RootInstallCheck.new
    assert_raises { checker.run(proposed, root) }
  end

  def test_run_bad_purge
    root = mock('root')
    proposed = mock('proposed')

    seq = sequence(__method__)
    proposed.expects(:remove).returns(true).in_sequence(seq)
    root.expects(:install).returns(true).in_sequence(seq)
    proposed.expects(:add).returns(true).in_sequence(seq)
    proposed.expects(:install).returns(true).in_sequence(seq)
    proposed.expects(:purge).returns(false).in_sequence(seq)

    checker = RootInstallCheck.new
    assert_raises { checker.run(proposed, root) }
  end
end
