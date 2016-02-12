# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
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
require 'rugged'

require_relative '../lib/ci/overrides'
require_relative '../lib/projects/factory'
require_relative 'lib/testcase'

require 'mocha/test_unit'

class ProjectsFactoryTest < TestCase
  required_binaries %w(git)

  def setup
    CI::Overrides.default_files = [] # Disable overrides by default.
  end

  def teardown
    CI::Overrides.default_files = nil # Reset
    ProjectsFactory.factories.each do |factory|
      factory.send(:reset!)
    end
  end

   #FIXME: port to rugged?
  def git_init_commit(repo_path, branches = %w(master kubuntu_unstable))
    repo_path = File.absolute_path(repo_path)
    repo_name = File.basename(repo_path)
    fixture_path = "#{@datadir}/packaging"
    Dir.mktmpdir do |dir|
      repo = Rugged::Repository.clone_at(repo_path, dir)
      Dir.chdir(dir) do
        Dir.mkdir('debian') unless Dir.exist?('debian')
        fail "missing fixture: #{fixture_path}" unless File.exist?(fixture_path)
        FileUtils.cp_r("#{fixture_path}/.", '.')

        index = repo.index
        index.add_all
        index.write
        tree = index.write_tree

        author = { name: 'Test', email: 'test@test.com', time: Time.now }
        Rugged::Commit.create(repo,
                              author: author,
                              message: 'commitmsg',
                              committer: author,
                              parents: [],
                              tree: tree,
                              update_ref: 'HEAD')

        branches.each do |branch|
          repo.create_branch(branch) unless repo.branches.exist?(branch)
        end
        origin = repo.remotes['origin']
        repo.references.each_name do |r|
          origin.push(r)
        end
      end
    end
  end

  def git_init_repo(path)
    FileUtils.mkpath(path)
    Rugged::Repository.init_at(path, :bare)
    File.absolute_path(path)
  end

  def create_fake_git(prefix: nil, repo: nil, repos: [], branches:)
    repos << repo if repo

    # Create a new tmpdir within our existing tmpdir.
    # This is so that multiple fake_gits don't clash regardless of prefix
    # or not.
    remotetmpdir = Dir::Tmpname.create('d', "#{@tmpdir}/remote") {}
    FileUtils.mkpath(remotetmpdir)
    Dir.chdir(remotetmpdir) do
      repos.each do |r|
        path = File.join(*[prefix, r].compact)
        git_init_repo(path)
        git_init_commit(path, branches)
      end
    end
    remotetmpdir
  end

  def gitolite_ls(paths)
    paths = paths.dup
    paths << 'random/garbage' # to make sure we filter correctly
    <<-EOF
hello sitter, this is gitolite3@weegie running gitolite3 3.6.1-3 (Debian) on git 2.1.4

