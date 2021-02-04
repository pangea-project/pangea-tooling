# frozen_string_literal: true
# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'
require_relative '../nci/lint/dir_package_lister'

module NCI
  class DirPackageListerTest < TestCase
    def test_packages
      FileUtils.cp_r("#{datadir}/.", '.')

      pkgs = DirPackageLister.new(Dir.pwd).packages
      assert_equal(2, pkgs.size)
      assert_equal(%w[foo bar].sort, pkgs.map(&:name).sort)
    end

    def test_packages_filter
      FileUtils.cp_r("#{datadir}/.", '.')

      pkgs = DirPackageLister.new(Dir.pwd, filter_select: %w[foo]).packages
      assert_equal(1, pkgs.size)
      assert_equal(%w[foo].sort, pkgs.map(&:name).sort)
    end
  end
end
