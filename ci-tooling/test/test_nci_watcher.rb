# frozen_string_literal: true

# SPDX-FileCopyrightText: 2017-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'

require_relative '../lib/debian/control'
require_relative '../nci/lib/watcher'

require 'mocha/test_unit'
require 'rugged'

class NCIWatcherTest < TestCase
  attr_reader :cmd

  def setup
    @cmd = TTY::Command.new(printer: :null)
    NCI.stubs(:setup_env!).returns(true)
    # Rip out causes from the test env so we don't trigger on them.
    NCI::Watcher::CAUSE_ENVS.each { |e| ENV.delete(e) }
    ENV['JOB_NAME'] = 'HIIIIYA'
  end

  def with_remote_repo(seed_dir)
    Dir.mktmpdir do |tmpdir|
      FileUtils.cp_r("#{seed_dir}/.", tmpdir, verbose: true)
      cmd.run('git init .', chdir: tmpdir)
      cmd.run('git add .', chdir: tmpdir)
      cmd.run('git commit -a -m "import"', chdir: tmpdir)
      cmd.run('git branch Neon/unstable', chdir: tmpdir)
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

      # New changelog entry
      assert_equal '4:17.04.2-0neon', Changelog.new.version
      control = Debian::Control.new
      control.parse!
      # fooVersion~ciBuild suitably replaced.
      assert_equal '4:17.04.2', control.binaries[0]['depends'][0][0].version
      assert_equal '4:17.04.2', control.binaries[0]['recommends'][0][0].version

      repo = Rugged::Repository.new(Dir.pwd)
      commit = repo.last_commit
      assert_includes commit.message, 'release'
      deltas = commit.diff(commit.parents[0]).deltas
      assert_equal 2, deltas.size
      changed_files = deltas.collect { |d| d.new_file[:path] }
      assert_equal ['debian/changelog', 'debian/control'], changed_files

      # watch file was unmanagled again
      assert_path_exist 'debian/watch'
      assert_includes File.read('debian/watch'), 'download.kde.org'
      assert_includes File.read('debian/watch'), 'https'
      assert_not_includes File.read('debian/watch'), 'download.kde.internal.neon.kde.org'
      assert_not_includes File.read('debian/watch'), 'download.kde.internal.neon.kde.org:9191'
    end
  end

  def test_no_mail_on_manual_trigger
    ENV['JOB_NAME'] = 'watcher_release_kde_ark'

    require_binaries(%w[dch])
    Pangea::SMTP.expects(:start).never

    ENV['BUILD_CAUSE'] = 'MANUALTRIGGER'

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
  ensure
    ENV.delete('BUILD_CAUSE')
  end

  def test_no_unstable
    # Should not smtp or anything.
    with_remote_repo(data) do |remote|
      cmd.run("git clone #{remote} .")

      NCI::Watcher.new.run
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
    require_binaries(%w[dch])

    smtp = mock('smtp')
    smtp.expects(:send_message).with do |_body, from, to|
      from == 'no-reply@kde.org' && to == 'neon-notifications@kde.org'
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
  end
end
