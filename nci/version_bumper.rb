#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-FileCopyrightText: 2023 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/debian/control'
require_relative '../lib/kdeproject_component'
require_relative '../lib/projects/factory/neon'

require 'awesome_print'
require 'deep_merge'
require 'tty/command'
require 'yaml'

# Iterates all plasma repos and adjusts the packaging for the new plasma version #.
class Mutagen
  attr_reader :cmd

  def initialize
    @cmd = TTY::Command.new
  end



  def run
    if File.exist?('plasma')
      Dir.chdir('plasma')
    else
      Dir.mkdir('plasma')
      Dir.chdir('plasma')

      repos = ProjectsFactory::Neon.ls
      KDEProjectsComponent.plasma_jobs.uniq.each do |project|
        repo = repos.find { |x| x.end_with?("/#{project}") }
        p [project, repo]
        cmd.run('git', 'clone', "git@invent.kde.org:neon/#{repo}")
      end
    end

    Dir.glob('*') do |dir|
      next unless File.directory?(dir)

      p dir
      Dir.chdir(dir) do
        cmd.run('git', 'fetch', 'origin')
        cmd.run('git', 'reset', '--hard')
        cmd.run('git', 'checkout', 'Neon/unstable')
        cmd.run('git', 'reset', '--hard', 'origin/Neon/unstable')

        cmd.run('dch', '--force-bad-version', '--force-distribution', '--distribution', 'jammy', '--newversion', '4:5.91.90-0neon', 'new release')

        cmd.run('git', 'commit', '--all', '--message', 'bump plasma version to 5.91.90') unless cmd.run!('git', 'diff', '--quiet').success?
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  Mutagen.new.run
end