#{paths.map { |p| " R W    #{p}" }.join("\n")}
    EOF
  end

  def reset_child_status!
    system('true') # Resets $? to all good
  end

  def cache_neon_backtick(return_value)
    reset_child_status!
    ProjectsFactory::Neon.expects(:`)
                         .with('ssh gitolite3@packaging.neon.kde.org.uk')
                         .returns(return_value)
    ProjectsFactory::Neon.ls
  end

  def cache_debian_backtick(path, return_value)
    reset_child_status!
    ProjectsFactory::Debian.expects(:`)
                           .with("ssh git.debian.org find /git/#{path} -maxdepth 1 -type d")
                           .returns(return_value)
    ProjectsFactory::Debian.ls(path)
  end

  def test_from_file
    neon_repos = %w(frameworks/attica
                    frameworks/solid
                    plasma/plasma-desktop
                    plasma/plasma-workspace
                    qt/qtbase)
    neon_dir = create_fake_git(branches: %w(master kubuntu_unstable),
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)

    debian_repos = %w(frameworks/ki18n)
    debian_dir = create_fake_git(prefix: 'pkg-kde',
                                 branches: %w(master kubuntu_unstable),
                                 repos: debian_repos)
    ProjectsFactory::Debian.instance_variable_set(:@url_base, debian_dir)

    # Cache a mocked listing for Neon
    cache_neon_backtick(gitolite_ls(neon_repos))
    # Also cache a mocked listing for Debian's pkg-kde
    cache_debian_backtick('pkg-kde', "/git/pkg-kde/framworks\n")
    # And another for Debian's pkg-kde/frameworks
    cache_debian_backtick('pkg-kde/frameworks', "/git/pkg-kde/frameworks/ki18n.git\n")

    # FIXME: this does git things
    projects = ProjectsFactory.from_file("#{data}/projects.yaml")

    assert projects.is_a?(Array)
    projects.each { |p| assert_is_a(p, Project) }

    ki18n = projects.find { |p| p.name == 'ki18n' }
    refute_nil ki18n, 'ki18n is missing from the projects :('
    assert_equal("#{debian_dir}/pkg-kde/frameworks/ki18n", ki18n.packaging_scm.url)

    assert_contains_project = lambda do |name|
      message = build_message(message, '<?> is not in the projects Array', name)
      assert_block message do
        projects.delete_if { |p| p.name == name } ? true : false
      end
    end
    expected_projects = %w(
      qtbase
      attica
      plasma-desktop
      plasma-workspace
      solid
      ki18n
    )
    expected_projects.each do |expected|
      assert_contains_project.call(expected)
    end
    assert(projects.empty?,
           "Projects not empty #{projects.collect(&:name)}")
  end

  def test_from_file_with_properties
    neon_repos = %w(qt/qtbase
                    qt/sni-qt
                    qt/qtsvg)
    neon_dir = create_fake_git(branches: %w(master kubuntu_unstable kubuntu_stable kubuntu_vivid_mobile),
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)
    # Cache a mocked listing for Neon
    cache_neon_backtick(gitolite_ls(neon_repos))

    projects = ProjectsFactory.from_file("#{data}/projects.yaml")

    assert projects.is_a?(Array)
    refute_equal(0, projects.size)
    projects.each do |x|
      assert_is_a(x, Project)
    end

    project = projects.find { |p| p.name == 'qtsvg' }
    refute_nil(project, 'qtsvg is missing from the projects :(')
    assert_equal('qtsvg', project.name)
    assert_equal('qt', project.component)
    assert_equal("#{neon_dir}/qt/qtsvg", project.packaging_scm.url)
    assert_equal('kubuntu_vivid_mobile', project.packaging_scm.branch)

    # TODO: should qtbase here really not cascade? this seems somewhat inconsistent
    #   with how overrides work where pattern rules cascade in order of
    #   preference.
    project = projects.find { |p| p.name == 'qtbase' }
    refute_nil(project, 'qtbase is missing from the projects :(')
    assert_equal('qtbase', project.name)
    assert_equal('qt', project.component)
    assert_equal("#{neon_dir}/qt/qtbase", project.packaging_scm.url)
    assert_equal('kubuntu_unstable', project.packaging_scm.branch)

    project = projects.find { |p| p.name == 'sni-qt' }
    refute_nil(project, 'sni-qt is missing from the projects :(')
    assert_equal('sni-qt', project.name)
    assert_equal('qt', project.component)
    assert_equal("#{neon_dir}/qt/sni-qt", project.packaging_scm.url)
    assert_equal('kubuntu_stable', project.packaging_scm.branch)
  end

  def test_from_file_kwords
    # Same as with_properties but we override the default via a kword for
    # from_file.
    neon_repos = %w(qt/qtbase
                    qt/sni-qt
                    qt/qtsvg)
    neon_dir = create_fake_git(branches: %w(master kitten kubuntu_stable kubuntu_vivid_mobile),
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)
    # Cache a mocked listing for Neon
    cache_neon_backtick(gitolite_ls(neon_repos))

    projects = ProjectsFactory.from_file("#{data}/projects.yaml",
                                         branch: 'kitten')

    project = projects.find { |p| p.name == 'qtbase' }
    refute_nil(project, 'qtbase is missing from the projects :(')
    assert_equal('kitten', project.packaging_scm.branch)

    project = projects.find { |p| p.name == 'qtsvg' }
    refute_nil(project, 'qtsvg is missing from the projects :(')
    assert_equal('kubuntu_vivid_mobile', project.packaging_scm.branch)

    project = projects.find { |p| p.name == 'sni-qt' }
    refute_nil(project, 'sni-qt is missing from the projects :(')
    assert_equal('kubuntu_stable', project.packaging_scm.branch)
  end

  def test_neon_understand
    assert ProjectsFactory::Neon.understand?('packaging.neon.kde.org.uk')
    refute ProjectsFactory::Neon.understand?('git.debian.org')
  end

  def test_neon_unknown_array_content
    factory = ProjectsFactory::Neon.new('packaging.neon.kde.org.uk')

    assert_raise RuntimeError do
      factory.factorize([1])
    end
  end

  def test_neon_from_list
    neon_repos = %w(frameworks/attica)
    neon_dir = create_fake_git(branches: %w(master kubuntu_unstable),
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)
    # Cache a mocked listing for Neon
    cache_neon_backtick(gitolite_ls(neon_repos))

    factory = ProjectsFactory::Neon.new('packaging.neon.kde.org.uk')
    projects = factory.factorize(%w(frameworks/attica))

    refute_nil(projects)
    assert_equal(1, projects.size)
    project = projects[0]
    assert_is_a(project, Project)
    assert_equal('attica', project.name)
    assert_equal('frameworks', project.component)
    assert_equal("#{neon_dir}/frameworks/attica", project.packaging_scm.url)
  end

  def test_neon_new_project_override
    neon_repos = %w(qt/qtbase)
    neon_dir = create_fake_git(branches: %w(master kubuntu_unstable),
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)
    # Cache a mocked listing for Neon
    cache_neon_backtick(gitolite_ls(neon_repos))

    CI::Overrides.default_files = [ data('override1.yaml'), data('override2.yaml') ]
    factory = ProjectsFactory::Neon.new('packaging.neon.kde.org.uk')

    # This uses new_project directly as we otherwise have no way to set
    # overrides right now.
    projects = [factory.send(:new_project,
                             name: 'qtbase',
                             component: 'qt',
                             url_base: neon_dir,
                             branch: 'kubuntu_unstable')]

    refute_nil(projects)
    assert_equal(1, projects.size)
    project = projects[0]
    assert_is_a(project, Project)
    assert_equal 'qtbase', project.name
    assert_equal("#{neon_dir}/qt/qtbase", project.packaging_scm.url)
    assert_equal 'qtbase', project.packaging_scm.branch # overridden to name via erb
    assert_equal 'tarball', project.upstream_scm.type
    assert_equal 'http://http.debian.net/debian/pool/main/q/qtbase-opensource-src/qtbase-opensource-src_5.5.1.orig.tar.xz', project.upstream_scm.url
  end

  def test_debian_from_list
    debian_repos = %w(frameworks/solid)
    debian_dir = create_fake_git(prefix: 'pkg-kde',
                                 branches: %w(master kubuntu_unstable),
                                 repos: debian_repos)
    ProjectsFactory::Debian.instance_variable_set(:@url_base, debian_dir)
    # Cache a mocked listing
    cache_debian_backtick('pkg-kde', "/git/pkg-kde/framworks\n")
    cache_debian_backtick('pkg-kde/frameworks', "/git/pkg-kde/frameworks/solid.git\n")

    factory = ProjectsFactory::Debian.new('git.debian.org')
    projects = factory.factorize([{ 'pkg-kde/frameworks' => ['solid'] }])

    refute_nil(projects)
    assert_equal(1, projects.size)
    project = projects[0]
    assert_is_a(project, Project)
    assert_equal 'solid', project.name
    assert_equal 'git', project.packaging_scm.type
    assert_equal "#{debian_dir}/pkg-kde/frameworks/solid", project.packaging_scm.url
    assert_equal 'kubuntu_unstable', project.packaging_scm.branch
  end

  def test_github_from_list
    github_repos = %w(calamares/calamares-debian)
    github_dir = create_fake_git(branches: %w(master kubuntu_unstable),
                                 repos: github_repos)
    ProjectsFactory::GitHub.instance_variable_set(:@url_base, github_dir)

    # mock the octokit query
    resource = Struct.new(:name)
    Octokit.expects(:organization_repositories)
           .returns([resource.new('calamares-debian')])

    factory = ProjectsFactory::GitHub.new('github.com')
    projects = factory.factorize([{ 'calamares' => ['calamares-debian'] }])

    refute_nil(projects)
    assert_equal(1, projects.size)
    assert_is_a(projects[0], Project)
    project = projects[0]
    assert_is_a(project, Project)
    assert_equal 'calamares-debian', project.name
    assert_equal 'git', project.packaging_scm.type
    assert_equal "#{github_dir}/calamares/calamares-debian", project.packaging_scm.url
    assert_equal 'kubuntu_unstable', project.packaging_scm.branch
  end

  def test_launchpad_understand
    assert ProjectsFactory::Launchpad.understand?('launchpad.net')
    refute ProjectsFactory::Launchpad.understand?('git.debian.org')
  end

  def test_launchpad_from_list
    require_binaries('bzr')
    # This test fakes bzr entirely to bypass the lp: pseudo-protocol
    # Overall this still tightly checks behavior.

    remote = File.absolute_path('remote')
    FileUtils.mkpath("#{remote}/qtubuntu-cameraplugin-fake")
    Dir.chdir("#{remote}/qtubuntu-cameraplugin-fake") do
      `bzr init .`
      File.write('file', '')
      `bzr add file`
      `bzr whoami --branch 'Test <test@test.com>'`
      `bzr commit -m 'commit'`
    end

    bzr_template = File.read(data('bzr.erb'))
    bzr_render = ERB.new(bzr_template).result(binding)
    bin = File.absolute_path('bin')
    Dir.mkdir(bin)
    bzr = "#{bin}/bzr"
    File.write(bzr, bzr_render)
    File.chmod(0744, bzr)
    ENV['PATH'] = "#{bin}:#{ENV['PATH']}"

    factory = ProjectsFactory::Launchpad.new('launchpad.net')
    projects = factory.factorize(['qtubuntu-cameraplugin-fake'])

    refute_nil(projects)
    assert_equal(1, projects.size)
    project = projects[0]
    assert_is_a(project, Project)
    assert_equal 'qtubuntu-cameraplugin-fake', project.name
    assert_equal 'bzr', project.packaging_scm.type
    assert_equal 'lp:qtubuntu-cameraplugin-fake', project.packaging_scm.url
    assert_equal nil, project.packaging_scm.branch
  end
end
