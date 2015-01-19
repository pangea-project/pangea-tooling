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
    g.checkout('master', new_branch: name)
    FileUtils.touch("#{name}file")
    g.add("#{name}file")
    g.commit_all("#{name}msg")
    g.push('origin', name)
  end

  def repo
    return @remotedir if @remotedir

    @remotedir = "#{@tmpdir}/remote"
    puts ":::: creating #{@remotedir}"
    Dir.mkdir(@remotedir)
    Dir.chdir(@remotedir) { Git.init('.', bare: true) }

    in_repo do |g|
      FileUtils.touch('masterfile')
      g.add('masterfile')
      g.commit_all('mastermsg')
      g.push

      # Create all default branches
      create_sample_branch(g, 'kubuntu_unstable')
    end

    return @remotedir
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
      g.checkout('master', new_branch: 'kubuntu_stable')
      FileUtils.touch('stablefile')
      g.add('stablefile')
      g.commit_all('stablemsg')
      g.push('origin', 'kubuntu_stable')

      g.checkout('master', new_branch: 'kubuntu_stable_utopic')
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
end
