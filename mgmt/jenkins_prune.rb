#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/jenkins/jobdir.rb'

options = {}

parser = OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: #{opts.program_name} --max-age INTEGER --min-count INTEGER

Prunes all Jenkins job dirs it can find by removing both logs and archives
EOF
  opts.separator('')

  opts.on('--max-age INTEGER',
          'The maximum age (in days) of builds to keep.',
          'This presents the upper limit.',
          'Any build exceeding this age will be pruned') do |v|
    options[:max_age] = v.to_i
  end

  opts.on('--min-count INTEGER',
          'The minium amount of builds to keep.',
          'This presents the lower limit of builds to keep.',
          'Builds below this limit are also kept if they are too old') do |v|
    options[:min_count] = v.to_i
  end

  opts.on('--paths archive,log,etc', Array,
          'List of paths to drop') do |v|
    options[:paths] = v
  end
end
parser.parse!

Dir.glob("#{Dir.home}/jobs/*").each do |jobdir|
  Jenkins::JobDir.prune(jobdir, options)
end
