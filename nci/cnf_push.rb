#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/repo_content_pusher'

module NCI
  # Pushes command-not-found metadata to aptly remote
  class CNFPusher
    def self.run
      RepoContentPusher.new(content_name: 'cnf', repo_dir: "#{Dir.pwd}/repo", dist: ENV.fetch('DIST')).run
    end
  end
end

NCI::CNFPusher.run if $PROGRAM_NAME == __FILE__
