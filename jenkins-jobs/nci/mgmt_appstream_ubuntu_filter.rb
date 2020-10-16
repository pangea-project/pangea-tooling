# frozen_string_literal: true

# SPDX-FileCopyrightText: 2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'pipelinejob'

# Gathers up all ubuntu appstream apps and filters them out of the component
# list we publish.
class MGMTAppstreamUbuntuFilter < PipelineJob
  attr_reader :dist

  def initialize(dist:)
    super("mgmt_appstream-ubuntu-filter_#{dist}",
          template: 'mgmt_appstream_ubuntu_filter', cron: 'H H * * *')
    @dist = dist
  end
end
