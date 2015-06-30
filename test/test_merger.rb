require 'fileutils'
require 'git'
require 'test/unit'
require 'tmpdir'

require_relative '../kci/merger'

class MergerTest < Test::Unit::TestCase
  def in_repo(&_block)
    Dir.mktmpdir(__callee__.to_s) do |t|
      g = Git.clone(repo, t)
      g.chdir do
        yield g
      end
    end
  end

  def create_sample_file(g, name)
    FileUtils.touch("#{name}file")
    g.add("#{name}file")
    g.commit_all("#{name}msg")
  end

  def create_sample_branch(g, name)
    g.checkout('master')
    g.checkout(name, new_branch: true)
    create_sample_file(g, name)
    g.push('origin', name)
  end

  def repo(dirname = '')
    return @remotedir if @remotedir

    @remotedir = "#{@tmpdir}/remote/#{dirname}"
    FileUtils.mkpath(@remotedir)
    Dir.chdir(@remotedir) { Git.init('.', bare: true) }

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
  end

  def test_full_merge_chain
    in_repo do |g|
      create_sample_branch(g, 'kubuntu_vivid_archive')
      create_sample_branch(g, 'kubuntu_vivid_backports')
      create_sample_branch(g, 'kubuntu_stable')
      create_sample_branch(g, 'kubuntu_stable_vivid')
      # NOTE: unstable already exists
      create_sample_branch(g, 'kubuntu_unstable_vivid')
    end

    in_repo do
      assert_nothing_raised { Merger.new.run('origin/kubuntu_vivid_archive') }
    end

    in_repo do |g|
      # backports merges archive
      assert_nothing_raised do
        g.checkout('kubuntu_vivid_backports')
      end
      assert(File.exist?('kubuntu_vivid_archivefile'))
      assert(File.exist?('kubuntu_vivid_backportsfile'))

      assert_nothing_raised do
        g.checkout('kubuntu_stable')
      end
      assert(File.exist?('kubuntu_vivid_archivefile'))
      assert(File.exist?('kubuntu_vivid_backportsfile'))
      assert(File.exist?('kubuntu_stablefile'))

      assert_nothing_raised do
        g.checkout('kubuntu_stable_vivid')
      end
      assert(File.exist?('kubuntu_vivid_archivefile'))
      assert(File.exist?('kubuntu_vivid_backportsfile'))
      assert(File.exist?('kubuntu_stablefile'))
      assert(File.exist?('kubuntu_stable_vividfile'))

      assert_nothing_raised do
        g.checkout('kubuntu_unstable')
      end
      assert(File.exist?('kubuntu_vivid_archivefile'))
      assert(File.exist?('kubuntu_vivid_backportsfile'))
      assert(File.exist?('kubuntu_stablefile'))
      assert(File.exist?('kubuntu_unstablefile'))

      assert_nothing_raised do
        g.checkout('kubuntu_unstable_vivid')
      end
      assert(File.exist?('kubuntu_vivid_archivefile'))
      assert(File.exist?('kubuntu_vivid_backportsfile'))
      assert(File.exist?('kubuntu_stablefile'))
      assert(File.exist?('kubuntu_unstablefile'))
      assert(File.exist?('kubuntu_unstable_vividfile'))
    end
  end

  def test_merge_debian_for_frameworks
    # Initialize the repo with a path that will trigger advanced merging.
    repo('git.debian.org/frameworks/random')

    in_repo do |g|
      g.checkout('master')
      create_sample_file(g, 'verifymastermerge')
      g.push('origin', 'master')
    end

    in_repo do
      assert_nothing_raised { Merger.new.run('origin/kubuntu_vivid_archive') }
    end

    in_repo do |g|
      assert_nothing_raised do
        g.checkout('master')
      end
      assert(File.exist?('masterfile'))
      assert(File.exist?('verifymastermergefile'))

      assert_nothing_raised do
        g.checkout('kubuntu_unstable')
      end
      assert(File.exist?('masterfile'))
      assert(File.exist?('verifymastermergefile'))
      assert(File.exist?('kubuntu_unstablefile'))
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
      g.checkout('kubuntu_stable_vivid', new_branch: true)
      g.push('origin', 'kubuntu_stable_vivid')
    end

    in_repo do
      Merger.new.run('origin/kubuntu_stable')
    end

    in_repo do |g|
      assert_nothing_raised { g.checkout('kubuntu_stable_vivid') }
      assert(File.exist?('stablefile'), 'Apparently stable did not get merged into stable_vivid')
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

  def test_no_noci_keyword_merge
    # Merge without NOCI to make sure it doesn't mark NOCI what it shouldn't.
    # FIXME: partial code copy
    in_repo do |g|
      create_sample_branch(g, 'kubuntu_vivid_archive')

      g.checkout('kubuntu_unstable')
      g.merge('origin/kubuntu_vivid_archive')
      g.push('origin', 'kubuntu_unstable')

      g.checkout('kubuntu_vivid_archive')
      FileUtils.touch('randomfile')
      g.add('randomfile')
      g.commit_all('randommsg')
      g.push('origin', 'kubuntu_vivid_archive')

      g.checkout('kubuntu_unstable')
      log = g.log.between('', 'kubuntu_vivid_archive')
      assert_false(log.first.message.include?('NOCI'))
    end

    in_repo do
      Merger.new.run('origin/kubuntu_vivid_archive')
    end

    in_repo do |g|
      g.checkout('kubuntu_unstable')
      assert(g.log.size >= 1)
      commit = g.log.first
      assert_equal(2, commit.parents.size) # Is a merge.
      assert_not_include(commit.message, 'NOCI')
    end
  end

  def test_noci_keyword_merge
    in_repo do |g|
      create_sample_branch(g, 'kubuntu_vivid_archive')

      g.checkout('kubuntu_unstable')
      g.merge('origin/kubuntu_vivid_archive')
      g.push('origin', 'kubuntu_unstable')

      g.checkout('kubuntu_vivid_archive')
      FileUtils.touch('randomfile')
      g.add('randomfile')
      g.commit_all("randommsg\n\nNOCI")
      g.push('origin', 'kubuntu_vivid_archive')

      g.checkout('kubuntu_unstable')
      log = g.log.between('', 'kubuntu_vivid_archive')
      assert(log.first.message.include?('NOCI'))
    end

    in_repo do
      Merger.new.run('origin/kubuntu_vivid_archive')
    end

    in_repo do |g|
      g.checkout('kubuntu_unstable')
      assert(g.log.size >= 1)
      commit = g.log.first
      assert_equal(2, commit.parents.size) # Is a merge.
      assert_include(commit.message, 'NOCI')
    end
  end

  def test_oudated_master
    # In the past it has happened that master while forced cleanup target is not
    # being checked out first which in turn means that the reset done as part
    # of cleanup doesn't actually affect the local master.
    # As part of merging however local branches take preference over remote
    # ones since we do chain merging we need to hold local changes and then
    # push them all at once.
    # e.g.
    # origin/kubuntu_wily_archive -> kubuntu_stable (remote into local)
    #   -> kubuntu_stable -> kubuntu_unstable (local into local)
    # :push:
    # Since we always have a local master due to the cleanup routine we must
    # forcefully check it out before cleanup.

    # Init repo name with git.debian in the path so that the advanced debian
    # merge logic runs.
    repo('git.debian.org/frameworks/random')

    # Create the sample branch.
    in_repo do |g|
      create_sample_branch(g, 'kubuntu_unstable')
    end

    # Run merger. We now have a local master and a local kubuntu_unstable...
    in_repo do
      Merger.new.run('origin/kubuntu_unstable')
    end

    # Diverge master.
    in_repo do |g|
      g.checkout('master')
      FileUtils.touch('randomfile')
      g.add('randomfile')
      g.commit_all('axios')
      g.push('origin', 'master')
    end

    # Run merger again. Must now merge randomfile even though we are on
    # a kubuntu_unstable checkout!
    in_repo do |g|
      g.checkout('kubuntu_unstable')
      Merger.new.run('origin/master')
    end

    in_repo do |g|
      g.checkout('kubuntu_unstable')
      assert(g.log.size >= 1)
      commit = g.log.first
      assert_equal(2, commit.parents.size) # Is a merge.
      assert_path_exist('randomfile')
    end
  end
end
