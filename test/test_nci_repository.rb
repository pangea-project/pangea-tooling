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

require_relative '../ci-tooling/test/lib/testcase'

require 'mocha/test_unit'
require 'rugged'

require_relative '../nci/debian-merge/repository'

module NCI
  module DebianMerge
    class NCIRepositoryTest < TestCase
      def setup
      end

      def test_clonery
        remote_dir = File.join(Dir.pwd, 'remote/fishy')
        FileUtils.mkpath(remote_dir)
        Dir.chdir(remote_dir) do
          `git init --bare .`
        end
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            `git clone #{remote_dir} clone`
            Dir.chdir('clone') do
              File.write('c1', '')
              `git add c1`
              `git commit --all -m 'commit'`
              # NB: if we define no message the tag itself will not have a date
              `git tag debian/1-0 -m 'fancy message'`

              `git branch Neon/unstable`

              File.write('c2', '')
              `git add c2`
              `git commit --all -m 'commit'`
              `git tag debian/2-0 -m 'fancy message'`

              `git push --all`
              `git push --tags`
            end
          end
        end

        repo = Repository.clone_into('file://' + remote_dir, Dir.pwd)
        assert_path_exist('fishy') # the clone
        repo.tag_base = 'debian/2'
        repo.merge
        repo.push

        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            `git clone #{remote_dir} clone`
            Dir.chdir('clone') do
              `git checkout Neon/pending-merge`
              assert($?.success?)
              # system 'bash'
              assert_path_exist('c2')
            end
          end
        end
      end

      def test_orphan_branch
        remote_dir = File.join(Dir.pwd, 'remote/fishy')
        FileUtils.mkpath(remote_dir)
        Dir.chdir(remote_dir) do
          `git init --bare .`
        end
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            `git clone #{remote_dir} clone`
            Dir.chdir('clone') do
              File.write('c1', '')
              `git add c1`
              `git commit --all -m 'commit'`
              # NB: if we define no message the tag itself will not have a date
              `git tag debian/1-0 -m 'fancy message'`

              File.write('c2', '')
              `git add c2`
              `git commit --all -m 'commit'`
              `git tag debian/2-0 -m 'fancy message'`

              # Orphan!
              `git checkout --orphan Neon/unstable`
              File.write('u1', '')
              `git add u1`
              `git commit --all -m 'commit'`

              `git push --all`
              `git push --tags`
            end
          end
        end

        repo = Repository.clone_into('file://' + remote_dir, Dir.pwd)
        assert_path_exist('fishy') # the clone
        repo.tag_base = 'debian/2'
        assert_raises RuntimeError do
          repo.merge # no ancestor between branch and tag error
        end
      end

      def test_bad_latest_tag
        remote_dir = File.join(Dir.pwd, 'remote/fishy')
        FileUtils.mkpath(remote_dir)
        Dir.chdir(remote_dir) do
          `git init --bare .`
        end
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            `git clone #{remote_dir} clone`
            Dir.chdir('clone') do
              File.write('c1', '')
              `git add c1`
              `git commit --all -m 'commit'`
              # NB: if we define no message the tag itself will not have a date
              `git tag debian/5-0 -m 'fancy message'`

              `git push --all`
              `git push --tags`
            end
          end
        end

        repo = Repository.clone_into('file://' + remote_dir, Dir.pwd)
        assert_path_exist('fishy') # the clone
        repo.tag_base = 'debian/2' # only tag on repo is debian/5-0
        assert_raises RuntimeError do
          repo.merge # unexpected tag error
        end
      end

      def test_push_mangle
        remote_dir = File.join(Dir.pwd, 'remote/fishy')
        FileUtils.mkpath(remote_dir)
        Dir.chdir(remote_dir) do
          `git init --bare .`
        end

        repo = Repository.clone_into('file://' + remote_dir, Dir.pwd)
        assert_path_exist('fishy') # the clone
        repo.tag_base = 'debian/2'
        Dir.chdir('fishy') do
          puts `git remote set-url origin git://anongit.neon.kde.org/frameworks/khtml`.strip
        end
        repo.send(:mangle_push_path!) # private
        Dir.chdir('fishy') do
          puts `git remote get-url origin`
          puts `git remote get-url --push origin`
          assert_equal('neon@git.neon.kde.org:frameworks/khtml',
                       `git remote get-url --push origin`.strip)
        end
      end

      def test_ssh_cred
        remote_dir = File.join(Dir.pwd, 'remote/fishy')
        FileUtils.mkpath(remote_dir)
        Dir.chdir(remote_dir) do
          `git init --bare .`
        end

        Net::SSH::Config.expects(:for).with('frogi').returns({
          keys: ['/weesh.key']
        })
        Rugged::Credentials::SshKey.expects(:new).with(
          username: 'neon',
          publickey: '/weesh.key.pub',
          privatekey: '/weesh.key',
          passphrase: ''
        ).returns('wrupp')

        repo = Repository.clone_into('file://' + remote_dir, Dir.pwd)
        assert_path_exist('fishy') # the clone
        repo.tag_base = 'debian/2'
        r = repo.send(:credentials, 'frogi', 'neon', [:ssh_key]) # private
        # this isn't actually what it is meant to, but since we mocha the actual
        # key creation to check its values, this is basically to assert that the
        # return value of key.new is coming out of the method
        assert_equal('wrupp', r)
      end

    end
  end
end
