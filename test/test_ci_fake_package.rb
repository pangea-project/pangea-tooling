# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/ci/fake_package'

require_relative '../ci-tooling/test/lib/testcase'

require 'mocha/test_unit'

class FakePackageTest < TestCase
  def test_install
    cmd = mock('cmd')
    TTY::Command.expects(:new).returns(cmd)
    cmd.expects(:run).with do |*args|
      next false if args != ['dpkg-deb', '-b', 'foo', 'foo.deb']

      assert_path_exist('foo/DEBIAN/control')
      control = File.read('foo/DEBIAN/control')
      assert_includes(control, 'Package: foo')
      assert_includes(control, 'Version: 123')
      true
    end
    DPKG.expects(:run).with('dpkg', ['-i', 'foo.deb']).returns(true)

    pkg = FakePackage.new('foo', '123')
    pkg.install
  end
end
