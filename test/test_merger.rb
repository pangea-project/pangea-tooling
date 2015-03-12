require 'fileutils'
require 'git'
require 'test/unit'
require 'tmpdir'

require_relative '../kci/merger'

class MergerTest < Test::Unit::TestCase
  def in_repo(&block)
    Dir.mktmpdir(__callee__.to_s) do |t|
      g = Git.clone(repo, t)
      g.chdir do
        yield g
      end
    end
  end

  def create_sample_branch(g, name)
    g.checkout('master')
    g.checkout(name, new_branch: true)
    FileUtils.touch("#{name}file")
    g.add("#{name}file")
    g.commit_all("#{name}msg")
    g.push('origin', name)
  end

  def create_remote
    return @remotedir if @remotedir

    @remotedir = "#{@tmpdir}/remote"
    puts ":::: creating #{@remotedir}"
    Dir.mkdir(@remotedir)
    Dir.chdir(@remotedir) { Git.init('.', bare: true) }

    @remotedir
  end

  def repo
    return @remotedir if @remotedir

    @remotedir = create_remote

    in_repo do |g|
      FileUtils.touch('masterfile')
      g.add('masterfile')
      g.commit_all('mastermsg')
      g.push

      # Create all default branches
      create_sample_branch(g, 'kubuntu_unstable')
    end

    @remotedir
  end

  def setup
    @tmpdir = Dir.mktmpdir(self.class.to_s)
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir('/')
    FileUtils.rm_rf(@tmpdir)
    @remotedir = nil
  end

  def test_full_merge_chain
    in_repo do |g|
      create_sample_branch(g, 'kubuntu_vivid_archive')
      create_sample_branch(g, 'kubuntu_stable')
      create_sample_branch(g, 'kubuntu_stable_utopic')
      # NOTE: unstable already exists
      create_sample_branch(g, 'kubuntu_unstable_utopic')
    end

    in_repo do
      assert_nothing_raised { Merger.new.run('origin/kubuntu_vivid_archive') }
    end

    in_repo do |g|
      assert_nothing_raised do
        g.checkout('kubuntu_stable')
      end
      assert(File.exist?('kubuntu_vivid_archivefile'))
      assert(File.exist?('kubuntu_stablefile'))

      assert_nothing_raised do
        g.checkout('kubuntu_stable_utopic')
      end
      assert(File.exist?('kubuntu_vivid_archivefile'))
      assert(File.exist?('kubuntu_stablefile'))
      assert(File.exist?('kubuntu_stable_utopicfile'))

      assert_nothing_raised do
        g.checkout('kubuntu_unstable')
      end
      assert(File.exist?('kubuntu_vivid_archivefile'))
      assert(File.exist?('kubuntu_stablefile'))
      assert(File.exist?('kubuntu_unstablefile'))

      assert_nothing_raised do
        g.checkout('kubuntu_unstable_utopic')
      end
      assert(File.exist?('kubuntu_vivid_archivefile'))
      assert(File.exist?('kubuntu_stablefile'))
      assert(File.exist?('kubuntu_unstablefile'))
      assert(File.exist?('kubuntu_unstable_utopicfile'))
    end
  end

  def test_stable_trigger
    in_repo do |g|
      g.checkout('master')
      g.checkout('kubuntu_stable', new_branch: true)
      FileUtils.touch('stablefile')
      g.add('stablefile')
      g.commit_all('stablemsg')
      g.push('origin', 'kubuntu_stable')

      g.checkout('master')
      g.checkout('kubuntu_stable_utopic', new_branch: true)
      g.push('origin', 'kubuntu_stable_utopic')
    end

    in_repo do
      Merger.new.run('origin/kubuntu_stable')
    end

    in_repo do |g|
      assert_nothing_raised { g.checkout('kubuntu_stable_utopic') }
      assert(File.exist?('stablefile'), 'Apparently stable did not get merged into stable_utopic')
    end
  end

  # Merging without unstable shouldn't fail as there are cases when
  # there really only is a stable branch.
  def test_no_unstable
    in_repo do |g|
      create_sample_branch(g, 'kubuntu_stable')
      # Ditch kubuntu_unstable
      g.push('origin', ':kubuntu_unstable')
    end

    in_repo do
      assert_nothing_raised do
        Merger.new.run('origin/kubuntu_stable')
      end
    end
  end

  def test_fail_no_ci_branch
    in_repo do |g|
      # Ditch kubuntu_unstable
      g.push('origin', ':kubuntu_unstable')
    end

    in_repo do
      assert_raise do
        Merger.new.run('origin/master')
      end
    end
  end

  # Merging without unstable shouldn't fail as there are cases when
  # there really only is a stable branch.
  def test_no_master
    # Bypass auto-init so we get a completely bare repo.
    @remotedir = create_remote
    in_repo do |g|
      branch = 'kubuntu_stable'
      g.checkout(branch, new_branch: true)
      FileUtils.touch('file')
      g.add('file')
      g.commit_all('message')
      g.push('origin', branch)
    end

    # Make sure we have no master
    in_repo do |g|
      remotes = g.branches.remote.select { |b| b.name == 'master' }
      assert(remotes.empty?, 'There is a remote master. Should not be there.')
    end

    in_repo do
      # We currently have no current_branch, make sure we don't fall over dead.
      assert_nothing_raised do
        Merger.new.run('origin/kubuntu_stable')
      end
      # We now do have a current_branch, make sure it's still fine.
      assert_nothing_raised do
        Merger.new.run('origin/kubuntu_stable')
      end
    end
  end
end
