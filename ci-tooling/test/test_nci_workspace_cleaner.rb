# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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

require 'date'

require_relative 'lib/testcase'
require_relative '../nci/workspace_cleaner'

require 'mocha/test_unit'

class NCIWorkspaceCleanerTest < TestCase
  def setup
    WorkspaceCleaner.workspace_paths = [Dir.pwd]
    ENV['DIST'] = 'meow'
  end

  def teardown
    WorkspaceCleaner.workspace_paths = nil
  end

  def mkdir(path, mtime)
    time = mtime.to_time
    Dir.mkdir(path)
    File.utime(time, time, path)
  end

  def test_clean
    datetime_now = DateTime.now
    mkdir('mgmt_6_days_old', datetime_now - 6)
    mkdir('3_days_old', datetime_now - 3)
    mkdir('1_day_old', datetime_now - 1)
    mkdir('6_hours_old', datetime_now - Rational(6, 24))
    mkdir('just_now', datetime_now)
    mkdir('future', datetime_now + 1)
    mkdir('future_ws-cleanup_123', datetime_now + 1)

    # We'll mock containment as we don't actually care what goes on on the
    # docker level, that is tested in the containment test already.
    containment = mock('containment')
    CI::Containment
      .stubs(:new)
      .with do |*_, **kwords|
        next false unless kwords.include?(:image)
        next false unless kwords[:no_exit_handlers]
        true
      end
      .returns(containment)
    containment
      .stubs(:run)
      .with(Cmd: ['/bin/chown', '-R', 'jenkins:jenkins', '/pwd'])
    containment.stubs(:cleanup)

    WorkspaceCleaner.clean

    assert_path_not_exist('3_days_old')
    assert_path_not_exist('1_day_old')
    assert_path_not_exist('future_ws-cleanup_123')

    assert_path_exist('mgmt_6_days_old')
    assert_path_exist('6_hours_old')
    assert_path_exist('just_now')
    assert_path_exist('future')
  end

  def test_clean_errno
    datetime_now = DateTime.now
    mkdir('3_days_old', datetime_now - 3)

    # We'll mock containment as we don't actually care what goes on on the
    # docker level, that is tested in the containment test already.
    containment = mock('containment')
    CI::Containment
      .stubs(:new)
      .with do |*_, **kwords|
        next false unless kwords.include?(:image)
        next false unless kwords[:no_exit_handlers]
        true
      end
      .returns(containment)
    # expect a chown! we must have this given we raise enoempty on rm_r later...
    containment
      .expects(:run)
      .with(Cmd: ['/bin/chown', '-R', 'jenkins:jenkins', '/pwd'])
    containment.stubs(:cleanup)

    FileUtils
      .stubs(:rm_r)
      .with { |x| x.end_with?('3_days_old') }
      .raises(Errno::ENOTEMPTY.new)
      .then
      .returns(true)

    FileUtils
      .stubs(:rm_r)
      .with { |x| !x.end_with?('3_days_old') }
      .returns(true)

    WorkspaceCleaner.clean

    # dir still exists here since we stubbed the rm_r call...
  end
end
