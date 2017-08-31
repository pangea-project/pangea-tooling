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

require_relative '../../lib/jenkins/job'
require_relative 'cores'
require_relative 'slave'

module NCI
  module JenkinsBin
    # Select a set of builds for core count evaluation
    class BuildSelector
      class CoreMismatchError < StandardError; end

      QUALIFIER_STATES = %w[success unstable].freeze

      attr_reader :log
      attr_reader :job
      attr_reader :number
      attr_reader :detected_cores
      attr_reader :exception_count
      attr_reader :set_size

      def initialize(job)
        @log = job.log
        @number = job.last_build_number
        @job = job.job # jenkins job
        @detected_cores = nil
        @exception_count = 0
        @set_size = 2
      end

      # This method is a complicated cluster fuck. I would not even know where
      # to begin in tearing it apart. I fear this is just what it is.
      # too long, abc too high, asignment too high etc. etc.
      # rubocop:disable all
      def build_of(build_number)
        # Get the build
        build = Retry.retry_it(times: 3, sleep: 1) do
          job.build_details(build_number)
        end
        raise "Could not resolve ##{build_number} of #{job.name}" unless build

        # Make sure it wasn't a failure. Failures give no sensible performance
        # data.
        result = build.fetch('result')
        return nil unless result
        return nil unless QUALIFIER_STATES.include?(result.downcase)

        # If we have a build, check its slave and possibly record it as detected
        # core count. We'll look for previous builds with the same count on
        # subsequent iteration.
        built_on = build.fetch('builtOn')
        built_on_cores = Slave.cores(built_on)
        if detected_cores && detected_cores != built_on_cores
          @log.info <<-EOF
[#{job.name}]
Could not find a set of #{set_size} subsequent successful builds
build:#{number} has unexpected slave #{built_on} type:#{built_on_cores} (expected type:#{detected_cores})
          EOF
          raise CoreMismatchError,
                "expected #{detected_cores}, got #{built_on_cores}"
        end

        @detected_cores = built_on_cores

        # If we do not know the core count because we shrunk the options
        # coerce to the closest match.
        unless Cores.know?(detected_cores)
          @detected_cores = Cores.coerce(detected_cores)
        end

        @exception_count -= 1
        build
      rescue JenkinsApi::Exceptions::NotFound => e
        if (@exception_count += 1) >= 5
          raise "repeated failure trying to resolve #{job.name}'s builds #{e}"
        end
      end
      # rubocop:enable all

      def select
        builds = []
        until number <= 0 || builds.size >= set_size
          build = build_of(number)
          @number -= 1
          builds << build if build
        end
        return nil unless builds.size >= set_size
        builds
      rescue CoreMismatchError
        nil # Logged at raise time already
      end
    end
  end
end
