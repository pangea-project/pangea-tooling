#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'fileutils'
require 'tmpdir'
require 'rugged'

require_relative '../lib/ci/overrides'
require_relative '../lib/projects/factory'
require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class ProjectsFactoryTest < TestCase
  required_binaries %w[git]

  def setup
    CI::Overrides.default_files = [] # Disable overrides by default.
    reset_child_status!
    WebMock.disable_net_connect!(allow_localhost: true)
    Net::SFTP.expects(:start).never
    # Disable upstream scm adjustment through releaseme we work with largely
    # fake data in this test which would raise in the adjustment as expections
    # would not be met.
    CI::UpstreamSCM.any_instance.stubs(:releaseme_adjust!).returns(true)
    stub_request(:get, 'https://projects.kde.org/api/v1/projects/frameworks')
      .to_return(status: 200, body: '["frameworks/attica","frameworks/baloo","frameworks/bluez-qt"]', headers: { 'Content-Type' => 'text/json' })
    stub_request(:get, 'https://projects.kde.org/api/v1/projects/kde/workspace')
      .to_return(status: 200, body: '["kde/workspace/khotkeys","kde/workspace/plasma-workspace"]', headers: { 'Content-Type' => 'text/json' })
    stub_request(:get, 'https://projects.kde.org/api/v1/projects/kde')
      .to_return(status: 200, body: '["kde/workspace/khotkeys","kde/workspace/plasma-workspace"]', headers: { 'Content-Type' => 'text/json' })
    stub_request(:get, 'https://invent.kde.org/sysadmin/release-tools/-/raw/master/modules.git')
      .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: "kdialog                                     master\nkeditbookmarks                              master\n", headers: { 'Content-Type' => 'text/plain' })
    stub_request(:get, 'https://invent.kde.org/sdk/releaseme/-/raw/master/plasma/git-repositories-for-release-normal')
      .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: 'bluedevil breeze breeze-grub breeze-gtk breeze-plymouth discover drkonqi', headers: { 'Content-Type' => 'text/plain' })
    stub_request(:get, 'http://embra.edinburghlinux.co.uk/~jr/release-tools/modules.git')
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Ruby'
        }
      )
      .to_return(status: 200, body: "kdialog                                     master\nkeditbookmarks                              master", headers: { "Content-Type": 'text/plain' })
    stub_request(:get, 'https://raw.githubusercontent.com/KDE/releaseme/master/plasma/git-repositories-for-release')
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Ruby'
        }
      )
      .to_return(status: 200, body: "aura-browser bluedevil breeze breeze-grub", headers: { "Content-Type": 'text/plain' })
  end

  def teardown
    CI::Overrides.default_files = nil # Reset
    ProjectsFactory.factories.each do |factory|
      factory.send(:reset!)
    end
    WebMock.allow_net_connect!
  end

  def git_init_commit(repo_path, branches = %w[master kubuntu_unstable])
    repo_path = File.absolute_path(repo_path)
    fixture_path = "#{datadir}/packaging"
    Dir.mktmpdir do |dir|
      repo = Rugged::Repository.clone_at(repo_path, dir)
      Dir.chdir(dir) do
        Dir.mkdir('debian') unless Dir.exist?('debian')
        raise "missing fixture: #{fixture_path}" unless File.exist?(fixture_path)

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

  def create_fake_git(branches:, prefix: nil, repo: nil, repos: [])
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

  def mock_kde_invent_api!(paths = nil)
    ::Gitlab::Client.expects(:new).never # safety net

    unless paths
      # Expect this path to not call into listing at all
      ::Gitlab.expects(:client).never
      return
    end

    client = mock('gitlab-client')
    ::Gitlab.expects(:client).returns(client)
    groups = mock('gitlab-groups')
    client
      .expects(:group_projects)
      .with('neon', include_subgroups: true, archived: false)
      .returns(groups)
    groups.expects(:auto_paginate).returns(paths.collect do |v|
      OpenStruct.new({ path_with_namespace: v, topics: (v == 'archived-synthesizer' ? %w[neon-archived] : []) })
    end)
  end

  def cache_debian_backtick(path, return_value)
    reset_child_status!
    ProjectsFactory::Debian.expects(:`)
                           .with("ssh git.debian.org find /git/#{path} -maxdepth 1 -type d")
                           .returns(return_value)
    ProjectsFactory::Debian.ls(path)
  end

  def test_from_file
    neon_repos = %w[frameworks/attica
                    frameworks/solid
                    plasma/plasma-desktop
                    plasma/plasma-workspace
                    qt/qtbase]
    neon_dir = create_fake_git(branches: %w[master kubuntu_unstable],
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)

    debian_repos = %w[frameworks/ki18n]
    debian_dir = create_fake_git(prefix: 'pkg-kde',
                                 branches: %w[master kubuntu_unstable],
                                 repos: debian_repos)
    ProjectsFactory::Debian.instance_variable_set(:@url_base, debian_dir)

    # Mock neon listing.
    mock_kde_invent_api!(neon_repos)
    # Also cache a mocked listing for Debian's pkg-kde
    cache_debian_backtick('pkg-kde', "/git/pkg-kde/framworks\n")
    # And another for Debian's pkg-kde/frameworks
    cache_debian_backtick('pkg-kde/frameworks', "/git/pkg-kde/frameworks/ki18n.git\n")

    # FIXME: this does git things
    projects = ProjectsFactory.from_file("#{data}/projects.yaml")

    assert projects.is_a?(Array)
    projects.each { |p| refute_equal(p, nil) }

    ki18n = projects.find { |p| p.name == 'ki18n' }
    refute_nil ki18n, 'ki18n is missing from the projects :('
    assert_equal("#{debian_dir}/pkg-kde/frameworks/ki18n", ki18n.packaging_scm.url)

    assert_contains_project = lambda do |name|
      message = build_message(message, '<?> is not in the projects Array', name)
      assert_block message do
        projects.delete_if { |p| p.name == name } ? true : false
      end
    end
    expected_projects = %w[
      qtbase
      attica
      plasma-desktop
      plasma-workspace
      solid
      ki18n
    ]
    expected_projects.each do |expected|
      assert_contains_project.call(expected)
    end
    assert(projects.empty?,
           "Projects not empty #{projects.collect(&:name)}")
  end

  def test_from_file_with_properties
    neon_repos = %w[qt/qtbase
                    qt/sni-qt
                    qt/qtsvg]
    neon_dir = create_fake_git(branches: %w[master kubuntu_unstable kubuntu_stable kubuntu_vivid_mobile],
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)
    # Mock neon listing.
    mock_kde_invent_api!(neon_repos)

    projects = ProjectsFactory.from_file("#{data}/projects.yaml")

    assert projects.is_a?(Array)
    refute_equal(0, projects.size)
    projects.each do |x|
      refute_equal(x, nil)
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
    neon_repos = %w[qt/qtbase
                    qt/sni-qt
                    qt/qtsvg]
    neon_dir = create_fake_git(branches: %w[master kitten kubuntu_stable kubuntu_vivid_mobile],
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)
    # Mock neon listing.
    mock_kde_invent_api!(neon_repos)

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
    assert ProjectsFactory::Neon.understand?('invent.kde.org/neon')
    refute ProjectsFactory::Neon.understand?('git.debian.org')
  end

  def test_neon_unknown_array_content
    factory = ProjectsFactory::Neon.new('invent.kde.org/neon')

    assert_raise RuntimeError do
      factory.factorize([1])
    end
  end

  def test_neon_from_list
    neon_repos = %w[frameworks/attica]
    neon_dir = create_fake_git(branches: %w[master kubuntu_unstable],
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)
    # disable neon listing.
    mock_kde_invent_api!(nil)

    factory = ProjectsFactory::Neon.new('invent.kde.org/neon')
    projects = factory.factorize(%w[frameworks/attica])

    refute_nil(projects)
    assert_equal(1, projects.size)
    project = projects[0]
    refute_equal(project, nil)
    assert_equal('attica', project.name)
    assert_equal('frameworks', project.component)
    assert_equal("#{neon_dir}/frameworks/attica", project.packaging_scm.url)
  end

  def test_neon_ls
    # Make sure our parsing is on-point and doesn't include any unexpected
    # rubbish.
    neon_repos = %w[frameworks/attica]
    # Mock neon listing.
    mock_kde_invent_api!(neon_repos)

    list = ProjectsFactory::Neon.ls
    assert_equal(['frameworks/attica'], list.sort)
  end

  def test_neon_new_project_override
    neon_repos = %w[qt/qtbase]
    neon_dir = create_fake_git(branches: %w[master kubuntu_unstable],
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)
    # disable neon listing.
    mock_kde_invent_api!(nil)

    CI::Overrides.default_files = [data('override1.yaml'),
                                   data('override2.yaml')]
    factory = ProjectsFactory::Neon.new('invent.kde.org/neon')

    # This uses new_project directly as we otherwise have no way to set
    # overrides right now.
    projects = [factory.send(:new_project,
                             name: 'qtbase',
                             component: 'qt',
                             url_base: neon_dir,
                             branch: 'kubuntu_unstable',
                             origin: nil).value!]

    refute_nil(projects)
    assert_equal(1, projects.size)
    project = projects[0]
    refute_equal(project, nil)
    assert_equal 'qtbase', project.name
    assert_equal("#{neon_dir}/qt/qtbase", project.packaging_scm.url)
    assert_equal 'qtbase', project.packaging_scm.branch # overridden to name via erb
    assert_equal 'tarball', project.upstream_scm.type
    assert_equal 'http://http.debian.net/debian/pool/main/q/qtbase-opensource-src/qtbase-opensource-src_5.5.1.orig.tar.xz', project.upstream_scm.url
  end

  def test_debian_from_list
    debian_repos = %w[frameworks/solid]
    debian_dir = create_fake_git(prefix: 'pkg-kde',
                                 branches: %w[master kubuntu_unstable],
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
    refute_equal(project, nil)
    assert_equal 'solid', project.name
    assert_equal 'git', project.packaging_scm.type
    assert_equal "#{debian_dir}/pkg-kde/frameworks/solid", project.packaging_scm.url
    assert_equal 'kubuntu_unstable', project.packaging_scm.branch
  end

  def test_github_from_list
    github_repos = %w[calamares/calamares-debian]
    github_dir = create_fake_git(branches: %w[master kubuntu_unstable],
                                 repos: github_repos)
    ProjectsFactory::GitHub.instance_variable_set(:@url_base, github_dir)

    # mock the octokit query
    resource = Struct.new(:name, :private)
    Octokit::Client
      .any_instance
      .expects(:org_repos)
      .returns([resource.new('calamares-debian', false)])

    factory = ProjectsFactory::GitHub.new('github.com')
    projects = factory.factorize([{ 'calamares' => ['calamares-debian'] }])

    refute_nil(projects)
    assert_equal(1, projects.size)
    project = projects[0]
    refute_equal(project, nil)
    assert_equal 'calamares-debian', project.name
    assert_equal 'git', project.packaging_scm.type
    assert_equal "#{github_dir}/calamares/calamares-debian", project.packaging_scm.url
    assert_equal 'kubuntu_unstable', project.packaging_scm.branch
  end

  def test_github_private
    github_repos = %w[calamares/calamares-debian]
    github_dir = create_fake_git(branches: %w[master kubuntu_unstable],
                                 repos: github_repos)
    ProjectsFactory::GitHub.instance_variable_set(:@url_base, github_dir)

    # mock the octokit query
    resource = Struct.new(:name, :private)
    Octokit::Client
      .any_instance
      .expects(:org_repos)
      .returns([resource.new('calamares-debian', true)])

    Project.expects(:new).with do |*args|
      args[0] == 'calamares-debian' &&
        args[1] == 'calamares' &&
        args[2] == 'ssh://git@github.com:'
    end.returns('x')

    factory = ProjectsFactory::GitHub.new('github.com')
    ret = factory.factorize([{ 'calamares' => ['calamares-debian'] }])
    # faked return from mocha
    assert_equal(%w[x], ret)
  end

  def test_gitlab_from_list
    gitlab_repos = %w[calamares/calamares-debian calamares/neon/neon-pinebook
                      calamares/neon/oem/oem-config]
    gitlab_dir = create_fake_git(branches: %w[master kubuntu_unstable],
                                 repos: gitlab_repos)
    ProjectsFactory::Gitlab.instance_variable_set(:@url_base, gitlab_dir)

    # mock the octokit query
    group = Struct.new(:id)
    subgroup = Struct.new(:id, :path)
    resource = Struct.new(:path_with_namespace)
    ::Gitlab.expects(:group_search)
            .returns([group.new('999')])

    response =
      ::Gitlab::PaginatedResponse.new([resource.new('calamares/calamares-debian')])

    subgroup_projects =
      ::Gitlab::PaginatedResponse.new([resource.new('calamares/neon/neon-pinebook')])

    recursive_projects =
      ::Gitlab::PaginatedResponse.new([resource.new('calamares/neon/oem/oem-config')])

    ::Gitlab.expects(:group_projects)
            .times(3)
            .returns(response, subgroup_projects, recursive_projects)

    subgroup_response =
      ::Gitlab::PaginatedResponse.new([subgroup.new('1000', 'neon')])

    recursive_subgroup =
      ::Gitlab::PaginatedResponse.new([subgroup.new('1001', 'oem')])

    none_subgroup =
      ::Gitlab::PaginatedResponse.new([])

    ::Gitlab.expects(:group_subgroups)
            .times(3)
            .returns(subgroup_response, recursive_subgroup, none_subgroup)

    factory = ProjectsFactory::Gitlab.new('gitlab.com')
    projects = factory.factorize([{ 'calamares' => ['calamares-debian', 'neon/neon-pinebook', 'neon/oem/oem-config'] }])

    refute_nil(projects)
    assert_equal(3, projects.size)
    project = projects[0]
    refute_equal(project, nil)
    assert_equal 'calamares-debian', project.name
    assert_equal 'git', project.packaging_scm.type
    assert_equal "#{gitlab_dir}/calamares/calamares-debian", project.packaging_scm.url
    assert_equal 'kubuntu_unstable', project.packaging_scm.branch

    project = projects[1]
    refute_equal(project, nil)
    assert_equal 'neon-pinebook', project.name
    assert_equal 'git', project.packaging_scm.type
    assert_equal "#{gitlab_dir}/calamares/neon/neon-pinebook", project.packaging_scm.url
    assert_equal 'kubuntu_unstable', project.packaging_scm.branch

    project = projects[2]
    refute_equal(project, nil)
    assert_equal 'oem-config', project.name
    assert_equal 'git', project.packaging_scm.type
    assert_equal "#{gitlab_dir}/calamares/neon/oem/oem-config", project.packaging_scm.url
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
    FileUtils.mkpath("#{remote}/qt/qtubuntu-cameraplugin-fake")
    Dir.chdir("#{remote}/qt/qtubuntu-cameraplugin-fake") do
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
    File.chmod(0o744, bzr)
    ENV['PATH'] = "#{bin}:#{ENV['PATH']}"

    factory = ProjectsFactory::Launchpad.new('launchpad.net')
    projects = factory.factorize(['qt/qtubuntu-cameraplugin-fake'])

    refute_nil(projects)
    assert_equal(1, projects.size)
    project = projects[0]
    refute_equal(project, nil)
    assert_equal 'qtubuntu-cameraplugin-fake', project.name
    assert_equal 'bzr', project.packaging_scm.type
    assert_equal 'lp:qt/qtubuntu-cameraplugin-fake', project.packaging_scm.url
    assert_equal nil, project.packaging_scm.branch
  end

  def test_l10n_understand
    assert ProjectsFactory::KDEL10N.understand?('kde-l10n')
    refute ProjectsFactory::KDEL10N.understand?('git.debian.org')
  end

  def fake_dir_entry(name)
    obj = mock("fake_dir_entry_#{name}")
    obj.responds_like_instance_of(Net::SFTP::Protocol::V01::Name)
    obj.expects(:name).at_least_once.returns(name)
    obj
  end

  def test_kde_l10n_from_hash
    l10n_repos = %w[kde-l10n-ru kde-l10n-de]
    l10n_dir = create_fake_git(prefix: 'kde-l10n',
                               branches: %w[kubuntu_unstable],
                               repos: l10n_repos)
    ProjectsFactory::KDEL10N.instance_variable_set(:@url_base, l10n_dir)

    fake_session = mock('sftp_session')
    fake_session.responds_like_instance_of(Net::SFTP::Session)

    fake_dir = mock('fake_dir')
    fake_dir.responds_like_instance_of(Net::SFTP::Operations::Dir)
    fake_dir.stubs(:glob)
            .with('/home/ftpubuntu/stable/applications/16.04.1/src/kde-l10n/', '**/**.tar.*')
            .returns([fake_dir_entry('kde-l10n-ru-16.04.1.tar.xz'), fake_dir_entry('kde-l10n-de-16.04.1.tar.xz')])

    Net::SFTP.stubs(:start)
             .with('depot.kde.org', 'ftpubuntu')
             .yields(fake_session)
    fake_session.stubs(:dir).returns(fake_dir)

    factory = ProjectsFactory::KDEL10N.new('kde-l10n')
    projects = factory.factorize([{ '16.04.1' => ['kde-l10n-ru'] }])

    refute_nil(projects)
    assert_equal(1, projects.size)
    assert_equal('kde-l10n-ru', projects[0].name)
  end

  def test_empty_base
    neon_repos = %w[pkg-kde-tools]
    neon_dir = create_fake_git(branches: %w[master kittens],
                               repos: neon_repos)
    ProjectsFactory::Neon.instance_variable_set(:@url_base, neon_dir)

    mock_kde_invent_api!(neon_repos)

    factory = ProjectsFactory::Neon.new('packaging.neon.kde.org.uk')
    projects = factory.factorize([{
                                   '' => [
                                     {
                                       'pkg-kde-tools' => { 'branch' => 'kittens' }
                                     }
                                   ]
                                 }])

    refute_nil(projects)
    assert_equal(1, projects.size)
    project = projects[0]
    refute_equal(project, nil)
    assert_equal('pkg-kde-tools', project.name)
    assert_equal('', project.component)
    assert_equal("#{neon_dir}/pkg-kde-tools", project.packaging_scm.url)
  end

  def test_neon_fake_archivals
    # the neon-archived topic should disqualify a thing form getting listed
    neon_repos = %w[qt/qtbase archived-synthesizer]
    mock_kde_invent_api!(neon_repos)
    list = ProjectsFactory::Neon.ls
    assert_include(list, 'qt/qtbase')
    assert_not_include(list, 'archived-synthesizer')
  end
end
