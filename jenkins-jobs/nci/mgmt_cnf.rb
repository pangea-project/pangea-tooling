# frozen_string_literal: true

# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'pipelinejob'

# generates command-not-found metadata
class MGTMCNFJob < PipelineJob
  attr_reader :dist
  attr_reader :type
  attr_reader :conten_push_repo_dir

  def initialize(dist:, type:, conten_push_repo_dir: type, name: type)
    super("mgmt_cnf_#{dist}_#{name}", template: 'mgmt_cnf', cron: '@weekly')
    @dist = dist
    @type = type
    if dist == "jammy"
      @conten_push_repo_dir = conten_push_repo_dir == 'stable' ? 'testing' : conten_push_repo_dir
    else
      @conten_push_repo_dir = conten_push_repo_dir
    end
  end
end
