#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require 'optparse'

require_relative '../ci-tooling/lib/apt'
require_relative '../ci-tooling/nci/lib/setup_repo'

OptionParser.new do |opts|
  opts.banner = <<-BANNER
Usage: #{opts.program_name} [options]
  BANNER

  opts.on('--no-repo', 'Do not set up a repo (does not require TYPE)') do
    @no_repo = true
  end

  opts.on('--src', 'Also setup src repo') do
    @with_source = true
  end
end.parse!

NCI.setup_proxy!
NCI.add_repo_key!
exit if @no_repo

ENV['TYPE'] ||= ARGV.fetch(0) { raise 'Need type as argument or in env.' }
NCI.setup_repo!(with_source: @with_source)
