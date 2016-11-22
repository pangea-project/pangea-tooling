# frozen_string_literal: true
#
# Copyright (C) 2016 Rohan Garg <rohan@garg.io>
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

require_relative '../lib/debian/architecturequalifier'
require_relative 'lib/testcase'
require 'mocha/test_unit'

# Test debian .dsc
module Debian
  class ArchitectureQualifierTest < TestCase
    def setup
      # Let all backtick or system calls that are not expected fall into
      # an error trap!
      Object.any_instance.expects(:`).never
      Object.any_instance.expects(:system).never
    end

    def test_multiple
      deb_arches = Debian::ArchitectureQualifier.new('i386 amd64')
      assert_equal(2, deb_arches.architectures.count)
    end

    def test_qualifies
      Object.any_instance.stubs(:system)
            .with('dpkg-architecture -a i386 -i i386 -f')
            .returns(true)

      Object.any_instance.stubs(:system)
            .with('dpkg-architecture -a amd64 -i i386 -f')
            .returns(false)

      deb_arches = Debian::ArchitectureQualifier.new('i386 amd64')
      assert(deb_arches.qualifies?('i386'))
    end

    def test_qualifies_with_modifier
      Object.any_instance.stubs(:system)
            .with('dpkg-architecture -a i386 -i i386 -f')
            .returns(true)

      deb_arches = Debian::ArchitectureQualifier.new('i386')
      assert_false(deb_arches.qualifies?('!i386'))
    end

    def test_architecture_with_modifier
      Object.any_instance.stubs(:system)
            .with('dpkg-architecture -a i386 -i i386 -f')
            .returns(true)
      Object.any_instance.stubs(:system)
            .with('dpkg-architecture -a amd64 -i i386 -f')
            .returns(false)

      Object.any_instance.stubs(:system)
            .with('dpkg-architecture -a i386 -i armhf -f')
            .returns(false)
      Object.any_instance.stubs(:system)
            .with('dpkg-architecture -a amd64 -i armhf -f')
            .returns(false)

      Object.any_instance.stubs(:system)
            .with('dpkg-architecture -a i386 -i amd64 -f')
            .returns(false)
      Object.any_instance.stubs(:system)
            .with('dpkg-architecture -a amd64 -i amd64 -f')
            .returns(true)

      deb_arches = Debian::ArchitectureQualifier.new('!i386 amd64')
      assert(deb_arches.qualifies?('!i386'))
      assert(deb_arches.qualifies?('armhf'))
      assert_false(deb_arches.qualifies?('!amd64'))
    end
  end
end
