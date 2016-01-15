require 'fileutils'
require 'tmpdir'

require_relative '../lib/projects'
require_relative 'lib/testcase'

# Mixin a prepend to overload the list_all_repos function with something testable.
module FakeProjectFactory
  def list_all_repos(_component)
    %w(kinfocenter)
  end
end

class ProjectFactory
  prepend FakeProjectFactory
end

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

    remotetmpdir = Dir.mktmpdir(self.class.to_s)
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

  def test_array_init_unstable
    require_binaries('git', 'bzr')

    repos = "#{Dir.pwd}/repo"
    %w(plasma/kinfocenter kde-applications/gwenview).each do |path|
      r = "#{repos}/#{path}"
      git_init_commit(git_init_repo(r))
    end

    Project.default_url = repos

    reference_projects = %w(kinfocenter gwenview qtubuntu-cameraplugin-fake)
    projects = Projects.new(type: 'unstable',
                            projects_file: "#{@datadir}/projects.json")
    assert_not_nil(projects)
    assert_equal(projects.size, reference_projects.size)
    tmpref = reference_projects.clone
    projects.each do |project|
      tmpref.delete_if { |name| name == project.name }
    end
    assert_equal(tmpref.size, 0)
  ensure
    Project.default_url = Project::DEFAULT_URL
  end

  def test_cleanup_uri
    assert_equal('/a/b', Project.cleanup_uri('/a//b/'))
    assert_equal('http://a.com/b', Project.cleanup_uri('http://a.com//b//'))
    assert_equal('//host/b', Project.cleanup_uri('//host/b/'))
  end

  def test_git_listing
    output = ProjectFactory.find_all_repos(data, hostcmd: '')
    assert_not_empty(output)
    output = ProjectFactory.split_find_output(output)
    assert_include(output, 'real1')
    assert_include(output, 'real2')
    # find includes path itself by default (since it is a dir...)
    assert_not_include(output, File.basename(data))
    assert_not_include(output, 'link1')
    assert_not_include(output, 'link2')
    assert_not_include(output, 'file1')
  end

  def test_custom_ci_invalid
    assert_raise Project::GitTransactionError do
      Projects.new(type: 'unstable', allow_custom_ci: true, projects_file: data('invalid.json'))
    end
  end

  def test_custom_ci
    projects = Projects.new(type: 'unstable', allow_custom_ci: true,
                            projects_file: data('projects.json'))
    assert_equal(2, projects.size)
    pro = projects[0]
    assert_equal('simplelogin-packaging', pro.name)
    assert_equal('plasma-phone-packaging', pro.component)
    assert_equal('git', pro.packaging_scm.type)
    assert_equal('https://github.com/plasma-phone-packaging/simplelogin-packaging', pro.packaging_scm.url)
    assert_equal('kubuntu_unstable', pro.packaging_scm.branch)
    assert_equal('git', pro.upstream_scm.type)
    assert_equal('git://anongit.kde.org/scratch/davidedmundson/simplelogin.git', pro.upstream_scm.url)

    pro = projects[1]
    assert_equal('seeds', pro.name)
    assert_equal('neon', pro.component)
    assert_equal('git', pro.packaging_scm.type)
    assert_equal('git://packaging.neon.kde.org.uk/neon/seeds', pro.packaging_scm.url)
    assert_equal('kubuntu_unstable', pro.packaging_scm.branch)
  ensure
    Project.default_url = Project::DEFAULT_URL
  end

  def test_static_ci
    repo_base = "#{Dir.pwd}/repo"
    git_init_commit(git_init_repo("#{repo_base}/pkg-kde/qt/qtx11extras"),
                    %w(master experimental))

    Project.default_url = repo_base

    assert_raise RuntimeError do
      Projects.new(type: 'unstable', projects_file: data('invalid.json'))
    end

    projects = Projects.new(type: 'unstable',
                            projects_file: data('projects.json'))
    assert_equal(1, projects.size)
    pro = projects[0]
    assert_equal('qtx11extras', pro.name)
    assert_equal('qt', pro.component)
    assert_equal('git', pro.packaging_scm.type)
    assert_equal("#{repo_base}/pkg-kde/qt/qtx11extras", pro.packaging_scm.url)
    assert_equal('experimental', pro.packaging_scm.branch)
    assert_equal('tarball', pro.upstream_scm.type)
    assert_equal('http://abc+dfsg.tar.xz', pro.upstream_scm.url)
  ensure
    Project.default_url = Project::DEFAULT_URL
  end

  def test_launchpad
    require_binaries('bzr')
    pro = Project.new('unity-action-api', 'launchpad',
                      'lp:')
    assert_equal('unity-action-api', pro.name)
    assert_equal('launchpad', pro.component)
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
