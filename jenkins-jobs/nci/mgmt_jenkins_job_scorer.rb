# frozen_string_literal: true

# SPDX-FileCopyrightText: 2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'pipelinejob'

# Updates core assignment for jobs. Jobs that take too long get more cores,
# jobs that are too fast may get fewer. This is pruely to balance cloud cost
# versus build time.
class MGMTJenkinsJobScorer < PipelineJob
  def initialize
    super('mgmt_jenkins-job-scorer',
          template: 'mgmt_jenkins_job_scorer', cron: '@weekly')
  end
end
