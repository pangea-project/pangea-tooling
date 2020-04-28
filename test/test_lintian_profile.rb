# frozen_string_literal: true
# SPDX-FileCopyrightText: 2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../ci-tooling/test/lib/testcase'

require_relative '../lib/lintian_profile'

module Lintian
  class ProfileTest < TestCase
    def setup
      ENV['LINTIAN_CFG'] = "#{Dir.pwd}/cfg"
      ENV['LINTIAN_PROFILE_DIR'] = "#{Dir.pwd}/prof"
    end

    def test_export
      Profile.new('foo').export
      assert_path_exist('cfg')
      assert_include(File.read('cfg'), 'show-overrides')
      assert_path_exist('prof/foo/main.profile')
      assert_include(File.read('prof/foo/main.profile'), 'Profile: foo/main')
      assert_equal(ENV['LINTIAN_PROFILE'], 'foo')
    end
  end
end
