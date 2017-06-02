# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require_relative '../../ci-tooling/lib/ci/pattern'
require_relative '../../ci-tooling/lib/retry'
require_relative '../../lib/jenkins/job'
require_relative 'build_selector'

module NCI
  module JenkinsBin
    # Wraps around a Job to determine its most suitable core count
    class Job
      attr_reader :name
      attr_reader :job
      attr_reader :log
      attr_reader :overrides
      attr_reader :selector

      def initialize(name)
        @name = name
        @log = Logger.new(STDOUT)

        @overrides = {
          # Needs enough RAM https://bugs.kde.org/show_bug.cgi?id=362946
          CI::FNMatchPattern.new('*_plasma-desktop_bin_amd64') => 8,
          CI::FNMatchPattern.new('*_{qt5webkit,qtwebengine}_bin_amd64') => 8
        }

        @job = Jenkins::Job.new(name)
        @selector = BuildSelector.new(self)
      end

      def last_build_number
        @last_build_number ||= Retry.retry_it(times: 3, sleep: 1) do
          job.build_number
        end
      end

      def override
        @overrride ||= begin
          patterns = CI::FNMatchPattern.filter(name, overrides)
          patterns = CI::FNMatchPattern.sort_hash(patterns)
          return nil if patterns.empty?
          patterns.values[0]
        end
      end

      def best_cores_for_time(average)
        # If the average time to build was <=3 we try to downgrade the slave
        # if it takes <=15 we are comfortable with the slave we have, anything
        # else results in an upgrade attempt.
        # Helper methods cap at min/max respectively.
        # The rationale here is that the relative amount of time it takes to
        # build with a given type of slave is either so low that it's basically
        # only setup or so high that parallelism may help more.
        average_minutes = average / 1000 / 60
        case average_minutes # duration in minutes
        when 0..2
          Cores.downgrade(selector.detected_cores)
        when 2..10
          selector.detected_cores # keep
        else
          Cores.upgrade(selector.detected_cores)
        end
      end

      # FIXME: this method is too long because of a slight misdesign WRT the
      # selector and/or the Job. Tearing it apart would mean passing the
      # selector around.
      def cores
        default_cores = 2

        # Overrides
        return override if override

        builds = selector.select
        return selector.detected_cores || default_cores unless builds

        durations = builds.collect { |x| x.fetch('duration') }
        average = durations.inject { |sum, x| sum + x }.to_f / durations.size

        best_cores_for_time(average)
      end
    end
  end
end
