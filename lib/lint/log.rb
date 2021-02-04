# frozen_string_literal: true
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'log/cmake'
require_relative 'log/dh_missing'
require_relative 'log/list_missing'

module Lint
  # Lints a build log
  class Log
    attr_reader :log_data

    def initialize(log_data)
      @log_data = log_data
    end

    # @return [Array<Result>]
    def lint
      results = []
      [CMake, ListMissing, DHMissing].each do |klass|
        results << klass.new.lint(@log_data.clone)
      end
      results
    end
  end
end
