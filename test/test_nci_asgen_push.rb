# frozen_string_literal: true

# SPDX-FileCopyrightText: 2019-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'
require_relative '../nci/asgen_push'

require 'mocha/test_unit'
require 'shellwords'

module NCI
  class AppstreamGeneratorPushTest < TestCase
    def setup
      Net::SFTP.expects(:start).never
      Net::SSH.expects(:start).never
      RSync.expects(:sync).never
      ENV['DIST'] = 'xenial'
      ENV['TYPE'] = 'release'
      ENV['APTLY_REPOSITORY'] = 'release'
      ENV['SSH_KEY_FILE'] = 'ssh.keyfile'
    end

    def test_run_no_export
      # Nothing generated => no pushing
      AppstreamGeneratorPush.new.run
    end

    class SFTPStub
      # Note that exceptions are only allocated. They won't be functional!
      # We get away with this because we only check if an exception was
      # raised. Moving forward we should avoid calling methods on sftp exceptions
      # OR revisit the cheap allocate trick.
      # Allocated objects exist, but they have not had their initialize called.

      def initialize(session:)
        @session = session
      end

      def session
        return @session
      end

      def chroot(path)
        "#{remote_dir}/#{path}"
      end

      def dir # also act as Dir, technically a different object in net::sftp though
        self
      end

      class NameStub
        def initialize(path)
          @path = path
        end

        def name
          File.basename(@path)
        end

        def symlink?
          File.symlink?(@path)
        end
      end

      def glob(path, pattern)
        warn 'glob'
        Dir.glob("#{chroot(path)}/#{pattern}") do |entry|
          yield NameStub.new(entry)
        end
      end

      def upload!(from, to)
        FileUtils.cp_r(from, chroot(to), verbose: true)
      end

      def stat!(path)
        File.stat(chroot(path))
      rescue Errno::ENOENT => e
        raise Net::SFTP::StatusException.allocate.exception(e.message)
      end

      def mkdir!(path)
        Dir.mkdir(chroot(path))
      rescue Errno::ENOENT => e
        raise Net::SFTP::StatusException.allocate.exception(e.message)
      end

      def readlink!(path)
        NameStub.new(File.readlink(chroot(path)))
      rescue Errno::ENOENT => e
        raise Net::SFTP::StatusException.allocate.exception(e.message)
      end

      def symlink!(old, new)
        File.symlink(old, chroot(new))
      rescue Errno::ENOENT => e
        raise Net::SFTP::StatusException.allocate.exception(e.message)
      end

      def rename!(old, new, _flags)
        File.rename(chroot(old), chroot(new))
      rescue Errno::ENOENT => e
        raise Net::SFTP::StatusException.allocate.exception(e.message)
      end

      def remove!(path)
        system "ls -lah #{chroot(path)}"
        FileUtils.rm(chroot(path))
      rescue Errno::ENOENT => e
        raise Net::SFTP::StatusException.allocate.exception(e.message)
      end

      private

      def remote_dir
        @session.remote_dir
      end
    end

    class SSHStub
      attr_reader :remote_dir

      def initialize(remote_dir:)
        @remote_dir = remote_dir
        @cmd = TTY::Command.new
      end

      def exec!(cmd)
        argv = Shellwords.split(cmd)
        raise if argv.any? { |x| x.include?('..') }
        argv = argv.collect { |x| x.start_with?('/') ? "#{remote_dir}/#{x}" : x }
        @cmd.run!(*argv)
      end
    end

    def test_run
      remote_dir = "#{Dir.pwd}/remote"

      ssh = SSHStub.new(remote_dir: remote_dir)
      sftp = SFTPStub.new(session: ssh)

      Net::SFTP.expects(:start).at_least_once.yields(sftp)
      # ignore this for now. hard to test and not very useful to test either
      RSync.expects(:sync)

      FileUtils.mkpath(remote_dir)
      FileUtils.cp_r("#{data}/.", '.')
      AppstreamGeneratorPush.new.run

      assert_path_exist("#{remote_dir}/home/neonarchives/aptly/skel/release/dists/xenial/main/dep11/Components-amd64.yml")
      assert_path_exist("#{remote_dir}/home/neonarchives/aptly/skel/release/dists/xenial/main/dep11/by-hash/MD5Sum/2a42a2c7a5dbd3fdb2e832aed8b2cbd5")
      assert_path_exist("#{remote_dir}/home/neonarchives/aptly/skel/release/dists/xenial/main/dep11/by-hash/MD5Sum/Components-amd64.yml.xz")
       # tempdir during upload
      assert_path_not_exist("#{remote_dir}/home/neonarchives/asgen_push.release")
    end

    def test_run_old_old
      # Has a current and an old variant already.
      remote_dir = "#{Dir.pwd}/remote"

      ssh = SSHStub.new(remote_dir: remote_dir)
      sftp = SFTPStub.new(session: ssh)

      Net::SFTP.expects(:start).at_least_once.yields(sftp)
      # ignore this for now. hard to test and not very useful to test either
      RSync.expects(:sync)

      FileUtils.cp_r("#{data}/.", '.')
      AppstreamGeneratorPush.new.run

      assert_path_exist("#{remote_dir}/home/neonarchives/aptly/skel/release/dists/xenial/main/dep11/Components-amd64.yml")
      assert_path_exist("#{remote_dir}/home/neonarchives/aptly/skel/release/dists/xenial/main/dep11/by-hash/MD5Sum/2a42a2c7a5dbd3fdb2e832aed8b2cbd5")
      assert_path_exist("#{remote_dir}/home/neonarchives/aptly/skel/release/dists/xenial/main/dep11/by-hash/MD5Sum/Components-amd64.yml.xz")
      assert_path_exist("#{remote_dir}/home/neonarchives/aptly/skel/release/dists/xenial/main/dep11/by-hash/MD5Sum/Components-amd64.yml.xz.old")
       # tempdir during upload
      assert_path_not_exist("#{remote_dir}/home/neonarchives/asgen_push.release")

      # This is a special blob which is specifically made different so
      # it gets dropped by the blobs cleanup.
      assert_path_not_exist("#{remote_dir}/home/neonarchives/aptly/skel/release/dists/xenial/main/dep11/by-hash/MD5Sum/e3f347cf9d52eeb49cace577d3cb1239")
    end
  end
end
