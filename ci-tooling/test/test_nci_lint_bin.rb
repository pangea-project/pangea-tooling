# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'

class NCILintBinTest < TestCase
  def setup
    ENV.delete('BUILD_URL')
    ENV['SIMPLECOV_ROOT'] = SimpleCov.root
    # Linitian testing is really hard to get to run sensibly since lintian
    # itself will want to unpack sources and compare debs and whatnot.
    # So we skip it in the hopes that it won't break API. The actual
    # functionality is tested in lintian's own unit test
    ENV['PANGEA_TEST_NO_LINTIAN'] = '1'
  end

  def run!
    `ruby #{__dir__}/../nci/lint_bin.rb 2> /dev/stdout`
  end

  description 'fail to run on account of no url file'
  def test_fail
    output = run!

    assert_not_equal(0, $?.to_i, output)
    assert_path_not_exist('reports')
  end

  description 'should work with a good url'
  def test_run
    ENV['BUILD_URL'] = data

    FileUtils.mkpath('build') # Dump a fake debian in.
    FileUtils.cp_r("#{datadir}/debian", "#{Dir.pwd}/build")

    output = run!

    assert_equal(0, $?.to_i, output)
    assert_path_exist('reports')
    Dir.glob("#{data('reports')}/*").each do |r|
      assert_path_exist("reports/#{File.basename(r)}")
    end
  end
end
