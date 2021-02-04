# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'
require_relative '../nci/lib/settings'

require 'mocha/test_unit'

class NCISettingsTest < TestCase
  def setup
    NCI::Settings.default_files = []
  end

  def teardown
    NCI::Settings.default_files = nil
  end

  def test_init
    NCI::Settings.new
  end

  def test_settings
    NCI::Settings.default_files << fixture_file('.yml')
    ENV['JOB_NAME'] = 'xenial_unstable_libkolabxml_src'
    settings = NCI::Settings.new
    settings = settings.for_job
    assert_equal({"sourcer"=>{"restricted_packaging_copy"=>true}}, settings)
  end

  def test_settings_singleton
    NCI::Settings.default_files << fixture_file('.yml')
    ENV['JOB_NAME'] = 'xenial_unstable_libkolabxml_src'
    assert_equal({"sourcer"=>{"restricted_packaging_copy"=>true}}, NCI::Settings.for_job)
  end

  def test_unknown_job
    assert_equal({}, NCI::Settings.new.for_job)
  end
end
