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
require_relative '../lib/ci/lb_runner'
require 'mocha/test_unit'

class LiveBuildRunnerTest < TestCase
  def copy_data
    FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd)
  end

  def test_configure
    copy_data
    system_calls = ['./configure',
                    'lb build',
                    'lb clean']
    system_sequence = sequence('system-calls')
    system_calls.each do |cmd|
      Object.any_instance.expects(:system)
            .with(*cmd)
            .returns(true)
            .in_sequence(system_sequence)
    end

    lb = LiveBuildRunner.new
    lb.configure!
    lb.build!
    assert(File.exist?('result/Debian_20160506​.1544-amd64.hybrid.iso'))
    assert(File.exist?('result/latest.iso'))
  end

  def test_auto
    copy_data
    system_calls = ['lb config',
                    'lb build',
                    'lb clean']
    system_sequence = sequence('system-calls')
    system_calls.each do |cmd|
      Object.any_instance.expects(:system)
            .with(*cmd)
            .returns(true)
            .in_sequence(system_sequence)
    end

    lb = LiveBuildRunner.new
    lb.configure!
    lb.build!
    assert(File.exist?('result/Debian_20160506​.1544-amd64.hybrid.iso'))
    assert(File.exist?('result/latest.iso'))
  end

  def test_build_fail
    copy_data

    Object.any_instance.expects(:system)
          .with('./configure')
          .returns(true)

    Object.any_instance.expects(:system)
          .with('lb build')
          .returns(false)

    Object.any_instance.expects(:system)
          .with('lb clean')
          .returns(true)

    lb = LiveBuildRunner.new
    lb.configure!

    assert_raise LiveBuildRunner::BuildFailedError do
      lb.build!
    end
  end

  def test_configure_fail
    assert_raise LiveBuildRunner::ConfigError do
      lb = LiveBuildRunner.new
    end
  end
end
