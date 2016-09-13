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
    File.write('job_name', 'xenial_unstable_libkolabxml_src')
    settings = NCI::Settings.new
    settings = settings.for_job
    assert_equal({"sourcer"=>{"restricted_packaging_copy"=>true}}, settings)
  end

  def test_settings_singleton
    NCI::Settings.default_files << fixture_file('.yml')
    File.write('job_name', 'xenial_unstable_libkolabxml_src')
    assert_equal({"sourcer"=>{"restricted_packaging_copy"=>true}}, NCI::Settings.for_job)
  end

  def test_unknown_job
    assert_equal({}, NCI::Settings.new.for_job)
  end
end
