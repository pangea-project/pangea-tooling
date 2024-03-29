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

require_relative '../job'

# Generic workflow/pipeline job. Constructs standard workflow rendering a
# pipeline of the same name (with - => _).
class PipelineJob < JenkinsJob
  attr_reader :cron
  attr_reader :sandbox
  attr_reader :with_push_trigger

  # @param name job name
  # @param template the pipeline template basename
  # @param cron the cron trigger rule if any
  # @param job_template the xml job template basename
  # @param sandbox whether to sandbox the pipeline - BE VERY CAREFUL WITH THIS
  #   it punches a huge security hole into jenkins for the specific job
  def initialize(name, template: name.tr('-', '_'), cron: '',
                 job_template: 'pipelinejob', sandbox: true,
                 with_push_trigger: true)
    template_file = File.exist?("#{__dir__}/templates/#{template}-#{job_template}.xml.erb") ? "#{template}-#{job_template}.xml.erb" : "#{job_template}.xml.erb"
    super(name, template_file,
          script: "#{__dir__}/pipelines/#{template}.groovy.erb")
    @cron = cron
    @sandbox = sandbox
    @with_push_trigger = with_push_trigger
  end
end
