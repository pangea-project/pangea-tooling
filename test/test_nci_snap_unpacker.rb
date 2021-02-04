# frozen_string_literal: true
#
# Copyright (C) 2018-2019 Harald Sitter <sitter@kde.org>
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
require_relative '../nci/snap/unpacker'

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

      ret = Unpacker.new('kblocks').unpack
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
        Unpacker.new('kblocks').unpack
      end
    end
  end
end
