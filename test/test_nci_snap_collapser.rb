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

require_relative '../ci-tooling/test/lib/testcase'
require_relative '../nci/snap/collapser'

require 'mocha/test_unit'

module NCI::Snap
  class BuildSnapUnpackerTest < TestCase
    def test_unpack
      mockcmd = mock('tty::command')
      TTY::Command.expects(:new).returns(mockcmd)
      mockcmd.expects(:run).with do |*args, **kwords|
        next false unless args & ['snap', 'download',
                                  '--channel=stable', 'kblocks']
        next false unless kwords[:chdir]

        FileUtils.touch("#{kwords[:chdir]}/foo.snap")
      end
      mockcmd.expects(:run).with do |*args|
        args & ['unsquashfs', '-d', '/snap/kblocks/current'] &&
          args.any? { |x| x.include?('foo.snap') }
      end

      ret = BuildSnapUnpacker.new('kblocks').unpack
      assert_equal('/snap/kblocks/current', ret)
    end

    def test_no_snap
      mockcmd = mock('tty::command')
      TTY::Command.expects(:new).returns(mockcmd)
      mockcmd.expects(:run).with do |*args|
        next false unless args & ['snap', 'download',
                                  '--channel=stable', 'kblocks']

        # Intentionally create no file here. We'll want an exception!
        true
      end

      assert_raises do
        BuildSnapUnpacker.new('kblocks').unpack
      end
    end
  end

  class BuildSnapPartCollapserTest < TestCase
    def test_part_collapse
      unpacker = mock('unpacker')
      BuildSnapUnpacker.expects(:new).returns(unpacker)
      unpacker.expects(:unpack).returns('/snap/kblocks/current')

      part = SnapcraftConfig::Part.new
      part.build_snaps = ['kblocks']
      part.plugin = 'cmake'
      BuildSnapPartCollapser.new(part).run

      assert_empty(part.build_snaps)
      assert_includes(part.configflags, '-DCMAKE_FIND_ROOT_PATH=/snap/kblocks/current')
    end

    def test_part_no_cmake
      part = SnapcraftConfig::Part.new
      part.build_snaps = ['kblocks']
      part.plugin = 'dump'
      assert_raises do
        BuildSnapPartCollapser.new(part).run
      end
    end
  end

  class BuildSnapCollapserTest < TestCase
    def test_snap_collapse
      part_collapser = mock('part_collapser')
      BuildSnapPartCollapser.expects(:new).with do |part|
        part.is_a?(SnapcraftConfig::Part)
      end.returns(part_collapser)
      part_collapser.expects(:run)

      FileUtils.cp(data('snapcraft.yaml'), Dir.pwd)
      BuildSnapCollapser.new('snapcraft.yaml').run
    end
  end
end
