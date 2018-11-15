# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/ci/kcrash_link_validator'
require_relative 'lib/testcase'

# Test kcrash validator
class KCrashLinkValidatorTest < TestCase
  def setup
    FileUtils.cp_r("#{data}/.", Dir.pwd, verbose: true)
    ENV['TYPE'] = 'unstable'
  end

  def test_run
    CI::KCrashLinkValidator.run do
      assert_includes(File.read('CMakeLists.txt'), 'kcrash_validator_check_all_targets')
    end
    assert_not_includes(File.read('CMakeLists.txt'), 'kcrash_validator_check_all_targets')
  end

  def test_run_no_cmakelists
    CI::KCrashLinkValidator.run do
      assert_path_not_exist('CMakeLists.txt')
    end
    assert_path_not_exist('CMakeLists.txt')
  end

  def test_run_on_unstable_only
    ENV['TYPE'] = 'stable'
    CI::KCrashLinkValidator.run do
      assert_not_includes(File.read('CMakeLists.txt'), 'kcrash_validator_check_all_targets')
    end
    assert_not_includes(File.read('CMakeLists.txt'), 'kcrash_validator_check_all_targets')
  end
end
