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

require 'date'

require_relative 'lib/testcase'
require_relative '../nci/workspace_cleaner'

require 'mocha/test_unit'

class NCIWorkspaceCleanerTest < TestCase
  def setup
    WorkspaceCleaner.workspace_paths = [Dir.pwd]
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

    WorkspaceCleaner.clean

    assert_path_not_exist('3_days_old')
    assert_path_not_exist('1_day_old')
    assert_path_not_exist('future_ws-cleanup_123')

    assert_path_exist('mgmt_6_days_old')
    assert_path_exist('6_hours_old')
    assert_path_exist('just_now')
    assert_path_exist('future')
  end
end
