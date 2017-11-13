# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

class OverlayBinsTest < TestCase
  OVERLAY_DIR = "#{__dir__}/../overlay-bin".freeze

  def setup
    assert_path_exist(OVERLAY_DIR, 'expected overlay dir to exist but could' \
                                   ' not find it. maybe it moved?')
    # Chains the actual overlay (which we expect to be dropped) before our
    # double overlay which we expect to get run to create stamps we can assert.
    @path = "#{OVERLAY_DIR}:#{datadir}:#{ENV['PATH']}"
    @env = { 'PATH' => @path, 'WORKSPACE' => Dir.pwd }
  end

  def test_cmake
    assert system(@env, "#{OVERLAY_DIR}/cmake", '-DXX=YY')
    assert_path_exist 'cmake_call'
    assert_equal '-DXX=YY', File.read('cmake_call').strip
  end

  def test_cmake_no_verbose
    assert system(@env, "#{OVERLAY_DIR}/cmake", '-DXX=YY', '-DCMAKE_VERBOSE_MAKEFILE=ON')
    assert_path_exist 'cmake_call'
    assert_equal '-DXX=YY', File.read('cmake_call').strip
  end

  def test_cmake_no_verbose_override
    File.write('cmake_verbose_makefile', '')
    assert system(@env, "#{OVERLAY_DIR}/cmake", '-DXX=YY', '-DCMAKE_VERBOSE_MAKEFILE=ON')
    assert_path_exist 'cmake_call'
    assert_equal '-DXX=YY -DCMAKE_VERBOSE_MAKEFILE=ON', File.read('cmake_call').strip
  end

  def test_tail
    assert system(@env, "#{OVERLAY_DIR}/tail", 'xx')
    assert_path_exist 'tail_call'
    assert_equal 'xx', File.read('tail_call').strip
  end

  def test_tail_cache_copy
    File.write('CMakeCache.txt', 'yy')
    assert system(@env, "#{OVERLAY_DIR}/tail", 'CMakeCache.txt')
    assert_path_not_exist 'tail_call'
    assert_path_exist 'archive_pickup/CMakeCache.txt'
    assert_equal 'yy', File.read('archive_pickup/CMakeCache.txt').strip
  end
end
