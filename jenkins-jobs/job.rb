# frozen_string_literal: true
#
# Copyright (C) 2014-2017 Harald Sitter <sitter@kde.org>
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

require 'rexml/document'

require_relative '../ci-tooling/lib/retry'
require_relative '../lib/jenkins/job'
require_relative 'template'

# Base class for Jenkins jobs.
class JenkinsJob < Template
  # FIXME: redundant should be name
  attr_reader :job_name

  def initialize(job_name, template_name)
    @job_name = job_name
    super(template_name)
  end

  # Legit class variable. This is for all JenkinsJobs.
  # rubocop:disable Style/ClassVars
  def remote_jobs
    @@remote_jobs ||= Jenkins.job.list_all
  end

  def self.reset
    @@remote_jobs = nil
  end
  # rubocop:enable Style/ClassVars

  # Creates or updates the Jenkins job.
  # @return the job_name
  def update
    # FIXME: this should use retry_it
    return unless job_name.include?(ENV.fetch('UPDATE_INCLUDE', ''))
    xml = render_template
    Retry.retry_it(times: 4, sleep: 1) do
      xml_debug(xml) if @debug
      jenkins_job = Jenkins::Job.new(job_name)
      warn job_name
      if remote_jobs.include?(job_name) # Already exists.
        original_xml = jenkins_job.get_config
        if xml_equal(original_xml, xml)
          warn "     ♻ #{job_name} already uptodate"
          return
        end
        jenkins_job.update(xml)
      else
        jenkins_job.create(xml)
      end
    end
  end

  private

  def xml_debug(data)
    xml_pretty(data, $stdout)
  end

  def xml_equal(data1, data2)
    xml_pretty_string(data1) == xml_pretty_string(data2)
  end

  def xml_pretty_string(data)
    io = StringIO.new
    xml_pretty(data, io)
    io.rewind
    io.read
  end

  def xml_pretty(data, io)
    doc = REXML::Document.new(data)
    REXML::Formatters::Pretty.new.write(doc, io)
  end

  alias to_s job_name
  alias to_str to_s
end
