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

require_relative '../nci/debian-merge/tagdetective.rb'

module NCI
  module DebianMerge
    class NCITagDetectiveTest < TestCase
      def setup
      end

      def test_last_tag_base
        remote_dir = File.join(Dir.pwd, 'frameworks/extra-cmake-modules')
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
              `git tag debian/1-0`

              File.write('c2', '')
              `git add c2`
              `git commit --all -m 'commit'`
              `git tag debian/2-0`

              `git push --all`
              `git push --tags`
            end
          end
        end
        ProjectsFactory::Neon.stubs(:ls).returns(%w(frameworks/extra-cmake-modules))
        ProjectsFactory::Neon.stubs(:url_base).returns(Dir.pwd)

        assert_equal('debian/2', TagDetective.new.last_tag_base)
      end

      def test_investigate
        remote_dir = File.join(Dir.pwd, 'frameworks/meow')
        FileUtils.mkpath(remote_dir)
        Dir.chdir(remote_dir) do
          `git init --bare .`
        end
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            `git clone #{remote_dir} clone`
            Dir.chdir('clone') do
              File.write('c2', '')
              `git add c2`
              `git commit --all -m 'commit'`
              `git tag debian/2-0`

              `git push --all`
              `git push --tags`
            end
          end
        end

        ProjectsFactory::Neon.stubs(:ls).returns(%w(frameworks/meow))
        ProjectsFactory::Neon.stubs(:url_base).returns(Dir.pwd)

        TagDetective.any_instance.stubs(:last_tag_base).returns('debian/2')

        TagDetective.new.investigate
        assert_path_exist('data.json')
        assert_equal({ 'tag_base' => 'debian/2', 'repos' => [remote_dir] },
                     JSON.parse(File.read('data.json')))
      end

      def test_unreleased
        remote_dir = File.join(Dir.pwd, 'frameworks/meow')
        FileUtils.mkpath(remote_dir)
        Dir.chdir(remote_dir) do
          `git init --bare .`
        end
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            `git clone #{remote_dir} clone`
            Dir.chdir('clone') do
              File.write('c2', '')
              `git add c2`
              `git commit --all -m 'commit'`

              `git push --all`
              `git push --tags`
            end
          end
        end

        ProjectsFactory::Neon.stubs(:ls).returns(%w(frameworks/meow))
        ProjectsFactory::Neon.stubs(:url_base).returns(Dir.pwd)

        TagDetective.any_instance.stubs(:last_tag_base).returns('debian/2')

        TagDetective.new.investigate
        assert_path_exist('data.json')
        assert_equal({ 'tag_base' => 'debian/2', 'repos' => [] },
                     JSON.parse(File.read('data.json')))
      end
    end
  end
end
