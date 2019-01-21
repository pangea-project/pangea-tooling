#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2019 Scarlett Moore <sgclark@kde.org>
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

require 'octokit'
require 'deep_merge'
require 'yaml'
require_relative '../../lib/ci/pattern.rb'

SKIP = %w(linuxmint calamares plasmazilla)
SERIES = '1901'
Octokit.auto_paginate = true
@client = Octokit::Client.new


#Loop through DCI github repos and create release branches.
class ReleaseBranch
  def initialize
    file = "#{__dir__}/../../../../pangea-conf-projects/dci/#{SERIES}/release.yaml"
    repo = load(file)
    puts repo
  end

  def load(file)
    hash = {}
    hash.deep_merge!(YAML.load(File.read(File.expand_path(file))))
    puts hash
    hash = CI::FNMatchPattern.convert_hash(hash, recurse: false)
    puts hash
    hash
  end
end
