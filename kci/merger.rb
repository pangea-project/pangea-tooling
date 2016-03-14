#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require_relative '../ci-tooling/lib/kci'
require_relative '../lib/merger'

# Merger merges delpoyment branches into KCI integration branches and KCI
# integration branches into one another.
class KCIMerger < Merger
  # Creates a new KCIMerger. Creates a logger, sets up dpkg-mergechangelogs and
  # opens Dir.pwd as a Git::Base.
  def initialize
    super
    @git = @repo
    @push_pending = []
  end

  def remote_branch(name)
    @git.branches.remote.select { |b| b.name == name }.fetch(0, nil)
  end

  def merge_archive_in_backports(series)
    source = "kubuntu_#{series}_archive"
    target = "kubuntu_#{series}_backports"
    @log.unknown "#{source} -> #{target}"
    target = @git.branches.remote.select { |b| b.name == target }.fetch(0, nil)
    return @log.error 'There is no backports branch!' unless target
    merge(source, target)
  end

  def merge_backports_or_archive_in_stable_or_unstable(series)
    @log.unknown "archive | backports -> stable | unstable (#{series})"
    source = remote_branch("kubuntu_#{series}_backports")
    source = remote_branch("kubuntu_#{series}_archive") unless source
    target = remote_branch("kubuntu_stable_#{series}")
    target = remote_branch("kubuntu_unstable_#{series}") unless target
    if KCI.latest_series == series
      target = remote_branch('kubuntu_stable')
      target = remote_branch('kubuntu_unstable') unless target
      raise 'There is no stable or unstable branch!' unless target
    end
    return @log.error 'There is no backports or archive branch!' unless source
    return @log.error 'There is no stable or unstable branch!' unless target
    merge(source, target)
  end

  def merge_in_variant(type, series)
    @log.unknown "#{type} -> variant (#{series})"
    source = remote_branch("kubuntu_#{type}_#{series}")
    source = remote_branch("kubuntu_#{type}") if KCI.latest_series == series
    return @log.error "There is no #{type} branch!" unless source
    merge_variants(source)
  end

  def merge_stable_in_unstable(series)
    @log.unknown "stable -> unstable (#{series})"
    source = remote_branch("kubuntu_stable_#{series}")
    target = remote_branch("kubuntu_unstable_#{series}")
    if KCI.latest_series == series
      source = remote_branch('kubuntu_stable')
      target = remote_branch('kubuntu_unstable')
    end
    return @log.error 'There is no stable branch!' unless source
    return @log.error 'There is no unstable branch!' unless target
    merge(source, target)
    merge_variants(target)
  end

  def merge_variants(typebase)
    # FIXME: should make sure typebase exists?
    typebase = typebase.name if typebase.respond_to?(:name)
    @git.branches.remote.each do |target|
      next unless target.name.start_with?("#{typebase}_")
      @log.info "  #{typebase} -> #{target}"
      merge(typebase, target)
    end
  end

  def run(trigger_branch)
    @log.info "triggered by #{trigger_branch}"

    @push_pending = []
    @git.checkout('master')
    cleanup_repo!('master')

    # NOTE: trigger branches must be explicitly added to the jenkins job class
    #       as such. Otherwise the merger job will not start.

    # Sort series by version, then merge in that order (i.e. oldest first).
    series = KCI.series.dup
    series = series.sort_by { |_, version| Gem::Version.new(version) }.to_h
    series.each_key do |s|
      # archive -> backports
      merge_archive_in_backports(s)
      # s_backports | s_archive -> s_stable | s_unstable | stable | unstable
      merge_backports_or_archive_in_stable_or_unstable(s)
      # s_stable | stable -> _variant
      merge_in_variant('stable', s)
      # stable -> unstable
      merge_stable_in_unstable(s)
      # s_unstable | unstable -> _variant
      merge_in_variant('unstable', s)
    end

    push_all_pending
  end

  private

  # Merges source into target and pushes the merge result.
  # @param source either a Git::Branch or a String specifying the branch from
  #   which should be merged
  # @param target either a Git::Branch or a String specifying the branch in
  #   which  should be merged
  def merge(source, target)
    # We want the full branch name of the remote to work with
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
    source_name = source.name if source.respond_to?(:name)
    source = @git.branches.local.select { |b| b.name == source_name }
    if source.empty?
      source = @git.branches.remote.select { |b| b.name == source_name }
    end
    if source.size != 1
      @log.warn "Apparently there is no branch named #{source_name}!"
      return
    end
    source = source.first
    target = target.name if target.respond_to?(:name)
    @git.checkout(target)
    msg = "Merging #{source.full} into #{target}."
    if noci_merge?(source)
      msg = "Merging #{source.full} into #{target}.\n\nNOCI"
    end
    @log.info msg
    @git.merge(source.full, msg)
    @push_pending << target
  end

  def push_all_pending
    # Coerce Git::Branch entities into strings
    @push_pending.collect! { |x| x.respond_to?(:name) ? x.name : x }
    @log.info @git.push('origin', @push_pending.uniq)
    @push_pending = []
  end
end

# :nocov:
if __FILE__ == $PROGRAM_NAME
  KCIMerger.new.run(ENV['GIT_BRANCH'])
  sleep(5)
end
# :nocov:
