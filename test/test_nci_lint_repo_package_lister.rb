# frozen_string_literal: true
# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'
require_relative '../nci/lint/versions'

require 'mocha/test_unit'

module NCI
  class RepoPackageListerTest < TestCase
    def test_packages
      repo = mock('repo')
      # Simple aptly package string
      repo.expects(:packages).returns(['Pamd64 foo 0.9 abc', 'Pamd64 bar 1.0 abc'])

      pkgs = RepoPackageLister.new(repo).packages
      assert_equal(2, pkgs.size)
      assert_equal(%w[foo bar].sort, pkgs.map(&:name).sort)
    end

    def test_packages_filter
      repo = mock('repo')
      # Simple aptly package string
      repo.expects(:packages).returns(['Pamd64 foo 0.9 abc', 'Pamd64 bar 1.0 abc'])

      pkgs = RepoPackageLister.new(repo, filter_select: %w[foo]).packages
      assert_equal(1, pkgs.size)
      assert_equal(%w[foo].sort, pkgs.map(&:name).sort)
    end

    def test_default_repo
      # Constructs an env derived default repo name.
      ENV['TYPE'] = 'xx'
      ENV['DIST'] = 'yy'
      Aptly::Repository.expects(:get).with('xx_yy')

      RepoPackageLister.new
    end
  end
end
