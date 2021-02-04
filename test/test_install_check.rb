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
require_relative '../lib/install_check'

require 'mocha/test_unit'
require 'webmock/test_unit'

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
    proposed.expects(:add).returns(true).in_sequence(seq)
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
