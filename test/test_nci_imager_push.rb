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
require_relative '../ci-tooling/lib/nci'

require 'net/sftp'
require 'tty/command'

# NB: this test wraps a script, it does not formally contribute to coverage
#   statistics but is better than no testing. the script should be turned
#   into a module with a run so we can require it without running it so we can
#   avoid the fork.
module NCI
  class ImagerPushTest < TestCase
    def assert_path_symlink(path, message=nil)
      failure_message = build_message(message,
                                      "<?> was expected to be a symlink",
                                      path)
      assert_block(failure_message) do
        File.symlink?(path)
      end
    end

    # Adapts sftp interface to local paths, making it possible to simulate
    # sftp against a local dir.
    class SFTPAdaptor
      Entry = Struct.new(:name)

      attr_reader :pwd
      def initialize(pwd)
        @pwd = pwd
        FileUtils.mkpath(pwd, verbose: true)
      end

      def mkdir!(dir)
        FileUtils.mkdir(File.join(pwd, dir), verbose: true)
      end

      def remove!(file)
        FileUtils.rm_f(File.join(pwd, file), verbose: true)
      end

      def mkpath(path)
        FileUtils.mkpath(File.join(pwd, path), verbose: true)
      end

      def upload!(src, target, requests: nil)
        # We don't care about requests.
        # NB: cp flattens symlinks, this is intentional because we consider
        #   symblinks not portable and thus they should not get uploaded if
        #   they are not meant to be flattened.
        FileUtils.cp(src, File.join(pwd, target), verbose: true)
      end

      ## Dir adpator
      ## should be separate adaptor class maybe?
      def dir
        self
      end

      def glob(path, pattern)
        Dir.glob(File.join(pwd, path, pattern)).collect do |x|
          Entry.new(name: x)
        end
      end

      ## Our CLI overlay!
      ## TODO: when making the pusher a proper module/class, prepend our
      ##   adaptor with the actual module so we can test the CLI logic as well.

      def cli_uploads
        @cli_uploads ||= false
      end

      def cli_uploads=(x)
        @cli_uploads = x
      end

      def symlink!(x, y)
        FileUtils.symlink(File.join(pwd, x), File.join(pwd, y), verbose: true)
      end
    end

    # Adapts ssh interface against localhost.
    class SSHAdaptor
      attr_reader :pwd
      def initialize(pwd, simulate: false)
        @pwd = pwd
        @tty = TTY::Command.new(dry_run: simulate)
      end

      def exec!(cmd, status: nil)
        Dir.chdir(pwd) do
          ret = @tty.run!(cmd)
          return if status.nil?
          status[:exit_code] = ret.status
        end
      end
    end

    def stub_sftp
      master = SFTPAdaptor.new('rsync.kde.org')
      # We do not mkpath properly in the pusher, simulate what we already have
      # server-side.
      master.mkpath('neon/images')
      mirror = SFTPAdaptor.new('files.kde.mirror.pangea.pub')
      embra = SFTPAdaptor.new('embra.edinburghlinux.co.uk')
      # We also do not properly mkpath against weegie.
      embra.mkpath('files.neon.kde.org.uk')

      Net::SFTP.expects(:start).never
      Net::SFTP.expects(:start).with('rsync.kde.org', 'neon').yields(master)
      Net::SFTP.expects(:start).with('files.kde.mirror.pangea.pub', 'neon-image-sync').yields(mirror)
      Net::SFTP.expects(:start).with('embra.edinburghlinux.co.uk', 'neon').yields(embra)
    end

    def stub_ssh
      files = SSHAdaptor.new('files.kde.mirror.pangea.pub', simulate: true)

      master = SSHAdaptor.new('rsync.kde.org')

      Net::SSH.expects(:start).never
      Net::SSH.expects(:start).with('files.kde.mirror.pangea.pub', 'neon-image-sync').yields(files)
      Net::SSH.expects(:start).with('rsync.kde.org', 'neon').yields(master)
    end

    # This brings down coverage which is meh, it does neatly isolate things
    # though.
    def test_run
      pid = fork do
        ENV['DIST'] = NCI.current_series
        ENV['ARCH'] = 'amd64'
        ENV['TYPE'] = 'testing'
        ENV['IMAGENAME'] = 'neon'

        Dir.mkdir('result')
        File.write('result/date_stamp', '20201123-1425')
        File.write('result/.message', 'hey hey wow wow')
        File.write("result/#{ENV['IMAGENAME']}-#{ENV['TYPE']}-20201123-1425.iso", 'blob')
        # imager creates the current files despite us wanting to create them
        # on the remote manually, make sure the symlinks are not resolved to
        # raw data (i.e. two isos being uploaded). The imager creates this file
        # because it needs to zsyncmake and having a dangling zsyncmake file
        # without associated iso file is also horrible.
        system('ln', '-s',
               "#{ENV['IMAGENAME']}-#{ENV['TYPE']}-20201123-1425.iso",
               "result/#{ENV['IMAGENAME']}-#{ENV['TYPE']}-current.iso") || raise
        File.write("result/#{ENV['IMAGENAME']}-#{ENV['TYPE']}-current.iso.zsync", 'blob')
        File.write('result/source.tar.xz', 'blob')

        Object.any_instance.expects(:system).never
        TTY::Command.any_instance.expects(:run)
              .with do |*args|
                next false unless args.include?('gpg')
                iso = args.pop # iso arg
                sig = args.pop # sig arg
                assert_path_exist(iso)
                File.write(sig, '')
              end
              .returns(true)

        stub_ssh
        stub_sftp

        load "#{__dir__}/../nci/imager_push.rb"
        puts 'all good, fork ending!'
        exit 0
      end
      waitedpid, status = Process.waitpid2(pid)
      assert_equal(pid, waitedpid)
      assert(status.success?)
      Dir.each_child("result") {|x| puts "Got #{x}" }
      assert_path_exist('rsync.kde.org/neon/images/testing/20201123-1425/.message')
      assert_path_exist('rsync.kde.org/neon/images/testing/20201123-1425/neon-testing-20201123-1425.iso')
      assert_path_exist('rsync.kde.org/neon/images/testing/20201123-1425/neon-testing-20201123-1425.iso.sig')
      assert_path_symlink('rsync.kde.org/neon/images/testing/20201123-1425/neon-testing-current.iso.sig')
      assert_path_symlink('rsync.kde.org/neon/images/testing/20201123-1425/neon-testing-current.iso')
      assert_path_exist('rsync.kde.org/neon/images/testing/20201123-1425/neon-testing-current.iso.zsync')
    end
  end
end
