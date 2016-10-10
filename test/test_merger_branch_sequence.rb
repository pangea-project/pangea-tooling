require 'rugged'

require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/merger/branch_sequence'

require 'logger'

class BranchSequenceTest < TestCase
  def in_repo(&_block)
    Dir.mktmpdir(__callee__.to_s) do |t|
      g = Git.clone(repo_path, t)
      g.config('user.name', 'KCIMerger Test')
      g.config('user.email', 'noreply')
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

  def rugged_commit_all(repo)
    index = repo.index
    index.add_all
    index.write
    tree = index.write_tree

    author = { name: 'Test', email: 'test@test.com', time: Time.now }
    parents = repo.empty? || repo.head_unborn? ? [] : [repo.head.target]

    Rugged::Commit.create(repo,
                          author: author,
                          message: 'commitmsg',
                          committer: author,
                          parents: parents,
                          tree: tree,
                          update_ref: 'HEAD')
  end

  def rugged_push_all(repo)
    origin = repo.remotes['origin']
    repo.references.each_name do |r|
      origin.push(r)
    end
  end

  def git_add_file(name, branch)
    rugged_in_repo(checkout_branch: branch) do |repo|
      FileUtils.touch(name)
      rugged_commit_all(repo)
    end
  end

  def rugged_in_repo(**kwords, &_block)
    Dir.mktmpdir(__callee__.to_s) do |t|
      repo = Rugged::Repository.clone_at(repo_path, t, **kwords)
      Dir.chdir(repo.workdir) do
        yield repo
      end
    end
  end

  def git_branch(from: nil, branches:)
    kwords = from ? { checkout: from } : {}
    rugged_in_repo(**kwords) do |repo|
      branches.each do |branch|
        if repo.head_unborn?
          repo.head = "refs/heads/#{branch}"
          rugged_commit_all(repo)
        end
        repo.create_branch(branch) unless repo.branches.exist?(branch)
      end
      rugged_push_all(repo)
    end
  end

  def git_init_repo(path)
    FileUtils.mkpath(path)
    Rugged::Repository.init_at(path, :bare)
    File.absolute_path(path)
  end

  def init_repo_path
    @remotedir = "#{@tmpdir}/remote"
    FileUtils.mkpath(@remotedir)
    git_init_repo(@remotedir)
    rugged_in_repo do |repo|
      rugged_push_all(repo)
    end
    @remotedir
  end

  def repo_path
    @remotedir ||= init_repo_path
  end

  def test_full_sequence
    rugged_in_repo do |repo|
      repo.head = 'refs/heads/Neon/stable'
      FileUtils.touch('stable_c1')
      rugged_commit_all(repo)

      repo.create_branch('Neon/unstable', 'Neon/stable')
      repo.checkout('Neon/unstable')
      FileUtils.touch('unstable_c1')
      rugged_commit_all(repo)

      repo.create_branch('Neon/unstable-very', 'Neon/unstable')
      repo.checkout('Neon/unstable-very')
      FileUtils.touch('unstable-very_c1')
      rugged_commit_all(repo)

      repo.checkout('Neon/stable')
      FileUtils.touch('stable_c2')
      rugged_commit_all(repo)

      rugged_push_all(repo)
    end

    in_repo do |g|
      BranchSequence.new('Neon/stable', git: g)
                    .merge_into('Neon/unstable')
                    .merge_into('Neon/unstable-very')
                    .push
    end

    in_repo do |g|
      g.checkout('Neon/unstable')
      assert_path_exist('stable_c1')
      assert_path_exist('stable_c2')
      assert_path_exist('unstable_c1')

      g.checkout('Neon/unstable-very')
      assert_path_exist('stable_c1')
      assert_path_exist('stable_c2')
      assert_path_exist('unstable_c1')
      assert_path_exist('unstable-very_c1')
    end
  end

  def test_no_stable
    rugged_in_repo do |repo|
      repo.head = 'refs/heads/Neon/unstable'
      FileUtils.touch('unstable_c1')
      rugged_commit_all(repo)

      rugged_push_all(repo)
    end

    in_repo do |g|
      BranchSequence.new('Neon/stable', git: g)
                    .merge_into('Neon/unstable')
                    .push
    end

    in_repo do |g|
      g.checkout('Neon/unstable')
      assert_path_exist('unstable_c1')
    end
  end

  def test_no_unstable
    rugged_in_repo do |repo|
      repo.head = 'refs/heads/Neon/stable'
      FileUtils.touch('stable_c1')
      rugged_commit_all(repo)

      rugged_push_all(repo)
    end

    in_repo do |g|
      BranchSequence.new('Neon/stable', git: g)
                    .merge_into('Neon/unstable')
                    .push
    end

    in_repo do |g|
      g.checkout('Neon/stable')
      assert_path_exist('stable_c1')
    end
  end
end
