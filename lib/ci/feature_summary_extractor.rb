# frozen_string_literal: true

# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'tmpdir'

module CI
  # Injects a feature summary call into cmakelists that enables us to easily get access to the output
  # without having to parse the entire log (and then possibly fall over missing marker lines :|).
  # Has a bit of a beauty problem that sources in the package
  class FeatureSummaryExtractor
    def self.run(result_dir:, build_dir:, &block)
      new(result_dir: result_dir, build_dir: build_dir).run(&block)
    end

    def initialize(result_dir:, build_dir:)
      @result_dir = File.absolute_path(result_dir)
      @build_dir = File.absolute_path(build_dir)
    end

    def run(&block)
      unless File.exist?("#{@build_dir}/CMakeLists.txt")
        yield
        return
      end

      warn 'Extended CMakeLists with feature_summary extraction.'
      mangle(&block)
    end

    private

    def data
      <<~SNIPPET
include(FeatureSummary)
string(TIMESTAMP _pangea_feature_summary_timestamp "%Y-%m-%dT%H:%M:%SZ" UTC)
feature_summary(FILENAME "#{@result_dir}/pangea_feature_summary-${_pangea_feature_summary_timestamp}.log" WHAT ALL)
      SNIPPET
    end

    def mangle
      Dir.mktmpdir do |tmpdir|
        backup = File.join(tmpdir, 'CMakeLists.txt')
        FileUtils.cp("#{@build_dir}/CMakeLists.txt", backup, verbose: true)
        File.open("#{@build_dir}/CMakeLists.txt", 'a') { |f| f.write(data) }
        yield
      ensure
        FileUtils.cp(backup, @build_dir, verbose: true)
      end
    end
  end
end
