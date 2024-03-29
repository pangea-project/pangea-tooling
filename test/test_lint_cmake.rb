# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/lint/cmake'
require_relative 'lib/testcase'

# Test lint cmake
class LintCMakeTest < TestCase
  def cmake_ignore_path
    "#{data('cmake-ignore')}"
  end

  def test_init
    r = Lint::CMake.new(data).lint
    assert(!r.valid)
    assert(r.informations.empty?)
    assert(r.warnings.empty?)
    assert(r.errors.empty?)
  end

  def test_missing_package
    r = Lint::CMake.new(data).lint
    assert(r.valid)
    assert_equal(%w[KF5Package], r.warnings)
  end

  def test_optional
    r = Lint::CMake.new(data).lint
    assert(r.valid)
    assert_equal(%w[Qt5TextToSpeech], r.warnings)
  end

  def test_warning
    r = Lint::CMake.new(data).lint
    assert(r.valid)
    assert_equal(%w[], r.warnings)
  end

  def test_disabled_feature
    r = Lint::CMake.new(data).lint
    assert(r.valid)
    assert_equal(['XCB-CURSOR , Required for XCursor support'], r.warnings)
  end

  def test_missing_runtime
    r = Lint::CMake.new(data).lint
    assert(r.valid)
    assert_equal(['Qt5Multimedia'], r.warnings)
  end

  def test_ignore_warning_by_release
    ENV['DIST'] = 'xenial'
    r = Lint::CMake.new(data).lint
    assert(r.valid)
    assert_equal(['XCB-CURSOR , Required for XCursor support'], r.warnings)
  end

  def test_ignore_warning_by_release_yaml_no_series
    ENV['DIST'] = 'xenial'
    r = Lint::CMake.new(data).lint
    assert(r.valid)
    assert_equal([], r.warnings)
  end

  def test_ignore_warning_by_release_basic
    ENV['DIST'] = 'xenial'
    r = Lint::CMake.new(data).lint
    assert(r.valid)
    assert_equal(['QCH , API documentation in QCH format (for e.g. Qt Assistant, Qt Creator & KDevelop)'], r.warnings)
  end

  def test_ignore_warning_by_release_basic_multiline
    ENV['DIST'] = 'xenial'
    r = Lint::CMake.new(data).lint
    assert(r.valid)
    assert_equal([], r.warnings)
  end

  def test_ignore_warning_by_release_bionic
    ENV['DIST'] = 'bionic'
    r = Lint::CMake.new(data).lint
    assert(r.valid)
    assert_equal(['XCB-CURSOR , Required for XCursor support', 'QCH , API documentation in QCH format (for e.g. Qt Assistant, Qt Creator & KDevelop)'], r.warnings)
  end
end
