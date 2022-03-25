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
require_relative '../nci/kf_sixy'

require 'mocha/test_unit'
require 'webmock/test_unit'
require 'net/ssh/gateway' # so we have access to the const

class NCIRepoCleanupTest < TestCase
  def setup
  end

  def teardown
  end

  def mock_repo
    repo = mock
    repo.expects(:Name)
  end

  def test_sixy_repo
    Object.any_instance.expects(:`)
    FileUtils.rm_rf("./kf6-test")
    FileUtils.cp_r("#{data}/original", "./kf6-test")
    Dir.chdir("kf6-test") do
      sixy = KfSixy.new()
      sixy.run
    end

    result = File.readlines("kf6-test/debian/control")
    File.readlines("#{data}/good/debian/control").each_with_index do |line, i|
      assert_equal(line, result[i])
    end
    assert_equal(false, File.exist?("kf6-test/debian/libkf5attica5.install"))
    assert_equal(false, File.exist?("kf6-test/debian/libkf5attica5.maintscript"))
    assert_equal(false, File.exist?("kf6-test/debian/libkf5attica5.symbols"))
    assert_equal(false, File.exist?("kf6-test/debian/libkf5attica-dev.acc.in"))
    assert_equal(false, File.exist?("kf6-test/debian/libkf5attica-dev.install"))
    assert_equal(false, File.exist?("kf6-test/debian/libkf5attica-dev.lintian-overrides"))
    assert_equal(false, File.exist?("kf6-test/debian/libkf5attica-doc.install"))
    assert_equal(true, File.exist?("kf6-test/debian/kf6-attica-dev.install"))
    assert_equal(true, File.exist?("kf6-test/debian/kf6-attica.install"))
  end
end
