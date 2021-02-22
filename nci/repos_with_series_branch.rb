#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-FileCopyrightText: 2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/projects/factory/neon'

require 'optparse'
require 'tty/command'

parser = OptionParser.new do |opts|
  opts.banner = <<~SUMMARY
    Usage: #{opts.program_name} [options] series
  SUMMARY
end
abort parser.help if ARGV.size != 1
series = ARGV[0]

with_branch = {}
cmd = TTY::Command.new
ProjectsFactory::Neon.ls.each do |repo|
  next if repo.include?('gitolite-admin') # enoaccess

  url = File.join(ProjectsFactory::Neon.url_base, repo)
  out, _err = cmd.run('git', 'ls-remote', url, "refs/heads/Neon/*_#{series}")
  with_branch[repo] = out unless out.empty?
end

puts "Repos with branchies:"
with_branch.each do |repo, out|
  puts repo
  puts out
end
