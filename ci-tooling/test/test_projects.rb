# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
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

require 'fileutils'
require 'tmpdir'

require_relative '../lib/projects'
require_relative 'lib/testcase'

require 'mocha/test_unit'

class ProjectTest < TestCase
  def git_init_commit(repo, branches = %w(master kubuntu_unstable))
    repo = File.absolute_path(repo)
    Dir.mktmpdir do |dir|
      `git clone #{repo} #{dir}`
      Dir.chdir(dir) do
        `git config user.name "Project Test"`
        `git config user.email "project@test.com"`
        Dir.mkdir('debian') unless Dir.exist?('debian')
        FileUtils.cp_r(Dir.glob("#{data}/debian/*"), 'debian')
        `git add *`
        `git commit -m 'commitmsg'`
        branches.each { |branch| `git branch #{branch}` }
        `git push --all origin`
      end
    end
  end

  def git_init_repo(path)
    FileUtils.mkpath(path)
    Dir.chdir(path) { `git init --bare` }
    File.absolute_path(path)
  end

  def create_fake_git(name:, component:, branches:)
    path = "#{component}/#{name}"

    # Create a new tmpdir within our existing tmpdir.
    # This is so that multiple fake_gits don't clash regardless of prefix
    # or not.
    remotetmpdir = Dir::Tmpname.create('d', "#{@tmpdir}/remote") {}
    FileUtils.mkpath(remotetmpdir)
    Dir.chdir(remotetmpdir) do
      git_init_repo(path)
      git_init_commit(path, branches)
    end
    remotetmpdir
  end

  def test_init
    name = 'tn'
    component = 'tc'

    %w(unstable stable).each do |stability|
      begin
        gitrepo = create_fake_git(name: name,
                                  component: component,
                                  branches: ["kubuntu_#{stability}",
                                             "kubuntu_#{stability}_yolo"])
        assert_not_nil(gitrepo)
        assert_not_equal(gitrepo, '')

        tmpdir = Dir.mktmpdir(self.class.to_s)
        Dir.chdir(tmpdir) do
          # Force duplicated slashes in the git repo path. The init is supposed
          # to clean up the path.
          # Make sure the root isn't a double slash though as that contstitues
          # a valid URI meaning whatever protocol is being used. Not practically
          # useful for us but good to keep that option open all the same.
          # Also make sure we have a trailing slash. Should we get a super short
          # tmpdir that way we can be sure that at least one pointless slash is
          # in the url.
          slashed_gitrepo = gitrepo.gsub('/', '//').sub('//', '/') + '/'
          project = Project.new(name, component, slashed_gitrepo,
                                type: stability)
          assert_equal(project.name, name)
          assert_equal(project.component, component)
          scm = project.upstream_scm
          assert_equal('git', scm.type)
          assert_equal('master', scm.branch)
          assert_equal("git://anongit.kde.org/#{name}", scm.url)
          assert_equal(%w(kinfocenter kinfocenter-dbg),
                       project.provided_binaries)
          assert_equal(%w(gwenview), project.dependencies)
          assert_equal([], project.dependees)
          assert_equal(["kubuntu_#{stability}_yolo"], project.series_branches)
          assert_equal(false, project.autopkgtest)

          assert_equal('git', project.packaging_scm.type)
          assert_equal("#{gitrepo}/#{component}/#{name}", project.packaging_scm.url)
          assert_equal("kubuntu_#{stability}", project.packaging_scm.branch)
        end
      ensure
        FileUtils.rm_rf(tmpdir) unless tmpdir.nil?
        FileUtils.rm_rf(gitrepo) unless gitrepo.nil?
      end
    end
  end

  # Tests init with explicit branch name instead of just type specifier
  def test_init_branch
    name = 'tn'
    component = 'tc'

    gitrepo = create_fake_git(name: name,
                              component: component,
                              branches: %w(kittens kittens_vivid))
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    tmpdir = Dir.mktmpdir(self.class.to_s)
    Dir.chdir(tmpdir) do
      # Force duplicated slashes in the git repo path. The init is supposed
      # to clean up the path.
      # Make sure the root isn't a double slash though as that contstitues
      # a valid URI meaning whatever protocol is being used. Not practically
      # useful for us but good to keep that option open all the same.
      # Also make sure we have a trailing slash. Should we get a super short
      # tmpdir that way we can be sure that at least one pointless slash is
      # in the url.
      slashed_gitrepo = gitrepo.gsub('/', '//').sub('//', '/') + '/'
      project = Project.new(name, component, slashed_gitrepo, branch: 'kittens')
      # FIXME: branch isn't actually stored in the projects because the
      #        entire thing is frontend driven (i.e. the update script calls
      #        Projects.new for each type manually). If this was backend/config
      #        driven we'd be much better off. OTOH we do rather differnitiate
      #        between types WRT dependency tracking and so forth....
      assert_equal(%w(kittens_vivid), project.series_branches)
    end
  ensure
    FileUtils.rm_rf(tmpdir) unless tmpdir.nil?
    FileUtils.rm_rf(gitrepo) unless gitrepo.nil?
  end

  # Attempt to clone a bad repo. Should result in error!
  def test_init_bad_repo
    assert_raise Project::GitTransactionError do
      Project.new('tn', 'tc', 'file:///yolo', branch: 'kittens')
    end
  end

  # Tests init with explicit branch name instead of just type specifier.
  # The branch is meant to not exist. We expect an error here!
  def test_init_branch_not_available
    name = 'tn'
    component = 'tc'

    gitrepo = create_fake_git(name: name,
                              component: component,
                              branches: %w())
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    tmpdir = Dir.mktmpdir(self.class.to_s)
    Dir.chdir(tmpdir) do
      slashed_gitrepo = gitrepo.gsub('/', '//').sub('//', '/') + '/'
      assert_raise Project::GitNoBranchError do
        Project.new(name, component, slashed_gitrepo, branch: 'kittens')
      end
    end
  ensure
    FileUtils.rm_rf(tmpdir) unless tmpdir.nil?
    FileUtils.rm_rf(gitrepo) unless gitrepo.nil?
  end

  def test_native
    name = 'tn'
    component = 'tc'

    gitrepo = create_fake_git(name: name, component: component, branches: %w(kubuntu_unstable))
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    Dir.mktmpdir(self.class.to_s) do |tmpdir|
      Dir.chdir(tmpdir) do
        project = Project.new(name, component, gitrepo, type: 'unstable')
        assert_nil(project.upstream_scm)
      end
    end
  end

  def test_cleanup_uri
    assert_equal('/a/b', Project.cleanup_uri('/a//b/'))
    assert_equal('http://a.com/b', Project.cleanup_uri('http://a.com//b//'))
    assert_equal('//host/b', Project.cleanup_uri('//host/b/'))
  end

  def test_launchpad
    reset_child_status!

    Object.any_instance.expects(:`).never
    Object.any_instance.expects(:system).never

    system_sequence = sequence('test_launchpad-system')
    Object.any_instance.expects(:system)
          .with do |x|
            next unless x == 'bzr checkout lp:unity-action-api unity-action-api'
            # .returns runs in a different binding so the chdir is wrong....
            # so we copy here.
            FileUtils.cp_r("#{data}/.", Dir.pwd, verbose: true)
            true
          end
          .returns(true)
          .in_sequence(system_sequence)
    Object.any_instance.expects(:system)
          .with('bzr up')
          .returns(true)
          .in_sequence(system_sequence)

    pro = Project.new('unity-action-api', 'launchpad',
                      'lp:')
    assert_equal('unity-action-api', pro.name)
    assert_equal('launchpad', pro.component)
    assert_equal(nil, pro.upstream_scm)
    assert_equal('lp:unity-action-api', pro.packaging_scm.url)
  end

  def test_default_url
    assert_equal(Project::DEFAULT_URL, Project.default_url)
  end

  def test_slash_in_name
    assert_raise NameError do
      Project.new('a/b', 'component', 'git:///')
    end
  end

  def test_slash_in_component
    assert_raise NameError do
      Project.new('name', 'a/b', 'git:///')
    end
  end
end
