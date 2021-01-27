#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>

require_relative 'lint/versions'

# Runs against Ubuntu, we do not add any extra repos. The intention is that
# all packages in our repo are greater than the one in Ubuntu (i.e. apt-cache).

Aptly.configure do |config|
  config.uri = URI::HTTPS.build(host: 'archive-api.neon.kde.org')
  # This is read-only.
end

our = NCI::RepoPackageLister.new
their = NCI::CachePackageLister.new(filter_select: our.packages.map(&:name))
NCI::VersionsTest.init(ours: our.packages, theirs: their.packages)
ENV['CI_REPORTS'] = Dir.pwd
ARGV << '--ci-reporter'
require 'minitest/autorun'
