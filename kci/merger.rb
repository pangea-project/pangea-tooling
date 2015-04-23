#!/usr/bin/env ruby

require 'git'
require 'logger'
require 'logger/colors'

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

    Git.global_config('merge.dpkg-mergechangelogs.name',
                      'debian/changelog merge driver')
    Git.global_config('merge.dpkg-mergechangelogs.driver',
                      'dpkg-mergechangelogs -m %O %A %B %A')
    # :nocov:
    if File.exist?('/var/lib/jenkins/tooling/git')
      Git.configure { |c| c.binary_path = '/var/lib/jenkins/tooling/git' }
    end
    # :nocov:
    @git = Git.open(Dir.pwd, log: Logger.new_for_git)
  end

  # FIXME: The entire merge method pile needs to be meta'd into probably one or
  # two main methods.

  def merge_backports(source)
    @log.unknown "#{source} -> kubuntu_vivid_backports"
    target = @git.branches.remote.select { |b| b.name == 'kubuntu_vivid_backports' }[0]
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

    cleanup('master')

    # merge_stable('master')# trigger_branch in stable
    merge_backports('kubuntu_vivid_archive')
    merge_stable('kubuntu_vivid_backports')
    merge_stable('kubuntu_vivid_archive')
    merge_unstable('kubuntu_stable')
  end

  private

  # Hard resets to head, cleans everything, and sets dpkg-mergechangelogs in
  # .gitattributes afterwards.
  def cleanup(target = @git.current_branch)
    @git.fetch('origin')
    @git.reset("remotes/origin/#{target}", hard: true)
    @git.clean(force: true, d: true)
    @git.pull('origin', target)
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
      source_name = source.clone
      source = @git.branches.remote.select { |b| b.name == source_name }[0]
      unless source
        @log.warn "Apparently there is no branch named #{source_name}!"
        return
      end
    end
    target = target.name if target.respond_to?(:name)
    @git.checkout(target)
    cleanup(target)
    msg = "Merging #{source.full} into #{target}."
    if noci_merge?(source)
      msg = "Merging #{source.full} into #{target}.\n\nNOCI"
    end
    @log.info msg
    @git.merge(source.full, msg)
    @log.info @git.push('origin', target)
  end

  def noci_merge?(source)
    log = @git.log.between('', source.full)
    return false unless log.size >= 1
    log.each do |commit|
      return false unless commit.message.include?('NOCI')
    end
    true
  end
end

# :nocov:
if __FILE__ == $PROGRAM_NAME
  Merger.new.run(ENV['GIT_BRANCH'])
  sleep(5)
end
# :nocov:
