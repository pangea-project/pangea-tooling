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

require_relative 'lib/testcase'
require_relative '../nci/snap/collapser'

require 'mocha/test_unit'

module NCI::Snap
  class BuildSnapPartCollapserTest < TestCase
    def test_part_collapse
      unpacker = mock('unpacker')
      Unpacker.expects(:new).with('kblocks').returns(unpacker)
      unpacker.expects(:unpack).returns('/snap/kblocks/current')

      core_unpacker = mock('core_unpacker')
      Unpacker.expects(:new).with('core18').returns(core_unpacker)
      core_unpacker.expects(:unpack).returns('/snap/core18/current')

      part = SnapcraftConfig::Part.new
      part.build_snaps = ['kblocks']
      part.plugin = 'cmake'
      BuildSnapPartCollapser.new(part).run

      assert_empty(part.build_snaps)
      assert_includes(part.cmake_parameters, '-DCMAKE_FIND_ROOT_PATH=/snap/kblocks/current')
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
      FileUtils.cp(data('snapcraft.yaml.ref'), Dir.pwd)

      orig_data = YAML.load_file('snapcraft.yaml')
      data = nil
      BuildSnapCollapser.new('snapcraft.yaml').run do
        ref = YAML.load_file('snapcraft.yaml.ref')
        data = YAML.load_file('snapcraft.yaml')
        assert_equal(ref, data)
      end
      data = YAML.load_file('snapcraft.yaml')
      assert_equal(orig_data, data)
    end
  end
end
