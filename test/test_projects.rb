# frozen_string_literal: true

# SPDX-FileCopyrightText: 2015-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'fileutils'
require 'tmpdir'

require_relative '../lib/projects'
require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class ProjectTest < TestCase
  def setup
    # Disable overrides to not hit production configuration files.
    CI::Overrides.default_files = []
    # Disable upstream scm adjustment through releaseme we work with largely
    # fake data in this test which would raise in the adjustment as expections
    # would not be met.
    CI::UpstreamSCM.any_instance.stubs(:releaseme_adjust!).returns(true)
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_request(:get, 'https://projects.kde.org/api/v1/projects/frameworks')
      .to_return(status: 200, body: '["frameworks/attica","frameworks/baloo","frameworks/bluez-qt"]', headers: { 'Content-Type' => 'text/json' })
    stub_request(:get, 'https://projects.kde.org/api/v1/projects/kde/workspace')
      .to_return(status: 200, body: '["kde/workspace/khotkeys","kde/workspace/plasma-workspace"]', headers: { 'Content-Type' => 'text/json' })
    stub_request(:get, 'https://projects.kde.org/api/v1/projects/kde')
      .to_return(status: 200, body: '["kde/workspace/khotkeys","kde/workspace/plasma-workspace"]', headers: { 'Content-Type' => 'text/json' })
    stub_request(:get, 'https://invent.kde.org/sysadmin/release-tools/-/raw/master/modules.git')
      .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: "kdialog                                     master\nkeditbookmarks                              master\n", headers: { 'Content-Type' => 'text/plain' })
    stub_request(:get, 'https://invent.kde.org/sdk/releaseme/-/raw/master/plasma/git-repositories-for-release')
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
    CI::Overrides.default_files = nil
  end

  def git_init_commit(repo, branches = %w[master kubuntu_unstable])
    repo = File.absolute_path(repo)
    Dir.mktmpdir do |dir|
      `git clone #{repo} #{dir}`
      Dir.chdir(dir) do
        `git config user.name "Project Test"`
        `git config user.email "project@test.com"`
        begin
          FileUtils.cp_r("#{data}/debian/.", 'debian/')
        rescue StandardError
        end
        yield if block_given?
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

  def create_fake_git(name:, component:, branches:, &block)
    path = "#{component}/#{name}"

    # Create a new tmpdir within our existing tmpdir.
    # This is so that multiple fake_gits don't clash regardless of prefix
    # or not.
    remotetmpdir = Dir::Tmpname.create('d', "#{@tmpdir}/remote") {}
    FileUtils.mkpath(remotetmpdir)
    Dir.chdir(remotetmpdir) do
      git_init_repo(path)
      git_init_commit(path, branches, &block)
    end
    remotetmpdir
  end

  def test_init
    name = 'tn'
    component = 'tc'

    %w[unstable stable].each do |stability|
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
        slashed_gitrepo = "#{gitrepo.gsub('/', '//').sub('//', '/')}/"
        project = Project.new(name, component, slashed_gitrepo,
                              type: stability)
        assert_equal(project.name, name)
        assert_equal(project.component, component)
        p scm = project.upstream_scm
        assert_equal('git', scm.type)
        assert_equal('master', scm.branch)
        assert_equal("https://anongit.kde.org/#{name}", scm.url)
        assert_equal(%w[kinfocenter kinfocenter-dbg],
                     project.provided_binaries)
        assert_equal(%w[gwenview], project.dependencies)
        assert_equal([], project.dependees)
        assert_equal(["kubuntu_#{stability}_yolo"], project.series_branches)
        assert_equal(false, project.autopkgtest)

        assert_equal('git', project.packaging_scm.type)
        assert_equal("#{gitrepo}/#{component}/#{name}", project.packaging_scm.url)
        assert_equal("kubuntu_#{stability}", project.packaging_scm.branch)
        assert_equal(nil, project.snapcraft)
        assert(project.debian?)
        assert_empty(project.series_restrictions)
      end
    ensure
      FileUtils.rm_rf(tmpdir) unless tmpdir.nil?
      FileUtils.rm_rf(gitrepo) unless gitrepo.nil?
    end
  end

  def test_init_profiles
    name = 'tn'
    component = 'tc'
    gitrepo = create_fake_git(name: name, component: component, branches: %w[kubuntu_unstable])
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    Dir.mktmpdir(self.class.to_s) do |tmpdir|
      Dir.chdir(tmpdir) do
        project = Project.new(name, component, gitrepo, type: 'unstable')
        assert_equal(%w[gwenview], project.dependencies)
      end
    end
  end

  # Tests init with explicit branch name instead of just type specifier
  def test_init_branch
    name = 'tn'
    component = 'tc'

    gitrepo = create_fake_git(name: name,
                              component: component,
                              branches: %w[kittens kittens_vivid kittens_piggy])
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
      slashed_gitrepo = "#{gitrepo.gsub('/', '//').sub('//', '/')}/"
      project = Project.new(name, component, slashed_gitrepo, branch: 'kittens')
      # FIXME: branch isn't actually stored in the projects because the
      #        entire thing is frontend driven (i.e. the update script calls
      #        Projects.new for each type manually). If this was backend/config
      #        driven we'd be much better off. OTOH we do rather differnitiate
      #        between types WRT dependency tracking and so forth....
      # NB: this must assert **two** branches to ensure all lines are stripped
      #   properly.
      assert_equal(%w[kittens_vivid kittens_piggy].sort,
                   project.series_branches.sort)
    end
  ensure
    FileUtils.rm_rf(tmpdir) unless tmpdir.nil?
    FileUtils.rm_rf(gitrepo) unless gitrepo.nil?
  end

  # Attempt to clone a bad repo. Should result in error!
  def test_init_bad_repo
    assert_raise Project::GitTransactionError do
      Project.new('tn', 'tc', 'git://foo.bar.ja', branch: 'kittens')
    end
  end

  def test_init_from_ssh
    Net::SSH::Config.expects(:for).with('github.com').returns({
                                                                keys: ['/weesh.key']
                                                              })
    Rugged::Credentials::SshKey.expects(:new).with(
      username: 'git',
      publickey: '/weesh.key.pub',
      privatekey: '/weesh.key',
      passphrase: ''
    ).returns('wrupp')
    gitrepo = create_fake_git(name: 'tc', component: 'tn', branches: %w[kittens])
    Rugged::Repository.expects(:clone_at).with do |*args, **kwords|
      p [args, kwords]
      next false unless args[0] == 'ssh://git@github.com/tn/tc' &&
                        args[1] == "#{Dir.pwd}/cache/projects/git@github.com/tn/tc" &&
                        kwords[:bare] == true &&
                        kwords[:credentials].is_a?(Method)

      FileUtils.mkpath("#{Dir.pwd}/cache/projects/git@github.com/tn")
      system("git clone #{gitrepo}/tn/tc #{Dir.pwd}/cache/projects/git@github.com/tn/tc")
      kwords[:credentials].call(args[0], 'git', nil)
      true
    end.returns(true)
    Project.new('tc', 'tn', 'ssh://git@github.com:', branch: 'kittens')
  end

  # Tests init with explicit branch name instead of just type specifier.
  # The branch is meant to not exist. We expect an error here!
  def test_init_branch_not_available
    name = 'tn'
    component = 'tc'

    gitrepo = create_fake_git(name: name,
                              component: component,
                              branches: %w[])
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    tmpdir = Dir.mktmpdir(self.class.to_s)
    Dir.chdir(tmpdir) do
      slashed_gitrepo = "#{gitrepo.gsub('/', '//').sub('//', '/')}/"
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

    gitrepo = create_fake_git(name: name, component: component, branches: %w[kubuntu_unstable])
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    Dir.mktmpdir(self.class.to_s) do |tmpdir|
      Dir.chdir(tmpdir) do
        project = Project.new(name, component, gitrepo, type: 'unstable')
        assert_nil(project.upstream_scm)
      end
    end
  end

  def test_fmt_1
    name = 'skype'
    component = 'ds9-debian-packaging'

    gitrepo = create_fake_git(name: name, component: component, branches: %w[kubuntu_unstable])
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    FileUtils.cp_r("#{data}/.", Dir.pwd, verbose: true)
    CI::Overrides.instance_variable_set(:@default_files, ["#{Dir.pwd}/base.yml"])
    Dir.mktmpdir(self.class.to_s) do |tmpdir|
      Dir.chdir(tmpdir) do
        project = Project.new(name, component, gitrepo, type: 'unstable')
        assert_nil(project.upstream_scm)
      end
    end
  end

  def test_launchpad
    reset_child_status!

    Object.any_instance.expects(:`).never
    Object.any_instance.expects(:system).never

    system_sequence = sequence('test_launchpad-system')
    Object.any_instance.expects(:system)
          .with do |x|
            next unless x =~ /bzr checkout --lightweight lp:unity-action-api ([^\s]+unity-action-api)/

            # .returns runs in a different binding so the chdir is wrong....
            # so we copy here.
            FileUtils.cp_r("#{data}/.", $~[1], verbose: true)
            true
          end
          .returns(true)
          .in_sequence(system_sequence)
    Object.any_instance.expects(:system)
          .with do |x, **kwords|
            x == 'bzr up' && kwords.fetch(:chdir) =~ /[^\s]+unity-action-api/
          end
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

  def test_native_blacklist
    name = 'kinfocenter'
    component = 'gear'

    gitrepo = create_fake_git(name: name, component: component, branches: %w[kubuntu_unstable])
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    Dir.mktmpdir(self.class.to_s) do |tmpdir|
      Dir.chdir(tmpdir) do
        # Should raise on account of KDE Gear being a protected component
        # name which must not contain native stuff.
        assert_raises do
          Project.new(name, component, gitrepo, type: 'unstable')
        end
      end
    end
  end

  def test_snapcraft_detection
    name = 'kinfocenter'
    component = 'gear'

    gitrepo = create_fake_git(name: name, component: component, branches: %w[kubuntu_unstable]) do
      File.write('snapcraft.yaml', '')
    end
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    Dir.mktmpdir(self.class.to_s) do |tmpdir|
      Dir.chdir(tmpdir) do
        # Should raise on account of KDE Gear being a protected component
        # name which must not contain native stuff.
        project = Project.new(name, component, gitrepo, type: 'unstable')
        assert_equal 'snapcraft.yaml', project.snapcraft
        refute project.debian?
      end
    end
  end

  def test_series_restrictions_overrides
    # series_restrictions is an array. overrides originally didn't proper apply
    # for basic data types. this test asserts that this is actually working.
    # for basic data types we want the deserialized object directly applied to
    # the member (i.e. for series_restrictions the overrides array is the final
    # restrictions array).

    name = 'kinfocenter'
    component = 'gear'

    gitrepo = create_fake_git(name: name, component: component, branches: %w[kubuntu_unstable])
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    FileUtils.cp_r("#{data}/.", Dir.pwd, verbose: true)
    CI::Overrides.instance_variable_set(:@default_files, ["#{Dir.pwd}/base.yml"])
    Dir.mktmpdir(self.class.to_s) do |tmpdir|
      Dir.chdir(tmpdir) do
        project = Project.new(name, component, gitrepo, type: 'unstable')
        assert_not_empty(project.series_restrictions)
      end
    end
  end

  def test_useless_native_override
    # overrides are set to not be able to override nil members. nil members
    # would mean the member doesn't exist or it was explicitly left nil.
    # e.g. 'native' packaging forces upstream_scm to be nil because dpkg would
    # not care if we made an upstream tarball anyway. native packaging cannot
    # ever have an upstream_scm!
    # This should raise an error as otherwise it's nigh impossible to figure out
    # why the override doesn't stick.

    name = 'native'
    component = 'componento'

    gitrepo = create_fake_git(name: name, component: component, branches: %w[kubuntu_unstable])
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    FileUtils.cp_r("#{data}/.", Dir.pwd, verbose: true)
    CI::Overrides.instance_variable_set(:@default_files, ["#{Dir.pwd}/base.yml"])
    Dir.mktmpdir(self.class.to_s) do |tmpdir|
      Dir.chdir(tmpdir) do
        assert_nothing_raised do
          Project.new(name, component, gitrepo, type: 'unstable')
        end
      end
    end
  end

  def test_useless_native_override_override
    # since overrides are cascading it can be that a generic rule sets
    # an (incorrect) upstream_scm which we'd ordinarilly refuse to override
    # and fatally error out on when operating on a native package.
    # To bypass this a more specific rule may be set for the specific native
    # package to explicitly force it to nil again. The end result is an
    # override that would attemtp to set upstream_scm to nil, which it
    # already is, so it gets skipped without error.

    name = 'override_override'
    component = 'componento'

    gitrepo = create_fake_git(name: name, component: component, branches: %w[kubuntu_unstable])
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    FileUtils.cp_r("#{data}/.", Dir.pwd, verbose: true)
    CI::Overrides.instance_variable_set(:@default_files, ["#{Dir.pwd}/base.yml"])
    Dir.mktmpdir(self.class.to_s) do |tmpdir|
      Dir.chdir(tmpdir) do
        project = Project.new(name, component, gitrepo, type: 'unstable')
        assert_nil(project.upstream_scm)
      end
    end
  end

  def test_neon_series
    # when a neon repo doesn't have the desired branch, check for a branch
    # named after current series or future series instead. the checkout
    # must not fail so long as either is available

    name = 'test_override_packaging_branch'
    component = 'componento'

    require_relative '../lib/nci'
    NCI.stubs(:current_series).returns('bionic')
    NCI.stubs(:future_series).returns('focal')
    gitrepo = create_fake_git(name: name, component: component, branches: %w[Neon/unstable_focal])
    assert_not_nil(gitrepo)
    assert_not_equal(gitrepo, '')

    FileUtils.cp_r("#{data}/.", Dir.pwd, verbose: true)
    CI::Overrides.instance_variable_set(:@default_files, ["#{Dir.pwd}/base.yml"])
    Dir.mktmpdir(self.class.to_s) do |tmpdir|
      Dir.chdir(tmpdir) do
        project = Project.new(name, component, gitrepo, type: 'unstable', branch: 'Neon/unstable')
        assert_include(project.series_branches, 'Neon/unstable_focal')
        # for the checkout expectations it's sufficient if we got no gitnobranch error raised
      end
    end
  end
end
