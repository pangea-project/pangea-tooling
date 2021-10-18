# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'linter'

module Lint
  # Parses CMake output
  # FIXME: presently we simply result with names, this however lacks context
  #        in the log then, so the output should be changed to a descriptive
  #        line
  class CMake < Linter
    METHS = {
      'The following OPTIONAL packages have not been found' => :parse_summary,
      'The following RUNTIME packages have not been found' => :parse_summary,
      'The following features have been disabled' => :parse_summary,
      'Could not find a package configuration file provided by' => :parse_package,
      'CMake Warning' => :parse_warning
    }.freeze

    def initialize(pwd = Dir.pwd)
      @result_dir = "#{pwd}/result/"

      super()
      # must be after base init, relies on @ignores being defined
      load_include_ignores("#{pwd}/build/debian/meta/cmake-ignore")
    end

    def lint
      result = Result.new
      Dir.glob("#{@result_dir}/pangea_feature_summary-*.log").each do |log|
        data = File.read(log)
        result.valid = true
        parse(data.split("\n"), result)
      end
      result.uniq
    end

    private

    def load_static_ignores
      super
      return unless ENV.fetch('DIST') == 'bionic'
      return unless ENV.fetch('DIST') == NCI.future_series

      # As long as bionic is the future series ignore QCH problems. We cannot
      # solve them without breaking away from xenial or breaking xenial
      # support.
      @ignores << CI::IncludePattern.new('QCH, API documentation in QCH')
      # It ECM it's by a different name for some reason.
      @ignores << CI::IncludePattern.new('BUILD_QTHELP_DOCS')
    end

    def warnings(line, data)
      METHS.each do |id, meth|
        next unless line.include?(id)

        ret = send(meth, line, data)
        @ignores.each do |ignore|
          ret.reject! { |d| ignore.match?(d) }
        end
        return ret
      end
      []
    end

    def parse(data, result)
      until data.empty?
        line = data.shift
        result.warnings += warnings(line, data)
      end
    end

    def parse_summary(_line, data)
      missing = []
      start_line = false
      until data.empty?
        line = data.shift
        if !start_line && line.empty?
          start_line = true
          next
        elsif start_line && !line.empty?
          next if line.strip.empty?

          match = line.match(/^ *\* (.*)$/)
          missing << match[1] if match&.size && match.size > 1
        else
          # Line is empty and the start conditions didn't match.
          # Either the block is not valid or we have reached the end.
          # In any case, break here.
          break
        end
      end
      missing
    end

    def parse_package(line, _data)
      package = 'Could not find a package configuration file provided by'
      match = line.match(/^\s+#{package}\s+"(.+)"/)
      return [] unless match&.size && match.size > 1

      [match[1]]
    end

    # This possibly should be outsourced into files somehow?
    def parse_warning(line, _data)
      warn 'CMake Warning Parsing is disabled at this time!'
      return [] unless line.include?('CMake Warning')
      # Lines coming from MacroOptionalFindPackage (from old parsing).
      return [] if line.include?('CMake Warning at ' \
        '/usr/share/kde4/apps/cmake/modules/MacroOptionalFindPackage.cmake')
      # Lines coming from find_package (from old parsing).
      return [] if line =~ /CMake Warning at [^ :]+:\d+ \(find_package\)/

      # Lines coming from warnings inside the actual CMakeLists.txt as those
      # can be arbitrary.
      # ref: "CMake Warning at src/worker/CMakeLists.txt:33 (message):"
      warning_exp = /CMake Warning at [^ :]*CMakeLists.txt:\d+ \(message\)/
      return [] if line.match(warning_exp)
      return [] if line.start_with?('CMake Warning (dev)')

      [] # if line.start_with?('CMake Warning:')] ALWAYS empty, too pointless
    end
  end
end
