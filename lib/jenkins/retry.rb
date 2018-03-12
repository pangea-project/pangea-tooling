# frozen_string_literal: true
#
# Copyright (C) 2015-2017 Harald Sitter <sitter@kde.org>
# Copyright (C) 2018 Jonathan Riddell <jr@jriddell.org>
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

require_relative '../../ci-tooling/lib/jenkins'

module Jenkins

  def retry_jobs(job_name_queue, exclusion_states=%w[success unstable], strict_mode=false)
    BlockingThreadPool.run do
      until job_name_queue.empty?
        name = job_name_queue.pop(true)
        Retry.retry_it(times: 5) do
          status = Jenkins.job.status(name)
          queued = Jenkins.client.queue.list.include?(name)
          @log.info "#{name} | status - #{status} | queued - #{queued}"
          next if Jenkins.client.queue.list.include?(name)

          if strict_mode
            skip = true
            downstreams = Jenkins.job.get_downstream_projects(name)
            downstreams << Jenkins.job.list_details(name.gsub(/_src/, '_pub'))
            downstreams.each do |downstream|
              downstream_status = Jenkins.job.status(downstream['name'])
              next if %w[success unstable running].include?(downstream_status)
              skip = false
            end
            @log.info "Skipping #{name}" if skip
            next if skip
          end

          unless exclusion_states.include?(Jenkins.job.status(name))
            @log.warn "  #{name} --> build"
            Jenkins.job.build(name)
          end
        end
      end
    end
  end

end
