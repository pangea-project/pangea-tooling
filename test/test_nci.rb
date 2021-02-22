# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>

require_relative 'lib/testcase'
require_relative '../lib/nci'

# Test NCI extensions on top of xci
class NCITest < TestCase
  def test_experimental_skip_qa
    skip = NCI.experimental_skip_qa
    assert_false(skip.empty?)
    assert(skip.is_a?(Array))
  end

  def test_only_adt
    only = NCI.only_adt
    assert_false(only.empty?)
    assert(only.is_a?(Array))
  end

  def test_old_series
    # Can be nil, otherwise it must be part of the array.
    return if NCI.old_series.nil?

    assert_include NCI.series.keys, NCI.old_series
  end

  def test_future_series
    # Can be nil, otherwise it must be part of the array.
    return if NCI.future_series.nil?

    assert_include NCI.series.keys, NCI.future_series
  end

  def test_current_series
    assert_include NCI.series.keys, NCI.current_series
  end

  def test_freeze
    assert_raises do
      NCI.architectures << 'amd64'
    end
  end

  def test_archive_key
    # This is a daft assertion. Technically the constraint is any valid apt-key
    # input, since we can't assert this, instead only assert that the data
    # is being correctly read from the yaml. This needs updating if the yaml's
    # data should ever change for whatever reason.
    assert_equal(NCI.archive_key, '444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D')
  end

  def test_qt_stage_type
    assert_equal(NCI.qt_stage_type, 'experimental')
  end

  def test_future_is_early
    # just shouldn't raise return value is truthy or falsey, which one we don't
    # care cause this is simply passing a .fetch() through.
    assert([true, false].include?(NCI.future_is_early))
  end

  def test_divert_repo
    File.write('nci.yaml', <<~YAML)
      repo_diversion: true
      divertable_repos: [testing]
    YAML
    NCI.send(:data_dir=, Dir.pwd) # resets as well

    assert(NCI.divert_repo?('testing'))
  ensure
    NCI.send(:reset!)
  end

  def test_no_divert_repo
    File.write('nci.yaml', <<~YAML)
      repo_diversion: true
      divertable_repos: []
    YAML
    NCI.send(:data_dir=, Dir.pwd) # resets as well

    refute(NCI.divert_repo?('testing'))
  ensure
    NCI.send(:reset!)
  end

  def test_no_diversion
    File.write('nci.yaml', <<~YAML)
      repo_diversion: false
      divertable_repos: [testing]
    YAML
    NCI.send(:data_dir=, Dir.pwd) # resets as well

    refute(NCI.divert_repo?('testing'))
  ensure
    NCI.send(:reset!)
  end
end
