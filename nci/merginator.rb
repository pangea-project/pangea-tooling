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

require_relative '../ci-tooling/lib/debian/control'
require_relative '../ci-tooling/lib/debian/version'
require_relative '../ci-tooling/lib/nci'

# Merges Qt stuff from debian and bumps versions around [highly experimental]

TARGET_BRANCH = 'Neon/release'

OLDVERSION = '5.13.1'
VERSION = '5.13.2'

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
  qtserialport
  qtconnectivity
  qtcharts
  qtx11extras
  qtsvg
  qtgraphicaleffects
  qtquickcontrols
  qtvirtualkeyboard
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

Dir.mkdir('qtsies') unless File.exist?('qtsies')
Dir.chdir('qtsies')

# TODO: rewrite tagdetective to Rugged and split it to isolate the generic logic

logger = TTY::Logger.new
cmd = TTY::Command.new(uuid: false)

passed = []
skipped = MODS.dup
failed = []

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

MODS.each do |mod|
  cmd.run "git clone neon:qt/#{mod}" unless File.exist?(mod)
  Dir.chdir(mod) do
    begin
      git = Git.open(Dir.pwd, log: logger)
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

      cmd.run('git reset --hard')

      cmd.run "git checkout #{TARGET_BRANCH}"
      version, = cmd.run 'dpkg-parsechangelog -SVersion'
      next if version.start_with?(VERSION) # already bumped

      last_merge = nil
      repo = Rugged::Repository.new(Dir.pwd)
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
      last_merge = Debian::Version.new(last_merge.name.split('/')[-1])
      last_merge.revision = nil
      last_merge.upstream.gsub!('+dfsg', '')
      last_merge = last_merge.full
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
        control = Debian::Control.new(Dir.pwd)
        control.parse!
        fields = %w[Build-Depends Build-Depends-Indep]
        fields.each do |field|
          control.source[field]&.each do |options|
            options.each do |relationship|
              next unless relationship.version&.start_with?(OLDVERSION)

              relationship.version.gsub!(OLDVERSION, last_merge)
            end
          end
        end
        File.write('debian/control', control.dump)
        git.commit('Undo depends version bump', add_all: true)
      end

      cmd.run "git merge #{tag}"
      merge_version = Debian::Version.new(tag.split('/')[-1])
      merge_version.revision = nil
      merge_version = merge_version.full

      # Reapply version delta with new version.
      control = Debian::Control.new(Dir.pwd)
      control.parse!
      fields = %w[Build-Depends Build-Depends-Indep]
      fields.each do |field|
        control.source[field]&.each do |options|
          options.each do |relationship|
            next unless relationship.version&.start_with?(merge_version)

            relationship.version.gsub!(merge_version, VERSION)
          end
        end
      end
      File.write('debian/control', control.dump)

      cmd.run('dch',
              '--distribution', NCI.current_series,
              '--newversion', "#{VERSION}-0neon",
              "New release #{VERSION}")
      git.commit("[TR] New release #{VERSION}", add_all: true)

      passed << mod
    rescue TTY::Command::ExitError => e
      logger.error(e.to_s)
      failed << mod
    end
  end
end

skipped -= passed
skipped -= failed

logger.info "Processed: #{passed.join("\n")}"
logger.info "Skipped: #{skipped.join("\n")}"
logger.info "Failed: #{failed.join("\n")}"
