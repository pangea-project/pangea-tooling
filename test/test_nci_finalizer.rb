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

require_relative '../nci/debian-merge/finalizer'

module NCI
  module DebianMerge
    class NCIFinalizerTest < TestCase
      def setup
      end

      def test_run
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

              `git branch Neon/pending-merge`

              `git push --all`
              `git push --tags`
            end
          end
        end

        tag_base = 'debian/2'
        url = remote_dir
        json = { repos: [url], tag_base: tag_base }
        File.write('data.json', JSON.generate(json))

        Finalizer.new.run

        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            `git clone #{remote_dir} clone`
            Dir.chdir('clone') do
              `git checkout Neon/unstable`
              assert($?.success?)
              # system 'bash'
              assert_path_exist('c2')
              `git checkout Neon/pending-merge`
              assert_false($?.success?) # doesnt exist anymore
            end
          end
        end
      end

      def test_already_ffd
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

              # Same commit
              `git branch Neon/unstable`
              `git branch Neon/pending-merge`

              `git push --all`
              `git push --tags`
            end
          end
        end

        tag_base = 'debian/2'
        url = remote_dir
        json = { repos: [url], tag_base: tag_base }
        File.write('data.json', JSON.generate(json))

        # not raising anything
        Finalizer.new.run
      end

      def test_ff_not_possible
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

              `git branch Neon/pending-merge`

              File.write('c2', '')
              `git add c2`
              `git commit --all -m 'commit'`
              `git tag debian/2-0 -m 'fancy message'`

              `git branch Neon/unstable`

              `git push --all`
              `git push --tags`
            end
          end
        end

        tag_base = 'debian/2'
        url = remote_dir
        json = { repos: [url], tag_base: tag_base }
        File.write('data.json', JSON.generate(json))

        # going to fail sine pending is behind unstable
        assert_raises Finalizer::Repo::NoFastForwardError do
          Finalizer.new.run
        end
      end
    end
  end
end
