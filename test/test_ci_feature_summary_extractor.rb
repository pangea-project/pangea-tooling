# frozen_string_literal: true

# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/ci/feature_summary_extractor'
require_relative 'lib/testcase'

# test feature_summary extraction
class FeatureSummaryExtractorTest < TestCase
  def setup
    FileUtils.cp_r("#{data}/.", Dir.pwd, verbose: true)
  end

  def test_run
    CI::FeatureSummaryExtractor.run(build_dir: '.', result_dir: '.') do
      assert_includes(File.read('CMakeLists.txt'), 'feature_summary(FILENAME')
    end
    assert_not_includes(File.read('CMakeLists.txt'), 'feature_summary(FILENAME')
  end

  def test_run_no_cmakelists
    CI::FeatureSummaryExtractor.run(build_dir: '.', result_dir: '.') do
      assert_path_not_exist('CMakeLists.txt')
    end
    assert_path_not_exist('CMakeLists.txt')
  end
end
