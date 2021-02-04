#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-FileCopyrightText: 2018-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

# Deploys seeds onto HTTP server so they can be used by livecd-rootfs/germinate
# over HTTP.

# Of interest
# https://stackoverflow.com/questions/16351271/apache-redirects-based-on-symlinks

require 'date'

require_relative '../lib/nci'
require_relative '../lib/tty_command'

ROOT = '/srv/www/metadata.neon.kde.org/germinate'
NEON_GIT = 'https://invent.kde.org/neon'
NEON_REPO = "#{NEON_GIT}/neon/seeds"
UBUNTU_SEEDS = 'https://git.launchpad.net/~ubuntu-core-dev/ubuntu-seeds/+git'
PLATFORM_REPO = "#{UBUNTU_SEEDS}/platform"

cmd = TTY::Command.new
stamp = Time.now.utc.strftime('%Y%m%d-%H%M%S')

dir = "#{ROOT}/seeds.new.#{stamp}"
cmd.run('rm', '-rf', dir)
cmd.run('mkdir', '-p', dir)
failed = true

at_exit do
  # In the event that we raise on something, make sure to clean up dangling bits
  cmd.run('rm', '-rf', dir) if failed
end

serieses = NCI.series.keys

series_branches = begin
  out, _ = cmd.run('git', 'ls-remote', '--heads', '--exit-code',
                   NEON_REPO, 'Neon/unstable*')
  found_main_branch = false
  branches = {}
  out.strip.split($/).collect do |line|
    ref = line.split(/\s/).last
    branch = ref.gsub('refs/heads/', '')
    if branch == 'Neon/unstable'
      found_main_branch = true
    elsif (series = serieses.find { |s| branch == "Neon/unstable_#{s}" })
      raise unless series # just to make double sure we found smth

      branches[series] = branch
    elsif branch.start_with?('Neon/unstable_')
      warn "Seems we found a legacy branch #{branch}, skipping."
    else
      raise "Unexpected branch #{branch} wanted a Neon/unstable branch :O"
    end
  end
  unless found_main_branch
    raise 'Did not find Neon/unstable branch! Something went well wrong!'
  end

  branches
end
p series_branches

Dir.chdir(dir) do
  serieses.each do |series|
    neondir = "neon.#{series}"
    platformdir = "platform.#{series}"
    branch = series_branches.fetch(series, 'Neon/unstable')
    cmd.run('git', 'clone', '--depth', '1', '--branch', branch,
            NEON_REPO, neondir)
    cmd.run('git', 'clone', '--depth', '1', '--branch', series,
            PLATFORM_REPO, platformdir)
  end
end

Dir.chdir(ROOT) do
  cur_dir = File.basename(dir) # dir is currently abs, make it relative
  main_dir = 'seeds'
  old_dir = File.readlink(main_dir) rescue nil
  new_dir = 'seeds.new'
  cmd.run('rm', '-f', new_dir)
  cmd.run('ln', '-s', cur_dir, new_dir)
  cmd.run('mv', '-T', new_dir, main_dir)
  cmd.run('rm', '-rf', old_dir)
end

failed = false
