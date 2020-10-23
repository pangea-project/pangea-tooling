# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'

require_relative '../lib/ci/version_enforcer'

module CI
  class VersionEnforcerTest < TestCase
    def setup
      # dud. only used for output in version enforcer
      ENV['JOB_NAME'] = 'RaRaRasputin'
    end

    def test_init_no_file
      enforcer = VersionEnforcer.new
      assert_nil(enforcer.old_version)
    end

    def test_init_with_file
      File.write(VersionEnforcer::RECORDFILE, '1.0')
      enforcer = VersionEnforcer.new
      refute_nil(enforcer.old_version)
    end

    def test_increment_fail
      File.write(VersionEnforcer::RECORDFILE, '1.0')
      enforcer = VersionEnforcer.new
      assert_raise VersionEnforcer::UnauthorizedChangeError do
        enforcer.validate('1:1.0')
      end
    end

    def test_decrement_fail
      File.write(VersionEnforcer::RECORDFILE, '1:1.0')
      enforcer = VersionEnforcer.new
      assert_raise VersionEnforcer::UnauthorizedChangeError do
        enforcer.validate('1.0')
      end
    end

    def test_record!
      enforcer = VersionEnforcer.new
      enforcer.record!('2.0')
      assert_path_exist(VersionEnforcer::RECORDFILE)
      assert_equal('2.0', File.read(VersionEnforcer::RECORDFILE))
    end
  end
end
