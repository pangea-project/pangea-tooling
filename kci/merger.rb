#!/usr/bin/env ruby

require 'git'
require 'logger'
require 'logger/colors'

require_relative '../ci-tooling/lib/kci'

# Stdlib Logger. Monkey patch with factory methods.
class Logger
  def self.new_for_merger
    l = Logger.new(STDOUT)
    l.progname = 'merger'
    l.level = Logger::INFO
    l.formatter = proc { |severity, _datetime, progname, msg|
      max_line = 80
      white_space_count = 2
      spacers = (max_line - msg.size - white_space_count) / 2
      spacers = ' ' * spacers
      if severity == 'ANY'
        "\n\e[1m#{spacers} #{msg} #{spacers}\e[0m\n"
      else
        "[#{severity[0]}] #{progname}: #{msg}\n"
      end
    }
    l
  end

  def self.new_for_git
    l = Logger.new(STDOUT)
    l.progname = 'git'
    l.level = Logger::WARN
    l
  end
end

# Merger merges delpoyment branches into KCI integration branches and KCI
# integration branches into one another.
class Merger
  # Logger instance used by the Merger.
  attr_reader :log

  # Creates a new Merger. Creates a logger, sets up dpkg-mergechangelogs and
  # opens Dir.pwd as a Git::Base.
  def initialize
    @log = Logger.new_for_merger

    # :nocov:
    if File.exist?('/var/lib/jenkins/tooling3/git')
      Git.configure { |c| c.binary_path = '/var/lib/jenkins/tooling3/git' }
    end
    # :nocov:
    @git = Git.open(Dir.pwd, log: Logger.new_for_git)
    @git.config('merge.dpkg-mergechangelogs.name',
                'debian/changelog merge driver')
    @git.config('merge.dpkg-mergechangelogs.driver',
                'dpkg-mergechangelogs -m %O %A %B %A')
    @push_pending = []
    @clean_branches = []
  end

  # FIXME: The entire merge method pile needs to be meta'd into probably one or
  # two main methods.

  def merge_backports(source)
    target = @git.branches.remote.select { |b| b.name == 'kubuntu_vivid_backports' }[0]
    @log.unknown "#{source} -> #{target}"
    return @log.error 'There is no backports branch!' unless target
    merge(source, target)
  end

  def merge_stable(source)
    target = []
    if target.empty?
      target = @git.branches.remote.select do |b|
        b.name.end_with?('kubuntu_stable')
      end
    end
    if target.empty?
      target = @git.branches.remote.select do |b|
        b.name.end_with?('kubuntu_unstable')
      end
    end
    if target.empty? || target.size > 1
      fail 'There appears to be no kubuntu_stable nor kubuntu_unstable branch!'
    end
    @log.unknown "#{source} -> #{target[0]}"
    merge(source, target[0])

    merge_variants('kubuntu_stable') # stable in variants
  end

  def merge_variants(typebase)
    # FIXME: should make sure typebase exists
    @git.branches.remote.each do |target|
      next unless target.name.start_with?("#{typebase}_")
      @log.info "  #{typebase} -> #{target}"
      merge(typebase, target)
    end
  end

  def merge_unstable(source)
    @log.unknown "#{source} -> kubuntu_unstable"
    target = @git.branches.remote.select { |b| b.name == 'kubuntu_unstable' }[0]
    return @log.error 'There is no unstable branch!' unless target
    merge(source, target)

    merge_variants('kubuntu_unstable') # unstable in variants
  end

  # Merge order:
  #  - master | kubuntu_vivid_archive
  #   -> merge into stable | unstable depending on what is available
  #  - kubuntu_stable
  #   -> merge into unstable
  #   -> merge into series variants
  #  - kubuntu_unstable
  #   -> merge into series variants
  def run(trigger_branch)
    @log.info "triggered by #{trigger_branch}"

    @push_pending = []
    # FIXME: fuck my life. so.... due to very bad design we must cleanup every
    #        branch *when it is supposed to merge*. Now stable is merged into
    #        more than once which would with postponed pushes mean that the
    #        second merge into stable undoes (cleans up) the previous merge.
    #        Since we don't want that we use this bloody workaround to make sure
    #        that stable doesn't get cleaned up twice.....
    #        What we should do is expand the git::branch class with the logic
    #        we presently have in the merge function and then make sure that
    #        each branch (i.e. instace of the object) only gets cleaned once.
    @clean_branches = []
    @git.checkout('master')
    cleanup('master')

    # NOTE: trigger branches must be explicitly added to the jenkins job class
    #       as such. Otherwise the merger job will not start.

    # merge_stable('master')# trigger_branch in stable
    # FIXME: for series names we probably should use the KCI module
    # FIXME: why the fuck do we merge into backports?
    merge_backports('kubuntu_vivid_archive')

    # Sort series by version, then merge in that order (i.e. oldest first).
    # Also merge branches in order archive then backports to equally implement
    # ageyness as it were.
    series = KCI.series.dup
    series = series.sort_by { |_, version| Gem::Version.new(version) }.to_h
    series.each_key do |s|
      merge_stable("kubuntu_#{s}_archive")
      merge_stable("kubuntu_#{s}_backports")
    end

    origin_url = @git.config('remote.origin.url')
    if origin_url.include?('git.debian.org') &&
       origin_url.include?('/frameworks/')
      @log.info 'Running advanced merge protocol (i.e. merging Debian)'
      merge_stable('master')
    end

    # Now merge stable into unstable (or unstable -> unstable = noop)
    merge_unstable('kubuntu_stable')

    push_all_pending
  end

  private

  # Hard resets to head, cleans everything, and sets dpkg-mergechangelogs in
  # .gitattributes afterwards.
  def cleanup(target = @git.current_branch)
    fail 'not current branch' unless @git.current_branch.include?(target)
    @git.reset("remotes/origin/#{target}", hard: true)
    @git.clean(force: true, d: true)
    File.write('.gitattributes',
               "debian/changelog merge=dpkg-mergechangelogs\n")
  end

  # Merges source into target and pushes the merge result.
  # @param source either a Git::Branch or a String specifying the branch from
  #   which should be merged
  # @param target either a Git::Branch or a String specifying the branch in
  #   which  should be merged
  def merge(source, target)
    # We want the full branch name of the remote to work with
    unless source.respond_to?(:full)
      # Try to pick a local version of the remote if available to support
      # postponed pushes.
      # FIXME: as with the clean branches stuff this is a major workaround for
      #        a design flaw in that primary merge targets always want the
      #        remote. For example if we have stable and unstable then we merge
      #        crap into stable and we want remote crap there rather than any
      #        local version of remote.
      #        On the other hand we then merge stable into unstable and there
      #        we very much want the local version rather than the remote one
      #        as otherwise we'd be missing data.
      source_name = source.clone
      source = @git.branches.local.select { |b| b.name == source_name }
      if source.empty?
        source = @git.branches.remote.select { |b| b.name == source_name }
      end
      if source.size != 1
        @log.warn "Apparently there is no branch named #{source_name}!"
        return
      end
      source = source.first
    end
    target = target.name if target.respond_to?(:name)
    @git.checkout(target)
    unless @clean_branches.include?(target)
      cleanup(target)
      @clean_branches << target
    end
    msg = "Merging #{source.full} into #{target}."
    if noci_merge?(source)
      msg = "Merging #{source.full} into #{target}.\n\nNOCI"
    end
    @log.info msg
    @git.merge(source.full, msg)
    @push_pending << target
  end

  def noci_merge?(source)
    log = @git.log.between('', source.full)
    return false unless log.size >= 1
    log.each do |commit|
      return false unless commit.message.include?('NOCI')
    end
    true
  end

  def push_all_pending
    @log.info @git.push('origin', @push_pending.uniq)
    @push_pending = []
  end
end

# :nocov:
if __FILE__ == $PROGRAM_NAME
  Merger.new.run(ENV['GIT_BRANCH'])
  sleep(5)
end
# :nocov:
