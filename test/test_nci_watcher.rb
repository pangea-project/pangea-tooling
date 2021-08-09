# frozen_string_literal: true

# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'

require_relative '../lib/debian/control'
require_relative '../nci/lib/watcher'
require_relative '../lib/kdeproject_component'

require 'mocha/test_unit'
require 'rugged'

class NCIWatcherTest < TestCase
  attr_reader :cmd

  def setup
    @cmd = TTY::Command.new(printer: :null)
    NCI.stubs(:setup_env!).returns(true)
    # Rip out causes from the test env so we don't trigger on them.
    NCI::Watcher::CAUSE_ENVS.each { |e| ENV.delete(e) }
    ENV['JOB_NAME'] = 'watcher_release_kde_ark'

    stub_request(:get, 'https://projects.kde.org/api/v1/projects/frameworks')
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Ruby'
        }
      )
      .to_return(status: 200, body: '["frameworks/attica","frameworks/baloo","frameworks/bluez-qt","frameworks/breeze-icons"]', headers: { "Content-Type": 'application/json' })

    stub_request(:get, 'https://invent.kde.org/sdk/releaseme/-/raw/master/plasma/git-repositories-for-release-normal')
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Ruby'
        }
      )
      .to_return(status: 200, body: 'bluedevil breeze breeze-grub breeze-gtk breeze-plymouth discover drkonqi', headers: { "Content-Type": 'text/plain' })

    stub_request(:get, 'https://invent.kde.org/sysadmin/release-tools/-/raw/master/modules.git')
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Ruby'
        }
      )
      .to_return(status: 200, body: "kdialog                                     master\nkeditbookmarks                              master", headers: { "Content-Type": 'text/plain' })


    stub_request(:get, 'https://invent.kde.org/sdk/releaseme/-/raw/master/plasma/git-repositories-for-release')
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Ruby'
        }
      )
      .to_return(status: 200, body: "bluedevil breeze breeze-grub breeze-gtk breeze-plymouth discover drkonqi kactivitymanagerd kde-cli-tools kde-gtk-config kdecoration kdeplasma-addons kgamma5 khotkeys kinfocenter kmenuedit kscreen kscreenlocker ksshaskpass ksystemstats kwallet-pam kwayland-integration kwayland-server kwin kwrited layer-shell-qt libkscreen libksysguard milou oxygen plasma-browser-integration plasma-desktop plasma-disks plasma-firewall plasma-integration plasma-nano plasma-nm plasma-pa plasma-phone-components plasma-sdk plasma-systemmonitor plasma-tests plasma-thunderbolt plasma-vault plasma-workspace plasma-workspace-wallpapers plymouth-kcm polkit-kde-agent-1 powerdevil qqc2-breeze-style sddm-kcm systemsettings xdg-desktop-portal-kde", headers: { "Content-Type": 'text/plain' })
  end

  def with_remote_repo(seed_dir, branch: 'unstable')
    Dir.mktmpdir do |tmpdir|
      FileUtils.cp_r("#{seed_dir}/.", tmpdir, verbose: true)
      cmd.run('git init .', chdir: tmpdir)
      cmd.run('git add .', chdir: tmpdir)
      cmd.run('git commit -a -m "import"', chdir: tmpdir)
      cmd.run("git branch Neon/#{branch}", chdir: tmpdir)
      yield tmpdir
    end
  end

  def test_run
    ENV['JOB_NAME'] = 'watcher_release_kde_ark'

    require_binaries(%w[dch])

    smtp = mock('smtp')
    smtp.expects(:send_message).with do |_body, from, to|
      from == 'no-reply@kde.org' && to == 'neon-notifications@kde.org'
    end
    Pangea::SMTP.expects(:start).yields(smtp)

    with_remote_repo(data) do |remote|
      cmd.run("git clone #{remote} .")

      fake_cmd = mock('uscan_cmd')
      fake_cmd
        .expects(:run!)
        .with do |args|
          # hijack and do some assertion here. This block is only evaluated upon
          # a call to run, so we can assert the state of the working dir when
          # uscan gets called here.
          assert_path_exist 'debian/watch'
          assert_includes File.read('debian/watch'), 'download.kde.internal.neon.kde.org'
          assert_includes File.read('debian/watch'), 'https'
          assert_not_includes File.read('debian/watch'), 'download.kde.org'
          args == 'uscan --report --dehs'
        end
        .returns(TTY::Command::Result.new(0, File.read(data('dehs.xml')), ''))
      NCI::Watcher.any_instance.stubs(:uscan_cmd).returns(fake_cmd)

      NCI::Watcher.new.run

      Dir.chdir('deb-packaging') do
        # New changelog entry
        assert_equal '4:17.04.2-0neon', Changelog.new.version
        control = Debian::Control.new
        control.parse!
        # fooVersion~ciBuild suitably replaced.
        assert_equal '4:17.04.2', control.binaries[0]['depends'][0][0].version
        assert_equal '4:17.04.2', control.binaries[0]['recommends'][0][0].version
      end

        repo = Rugged::Repository.new(Dir.pwd)
        commit = repo.last_commit
        assert_includes commit.message, 'release'
        deltas = commit.diff(commit.parents[0]).deltas
        assert_equal 2, deltas.size
        changed_files = deltas.collect { |d| d.new_file[:path] }
        assert_equal ['deb-packaging/debian/changelog', 'deb-packaging/debian/control'], changed_files

        # watch file was unmanagled again
        assert_path_exist 'deb-packaging/debian/watch'
        assert_includes File.read('deb-packaging/debian/watch'), 'download.kde.org'
        assert_includes File.read('deb-packaging/debian/watch'), 'https'
        assert_not_includes File.read('deb-packaging/debian/watch'), 'download.kde.internal.neon.kde.org'
        assert_not_includes File.read('deb-packaging/debian/watch'), 'download.kde.internal.neon.kde.org:9191'
    end
  end

  def test_no_mail_on_manual_trigger
    ENV['JOB_NAME'] = 'watcher_release_kde_ark'

    require_binaries(%w[dch])
    Pangea::SMTP.expects(:start).never

    ENV['BUILD_CAUSE'] = 'MANUALTRIGGER'

    with_remote_repo(data, branch: 'stable') do |remote|
      cmd.run("git clone #{remote} .")

      fake_cmd = mock('uscan_cmd')
      fake_cmd
        .expects(:run!)
        .with('uscan --report --dehs')
        .returns(TTY::Command::Result.new(0, File.read(data('dehs.xml')), ''))
      NCI::Watcher.any_instance.stubs(:uscan_cmd).returns(fake_cmd)

      NCI::Watcher.new.run
    end
  ensure
    ENV.delete('BUILD_CAUSE')
  end

  def test_no_unstable
    # Should not smtp or anything.
    assert_raises NCI::Watcher::UnstableURIForbidden do
      with_remote_repo(data) do |remote|
        cmd.run("git clone #{remote} .")

        NCI::Watcher.new.run
      end
    end
  end

  def test_snapcraft_updater
    FileUtils.cp_r("#{data}/.", '.')
    dehs = mock('dehs')
    dehs.stubs(:upstream_version).returns('18.14.1')
    # NB: watcher doesn't unmangle itself, we expect the updater to do it
    dehs.stubs(:upstream_url).returns('https://download.kde.internal.neon.kde.org/okular-18.14.1.tar.xz')
    NCI::Watcher::SnapcraftUpdater.new(dehs).run
    actual = YAML.load_file('snapcraft.yaml')
    expected = YAML.load_file('snapcraft.yaml.ref')
    assert_equal(expected, actual)
  end

  def test_3rdparty_manual_trigger_fail_no_mail
    ENV['BUILD_CAUSE'] = 'MANUALTRIGGER'
    require_binaries(%w[dch])

    Pangea::SMTP.expects(:start).never

    assert_raises NCI::Watcher::NotKDESoftware do
      with_remote_repo(data) do |remote|
        cmd.run("git clone #{remote} .")

        fake_cmd = mock('uscan_cmd')
        fake_cmd
          .expects(:run!)
          .with('uscan --report --dehs')
          .returns(TTY::Command::Result.new(0, File.read(data('dehs.xml')), ''))
        NCI::Watcher.any_instance.stubs(:uscan_cmd).returns(fake_cmd)

        NCI::Watcher.new.run
      end
    end
  end

  def test_3rdparty_time_trigger_mail_and_fail
    ENV['BUILD_CAUSE'] = 'TIMERTRIGGER'
    ENV['JOB_NAME'] = 'watcher_release_kde_ark'
    require_binaries(%w[dch])

    smtp = mock('smtp')
    match_body = nil # for asserting the body content later
    smtp.expects(:send_message).with do |body, from, to|
      match = from == 'no-reply@kde.org' && to == 'neon-notifications@kde.org'
      next false unless match

      match_body = body
      true
    end
    Pangea::SMTP.expects(:start).yields(smtp)

    assert_raises NCI::Watcher::NotKDESoftware do
      with_remote_repo(data) do |remote|
        cmd.run("git clone #{remote} .")

        fake_cmd = mock('uscan_cmd')
        fake_cmd
          .expects(:run!)
          .with('uscan --report --dehs')
          .returns(TTY::Command::Result.new(0, File.read(data('dehs.xml')), ''))
        NCI::Watcher.any_instance.stubs(:uscan_cmd).returns(fake_cmd)

        NCI::Watcher.new.run
      end
    end

    # If this is the expected invocation assert that the body is well formed.
    # Specifically the headers mustn't be indented as can happen with heredoc.
    # Split by \n\n to isolate the header block.
    assert(match_body)
    lines = match_body.split("\n\n", 2)[0].lines
    lines = lines.collect(&:rstrip) # strip trailing \n for easy compare
    refute(lines.empty?)
    assert_includes(lines, 'From: Neon CI <no-reply@kde.org>')
    assert_includes(lines, 'To: neon-notifications@kde.org')
    assert_includes(lines, 'Subject: Dev Required: ark - 17.04.2')
  end
end
