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

require_relative '../lib/ci/version_enforcer'

module CI
  class VersionEnforcerTest < TestCase
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
