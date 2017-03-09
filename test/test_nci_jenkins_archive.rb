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

require_relative '../nci/jenkins_archive'
require_relative '../ci-tooling/test/lib/testcase'

require 'mocha/test_unit'

class NCIJenkinsArchiveTest < TestCase
  def setup
    Dir.expects(:home).returns(Dir.pwd)
  end

  def test_jenkins_archive_builds
    backupdir = "#{Dir.pwd}/mnt/volume-neon-jenkins/jobs.bak"
    buildsdir = 'jobs/nrop/builds'
    FileUtils.mkpath(buildsdir)
    (1000..1020).each do |i|
      dir = "#{buildsdir}/#{i}"
      FileUtils.mkpath(dir)
      # Decrease age and then multiply by days-in-week to get a build per week.
      # With 20 that gives us 120 days, or 4 months.
      age = (1020 - i) * 7
      mtime = (DateTime.now - age).to_time
      FileUtils.touch(dir, mtime: mtime)
    end

    NCI.jenkins_archive_builds(Dir.pwd)

    # 16 are being retained regardless, so only 1000 to 1005 qualify as old
    # enough for archival. NB: we have 21 dirs in total so that's why we have
    # 1005 not 1004 as oldest archived ;)
    (1000..1005).each do |i|
      assert_path_exist("#{backupdir}/#{i}")
    end

    (1012..1020).each do |i|
      assert_path_exist("#{buildsdir}/#{i}")
    end
  end
end
