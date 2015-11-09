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
    (1..16).each do |i|
      dir = "#{buildsdir}/#{i}"
      FileUtils.mkpath(dir)
      %w(build.xml log log.html log_ref.html).each do |file|
        age = (16 - i)
        FileUtils.touch("#{dir}/#{file}", mtime: (DateTime.now - age).to_time)
      end
    end
    # 17 is a symlink to itself. For some reason this can happen
    File.symlink('17', "#{buildsdir}/17")
    # Static links
    File.symlink('2', "#{buildsdir}/lastFailedBuild")
    File.symlink('-1', "#{buildsdir}/lastUnstableBuild")
    File.symlink('11', "#{buildsdir}/lastUnsuccessfulBuild")
    File.symlink('14', "#{buildsdir}/lastStableBuild")
    File.symlink('14', "#{buildsdir}/lastSuccessfulBuild")

    # At this point 16-3 do not qualify for pruning on account of being too new.
    # 2 and 1 are old enough. Only 1 can be removed though as 2 is pointed to
    # by a reference symlink.

    # We now set build 15 to a very old mtime to make sure it doesn't get
    # deleted either as we always keep the last 7 builds
    FileUtils.touch("#{buildsdir}/15/log", mtime: (DateTime.now - 32).to_time)

    Dir.glob('jobs/*').each do |jobdir|
      Jenkins::JobDir.prune_logs(jobdir)
    end

    %w(lastFailedBuild lastStableBuild lastSuccessfulBuild lastUnstableBuild lastUnsuccessfulBuild).each do |d|
      dir = "#{buildsdir}/#{d}"
      # unstable is symlink to -1 == invalid by default!
      assert_path_exist(dir) unless d == 'lastUnstableBuild'
      assert(File.symlink?(dir), "#{dir} was supposed to be a symlink but isn't")
    end

    # Pointed to by symlinks, mustn't be deleted
    assert_path_exist("#{buildsdir}/2/log")
    assert_path_exist("#{buildsdir}/3/log")
    assert_path_exist("#{buildsdir}/11/log")
    assert_path_exist("#{buildsdir}/14/log")

    # Keeps last 6 builds regardless of mtime. 15 had a very old mtime.
    assert_path_exist("#{buildsdir}/15/log")

    # Deletes only builds older than 14 days.
    assert_path_not_exist("#{buildsdir}/1/log")
  end
end
