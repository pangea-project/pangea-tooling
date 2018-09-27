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

require_relative '../lib/ci/dependency_resolver'
require_relative 'lib/testcase'

require 'mocha/test_unit'

# test ci/dependency_resolver
module CI
  class DependencyResolverAPTTest < TestCase
    required_binaries %w[apt-get]

    def test_build_bin_only
      builddir = Dir.pwd
      cmd = mock('cmd')
      cmd
        .expects(:run!)
        .with({ 'DEBIAN_FRONTEND' => 'noninteractive' },
              '/usr/bin/apt-get',
              '--arch-only',
              '--host-architecture', 'i386',
              '--yes',
              'build-dep', builddir)
        .returns(TTY::Command::Result.new(0, '', ''))
      TTY::Command.expects(:new).returns(cmd)

      DependencyResolverAPT.resolve(builddir, arch: 'i386', bin_only: true)
    end
  end
end
