# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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
require_relative '../nci/duplicated_repos'

require 'mocha/test_unit'

module NCI
  class DuplicatedReposTest < TestCase
    def teardown
      DuplicatedRepos.whitelist = nil
    end

    def test_run_fail
      ProjectsFactory::Neon.expects(:ls).returns(%w[foo/bar std/bar])
      # Fatality only activates after a transition period. Can be dropped
      # once past the date.
      if (DateTime.new(2017, 9, 4) - DateTime.now) <= 0.0
        assert_raise do
          DuplicatedRepos.run
        end
      else
        DuplicatedRepos.run
      end
      assert_path_exist('reports/DuplicatedRepos.xml')
      data = File.read('reports/DuplicatedRepos.xml')
      assert_includes(data, 'foo/bar')
    end

    def test_run_pass
      ProjectsFactory::Neon.expects(:ls).returns(%w[foo/bar std/foo])
      DuplicatedRepos.run
      assert_path_exist('reports/DuplicatedRepos.xml')
      data = File.read('reports/DuplicatedRepos.xml')
      assert_not_includes(data, 'foo/bar')
    end

    def test_run_pass_with_whitelist
      DuplicatedRepos.whitelist = { 'bar' => %w[foo/bar std/bar] }
      ProjectsFactory::Neon.expects(:ls).returns(%w[foo/bar std/bar])
      DuplicatedRepos.run
      assert_path_exist('reports/DuplicatedRepos.xml')
      data = File.read('reports/DuplicatedRepos.xml')
      assert_not_includes(data, 'foo/bar')
    end

    def test_run_pass_with_paths_exclusion
      ProjectsFactory::Neon.expects(:ls).returns(%w[foo/bar attic/bar])
      DuplicatedRepos.run
      assert_path_exist('reports/DuplicatedRepos.xml')
      data = File.read('reports/DuplicatedRepos.xml')
      assert_not_includes(data, 'foo/bar')
    end

    def test_multi_exclusion
      ProjectsFactory::Neon.expects(:ls).returns(%w[foo/bar attic/bar kde-sc/bar])
      DuplicatedRepos.run
      assert_path_exist('reports/DuplicatedRepos.xml')
      data = File.read('reports/DuplicatedRepos.xml')
      assert_not_includes(data, 'foo/bar')
    end
  end
end
