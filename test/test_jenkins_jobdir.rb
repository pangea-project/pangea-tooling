require 'date'

require_relative '../lib/jenkins/jobdir'
require_relative '../ci-tooling/test/lib/testcase'

class JenkinsJobDirTest < TestCase
  def setup
    @home = ENV.fetch('HOME')
    ENV['HOME'] = Dir.pwd
  end

  def teardown
    ENV['HOME'] = @home
  end

  def test_prune
    buildsdir = "jobs/#{__method__}/builds"
    FileUtils.mkpath(buildsdir)
    (1000..1016).each do |i|
      dir = "#{buildsdir}/#{i}"
      FileUtils.mkpath(dir)
      age = (1016 - i)
      mtime = (DateTime.now - age).to_time
      %w(build.xml log log.html log_ref.html).each do |file|
        FileUtils.touch("#{dir}/#{file}", mtime: mtime)
      end
      FileUtils.mkpath("#{dir}/archive/randomdir")
      FileUtils.touch("#{dir}/archive", mtime: mtime)
      FileUtils.touch("#{dir}/archive/randomdir/artifact", mtime: mtime)
    end
    # 1017 is a symlink to itself. For some reason this can happen
    File.symlink('1017', "#{buildsdir}/1017")
    # Static links
    File.symlink('1002', "#{buildsdir}/lastFailedBuild")
    File.symlink('-1', "#{buildsdir}/lastUnstableBuild")
    File.symlink('1011', "#{buildsdir}/lastUnsuccessfulBuild")
    File.symlink('1014', "#{buildsdir}/lastStableBuild")
    File.symlink('1014', "#{buildsdir}/lastSuccessfulBuild")
    # Really old plunder but protected name.
    FileUtils.touch("#{buildsdir}/legacyIds", mtime: (DateTime.now - 300).to_time)

    very_old_mtime = (DateTime.now - 32).to_time

    # On mobile.kci we had prunes on logs only. So we need to make sure
    # archives are pruned even if they have no log
    FileUtils.mkpath("#{buildsdir}/999/archive")
    FileUtils.touch("#{buildsdir}/999/archive", mtime: very_old_mtime)

    # At this point 1016-3 do not qualify for pruning on account of being too
    # new. 2 and 1 are old enough. Only 1 can be removed though as 2 is pointed
    # to by a reference symlink.

    # We now set build 1015 to a very old mtime to make sure it doesn't get
    # deleted either as we always keep the last 7 builds
    FileUtils.touch("#{buildsdir}/1015/log", mtime: very_old_mtime)

    Dir.glob('jobs/*').each do |jobdir|
      Jenkins::JobDir.prune(jobdir)
    end

    %w(lastFailedBuild lastStableBuild lastSuccessfulBuild lastUnstableBuild lastUnsuccessfulBuild).each do |d|
      dir = "#{buildsdir}/#{d}"
      # unstable is symlink to -1 == invalid by default!
      assert_path_exist(dir) unless d == 'lastUnstableBuild'
      assert(File.symlink?(dir), "#{dir} was supposed to be a symlink but isn't")
    end
    # Protected but not a symlink
    assert_path_exist("#{buildsdir}/legacyIds")

    markers = %w(log archive/randomdir)

    # Pointed to by symlinks, mustn't be deleted
    %w(1002 1003 1011 1014).each do |build|
      markers.each { |m| assert_path_exist("#{buildsdir}/#{build}/#{m}") }
    end

    # Keeps last 6 builds regardless of mtime. 1015 had a very old mtime.
    markers.each { |m| assert_path_exist("#{buildsdir}/1015/#{m}") }

    # Deletes only builds older than 14 days.
    markers.each { |m| assert_path_not_exist("#{buildsdir}/1000/#{m}") }

    assert_path_not_exist("#{buildsdir}/999/archive")
  end

  def test_prune_builds
    backupdir = "jobs/#{__method__}/builds-backup"
    buildsdir = "jobs/#{__method__}/builds"
    FileUtils.mkpath(buildsdir)
    (1000..1020).each do |i|
      dir = "#{buildsdir}/#{i}"
      FileUtils.mkpath(dir)
      # Decrease age and then multiply by days-in-week to get a build per week.
      # With 20 that gives us 120 days, or 4 months.
      age = (1020 - i) * 7
      mtime = (DateTime.now - age).to_time
      FileUtils.touch(dir, mtime: mtime)
    end

    Dir.glob('jobs/*').each do |jobdir|
      FileUtils.mkpath(backupdir) unless Dir.exist?(backupdir)
      # File older than 2 months
      Jenkins::JobDir.each_ancient_build(jobdir, min_count: 4, max_age: 7 * 4 * 2) do |ancient_build|
        FileUtils.mv(ancient_build, backupdir)
      end
    end

    # 1011 would be 9 weeks, we assume a month has 4 weeks. We expect 2 months
    # retained and the older ones as backup.
    (1000..1011).each do |i|
      assert_path_exist("#{backupdir}/#{i}")
    end

    (1012..1020).each do |i|
      assert_path_exist("#{buildsdir}/#{i}")
    end
  end
end
