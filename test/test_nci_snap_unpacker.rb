# frozen_string_literal: true

# SPDX-FileCopyrightText: 2018-2022 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'
require_relative '../nci/snap/unpacker'

require 'mocha/test_unit'

module NCI::Snap
  class BuildSnapUnpackerTest < TestCase
    # TODO remove unpacker it's unused
    # def test_unpack
    #   mockcmd = mock('tty::command')
    #   TTY::Command.expects(:new).returns(mockcmd)
    #   mockcmd.expects(:run).with do |*args|
    #     kwords = args.pop # ruby3 compat, ruby3 no longer allows implicit **kwords conversion from hash but mocha relies on it still -sitter
    #     next false unless args & ['snap', 'download',
    #                               '--channel=stable', 'kblocks']
    #     next false unless kwords[:chdir]

    #     FileUtils.touch("#{kwords[:chdir]}/foo.snap")
    #   end
    #   mockcmd.expects(:run).with do |*args|
    #     args & ['unsquashfs', '-d', '/snap/kblocks/current'] &&
    #       args.any? { |x| x.include?('foo.snap') }
    #   end

    #   ret = Unpacker.new('kblocks').unpack
    #   assert_equal('/snap/kblocks/current', ret)
    # end

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
