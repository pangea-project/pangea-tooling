# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'deep_merge'
require 'yaml'

require_relative '../../lib/ci/pattern'

module DCI
  # DCI settings
  class Settings
    DEFAULT_FILES = [
      File.expand_path("#{__dir__}/../../data/settings/dci.yaml")
    ].freeze

    class << self
      def for_job
        new.for_job
      end

      def default_files
        @default_files ||= DEFAULT_FILES
      end

      attr_writer :default_files
    end

    def initialize(files = self.class.default_files)
      @default_paths = files
    end

    def for_job
      unless job?
        puts 'Could not determine job_name. Stamp file missing'
        return {}
      end
      job_patterns = CI::FNMatchPattern.filter(job, settings)
      job_patterns = CI::FNMatchPattern.sort_hash(job_patterns)
      return {} if job_patterns.empty?
      merge(job_patterns)
    end

    private

    def merge(job_patterns)
      folded = {}
      job_patterns.each do |patterns|
        patterns.each do |pattern|
          folded = folded.deep_merge(pattern)
        end
      end
      folded
    end

    def job?
      @job_exist ||= ENV.has_key?('JOB_NAME')
    end

    def job
      job? # Make sure exist has been chached.
      @job ||= ENV.fetch('JOB_NAME').strip
    end

    def settings
      @settings ||= load
    end

    def load
      hash = {}
      @default_paths.each do |path|
        hash.deep_merge!(YAML.load(File.read(path)))
      end
      hash = CI::FNMatchPattern.convert_hash(hash, recurse: false)
      hash
    end
  end
end
