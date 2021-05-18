#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2019 Harald Sitter <sitter@kde.org>
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

require 'tty/command'
require 'tty/logger'
require 'git'
require 'rugged'

require_relative '../lib/debian/control'
require_relative '../lib/debian/uscan'
require_relative '../lib/debian/version'
require_relative '../lib/nci'

# Merges Qt stuff from debian and bumps versions around [highly experimental]

TARGET_BRANCH = 'Neon/release'

# not actually qt versioned:
# - qtgamepad
# - qbs
# - qtcreator
# - qt5webkit
# - qtchooser
# further broken:
# - qtquickcontrols2 has pkg-kde-tools lowered which conclits a bit and is
#   temporary the commit says, but it doesn't look all that temporary
# - qtwebengine way too much delta in there
MODS = %w[
  qtvirtualkeyboard
  qtserialport
  qtconnectivity
  qtcharts
  qtx11extras
  qtsvg
  qtgraphicaleffects
  qtquickcontrols
  qtspeech
  qtwebview
  qt3d

  qtwebengine
  qtquickcontrols2
  qtscript
  qtnetworkauth
  qtwayland
  qtwebchannel
  qtwebsockets
  qttranslations
  qttools
  qtlocation
  qtsensors
  qtxmlpatterns
  qtdeclarative
  qtbase
]

# Version helper able to differentiate upstream from real_upstream (i.e. without
# +dfsg suffix and the like)
class Version < Debian::Version
  attr_accessor :real_upstream
  attr_accessor :real_upstream_suffix

  def initialize(*)
    super

    self.upstream = super_upstream # force parsing through = method
  end

  # Returns only epoch with real upstream (i.e. without +dfsg suffix or revision)
  def epoch_with_real_upstream
    comps = []
    comps << "#{epoch}:" if epoch
    comps << real_upstream
    comps.join
  end

  # Override to glue together real and suffix
  alias :super_upstream :upstream
  def upstream
    "#{real_upstream}#{real_upstream_suffix}"
  end

  # Split upstream into real and suffix
  def upstream=(input)
    regex = /(?<real>[\d\.]+)(?<suffix>.*)/
    match = input.match(regex)
    @real_upstream = match[:real]
    raise if @real_upstream.empty?

    @real_upstream_suffix = match[:suffix]
  end
end

