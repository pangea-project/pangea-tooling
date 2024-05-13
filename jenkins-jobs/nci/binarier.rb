# frozen_string_literal: true

# SPDX-FileCopyrightText: 2015-2021 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2018 Bhushan Shah <bshah@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../job'
require_relative '../binarier'

# binary builder
class BinarierJob
  attr_accessor :qt_git_build
  attr_accessor :qt6_build

  # Monkey patch cores in
  def cores
    config_file = "#{Dir.home}/.config/nci-jobs-to-cores.json"
    return '8' unless File.exist?(config_file)

    JSON.parse(File.read(config_file)).fetch(job_name, '8')
  end

  def compress?
    %w[qt6webengine pyside6 qt5webkit qtwebengine
       mgmt_job-updater appstream-generator mgmt_jenkins_expunge].any? do |x|
      job_name.include?(x)
    end
  end

  def architecture
    # i386 is actually cross-built via amd64
    return 'amd64' if @architecture == 'i386'

    @architecture
  end

  def cross_architecture
    @architecture
  end

  def cross_compile?
    @architecture == 'i386'
  end
end
