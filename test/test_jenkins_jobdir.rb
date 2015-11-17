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
end