class Merginator
  attr_reader :logger
  attr_reader :cmd
  attr_reader :passed
  attr_reader :skipped
  attr_reader :failed

  # Git instance (wrapper around git cli)
  attr_reader :git
  # Rugged repo (libgit2)
  attr_reader :repo

  def initialize
    @logger = TTY::Logger.new
    @cmd = TTY::Command.new(uuid: false)

    @passed = []
    @skipped = MODS.dup
    @failed = []
  end

  # rerere's existing merges to possibly learn how to solve problems.
  # not sure if this does much for us TBH
  def train_rerere(repo)
    return unless Dir.glob('.git/rr-cache/*').empty?

    cmd = TTY::Command.new
    old_head = repo.head

    repo.walk(repo.head.target) do |commit|
      next unless commit.parents.size >= 2

      warn 'merge found'

      cmd.run "git checkout #{commit.parents[0].oid}"
      cmd.run 'git reset --hard'
      cmd.run 'git clean -fd'

      result = cmd.run! "git merge #{commit.parents[1..-1].collect(&:oid).join(' ')}"
      if result.failure?
        cmd.run "git show -s --pretty=format:'Learning from %h %s' #{commit.oid}"
        cmd.run 'git rerere'
        cmd.run "git checkout #{commit.oid} -- ."
        cmd.run 'git rerere'
      end

      cmd.run 'git reset --hard'
    end

    cmd.run "git checkout #{old_head.target.oid}"
    cmd.run 'git reset --hard'
    cmd.run 'git clean -fd'
  end

  def setup_repo
    @git = Git.open(Dir.pwd, log: logger)
    git.config('merge.dpkg-mergechangelogs.name',
               'debian/changelog merge driver')
    git.config('merge.dpkg-mergechangelogs.driver',
               'dpkg-mergechangelogs -m %O %A %B %A')
    repo_path = git.repo.path
    FileUtils.mkpath("#{repo_path}/info")
    File.write("#{repo_path}/info/attributes",
               "debian/changelog merge=dpkg-mergechangelogs\n")
    git.config('user.name', 'Neon CI')
    git.config('user.email', 'neon@kde.org')
    git.config('rerere.enabled', 'true')

    @repo = Rugged::Repository.new(Dir.pwd)
  end

  def mangle_depends(from:, to:)
    control = Debian::Control.new(Dir.pwd)
    control.parse!
    fields = %w[Build-Depends Build-Depends-Indep]
    fields.each do |field|
      control.source[field]&.each do |options|
        options.each do |relationship|
          next unless relationship.version&.start_with?(from)

          relationship.version.gsub!(from, to)
        end
      end
    end
    File.write('debian/control', control.dump)
  end

  # uscan dehs result
  def dehs
    # Only do this once for the first source for efficency
    @dehs ||= begin
      result = cmd.run!('uscan --report --dehs')
      data = result.out
      puts "uscan exited (#{result}) :: #{data}"
      newer = Debian::UScan::DEHS.parse_packages(data).collect do |package|
        next nil unless package.status == Debian::UScan::States::NEWER_AVAILABLE

        package
      end.compact

      raise "There is no Qt release pending says uscan???" if newer.empty?
      # uscan technically kinda supports multiple sources, we do not.
      raise "More than one uscan result?! #{newer.inspect}" if newer.size > 1

      newer[0]
    end
  end

  def run
    Dir.mkdir('qtsies') unless File.exist?('qtsies')
    Dir.chdir('qtsies')

    # TODO: rewrite tagdetective to Rugged and split it to isolate the generic logic

    MODS.each do |mod|
      cmd.run "git clone git@invent.kde.org:neon/qt/#{mod}" unless File.exist?(mod)
      Dir.chdir(mod) do
        begin
          setup_repo

          cmd.run('git reset --hard')

          cmd.run "git checkout #{TARGET_BRANCH}"
          old_version, = cmd.run 'dpkg-parsechangelog -SVersion'
          old_version = Version.new(old_version)
          # check if already bumped
          next if old_version.real_upstream.start_with?(dehs.upstream_version)

          last_merge = nil
          repo.walk(repo.head.target) do |commit|
            next unless commit.parents.size >= 2 # not a merge

            commit.parents.find do |parent|
              last_merge = repo.tags.find { |tag| tag.target == parent && tag.name.start_with?('debian/')}
            end

            break if last_merge # found the last merge
          end
          raise unless last_merge

          tooling_release_commmit = nil
          repo.walk(repo.head.target) do |commit|
            # A bit unclear if and in which order we'd walk a merge, so be careful
            # and prevent us from walking past the merge.
            break if commit == last_merge.target # at merge
            break if commit.time < last_merge.target.time # went beyond last merge
            next unless commit.message.include?('[TR]')

            tooling_release_commmit = commit
            break
          end

          # Convert tag name to version without rev.
          last_merge_tag = last_merge
          last_merge = Version.new(last_merge.name.split('/')[-1])
          logger.warn("last merge was #{last_merge} #{last_merge_tag.name}")

          cmd.run 'git checkout master'
          cmd.run 'git pull --rebase'
          tag, = cmd.run 'git describe'
          tag = tag.strip

          cmd.run "git checkout #{TARGET_BRANCH}"
          cmd.run "git reset --hard origin/#{TARGET_BRANCH}"
          train_rerere(repo)
          cmd.run "git checkout #{TARGET_BRANCH}"
          cmd.run "git reset --hard origin/#{TARGET_BRANCH}"

          # Undo version delta because Bhushan insists on not having ephemeral
          # version constriction applied via tooling at build time!
          # Editing happens in-place. This preserves order in the output (more or
          # less anyway).
          if tooling_release_commmit
            # Ideally we'd have found a previous tooling commit to undo
            if tooling_release_commmit.parents >= 2
              raise 'tooling release commit is a merge. this should not happen!'
            end

            git.revert(tooling_release_commmit.oid)
          else
            # TODO: should we stick with this it'd probably be smarter to expect only
            #   tooling to apply a bump and tag the relevant commit with some marker,
            #   so we can then find it again and simply revert the bump.
            #   Much less risk of causing conflict because Control technically doesn't
            #   know how to preserve content line-for-line, it just happens to so long
            #   as the input was wrapped-and-sorted.
            mangle_depends(from: old_version.epoch_with_real_upstream,
                           to: last_merge.epoch_with_real_upstream)
            git.commit('Undo depends version bump', add_all: true)
          end

          cmd.run "git merge #{tag}"
          merge_version = Version.new(tag.split('/')[-1])

          # Construct new version from pre-existing one. This retains epoch
          # and possibly upstream suffix
          new_version = Version.new(dehs.upstream_version)
          new_version.epoch = old_version.epoch
          new_version.real_upstream_suffix = old_version.real_upstream_suffix
          new_version.revision = "0neon"

          # Reapply version delta with new version.
          mangle_depends(from: merge_version.epoch_with_real_upstream,
                         to: new_version.epoch_with_real_upstream)

          cmd.run('dch',
                  '--distribution', NCI.current_series,
                  '--newversion', "#{new_version}",
                  "New release #{new_version.real_upstream}")
          git.commit("[TR] New release #{new_version.real_upstream}", add_all: true)

          passed << mod
        rescue TTY::Command::ExitError => e
          logger.error(e.to_s)
          failed << mod
        end
      end
    end

    # skipped is a read only attribute, we need to assign the var directly!
    @skipped -= passed
    @skipped -= failed

    logger.info "Processed: #{passed.join("\n")}"
    logger.info "Skipped: #{skipped.join("\n")}"
    logger.info "Failed: #{failed.join("\n")}"
  end
end

if $PROGRAM_NAME == __FILE__
  Merginator.new.run
end
