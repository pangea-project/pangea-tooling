#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

ENV['CI_REPORTS'] = "#{Dir.pwd}/reports"
if ENV.include?('CI_PIPELINE_URL') # gitlab
  ENV['LOG_URL'] = "#{ENV.fetch('CI_PIPELINE_URL')}/raw"
else
  BUILD_URL = ENV.fetch('BUILD_URL') { File.read('build_url') }.strip
  ENV['LOG_URL'] = "#{BUILD_URL}/consoleText"
end

# DONT FLIPPING EAT STDOUTERR ... WHAT THE FUCK
#   option for ci-reporter
ENV['CI_CAPTURE'] = 'off'

if ENV['PANGEA_UNDER_TEST']
  warn 'Enabling test coverage merging'
  require 'simplecov'
  SimpleCov.start do
    root ENV.fetch('SIMPLECOV_ROOT') # set by lint_bin test
    command_name "#{__FILE__}_#{Time.now.to_i}_#{rand}"
    merge_timeout 16
  end
end

Dir.glob(File.expand_path('lint_bin/test_*.rb', __dir__)).each do |file|
  require file
end
