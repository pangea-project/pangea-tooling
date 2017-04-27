# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
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

require_relative '../../ci-tooling/lib/thread_pool'

module Jenkins
  # Updates Jenkins Projects
  class ProjectUpdater
    def initialize
      update_submodules
      @job_queue = Queue.new
      @job_names = []
    end

    def update_submodules
      return if @submodules_updated
      unless system(*%w[git submodule update --remote --recursive])
        raise 'failed to update git submodules of tooling!'
      end
      @submodules_updated = true
    end

    def update
      update_submodules
      populate_queue
      # run_queue
      # check_jobs_exist
    end

    def install_plugins
      # Autoinstall all possibly used plugins.
      installed_plugins = Jenkins.plugin_manager.list_installed.keys
      plugins = (plugins_to_install + standard_plugins).uniq
      plugins.each do |plugin|
        next if installed_plugins.include?(plugin)
        puts "--- Installing #{plugin} ---"
        Jenkins.plugin_manager.install(plugin)
      end
    end

    private

    # Override to supply a blacklist of jobs to not be considered in the
    # templatification warnings.
    def jobs_without_template
      []
    end

    def check_jobs_exist
      # To blacklist jobs from being complained about, override
      # #jobs_without_template in the sepcific updater class.

      remote = JenkinsApi::Client.new.job.list_all - jobs_without_template
      local = @job_names

      job_warn('--- Some jobs are not being templated! ---', (remote - local))
      job_warn('--- Some jobs were not created @remote! ---', (local - remote))
    end

    def job_warn(warning_str, names)
      return if names.empty?
      warn warning_str
      names.each do |name|
        uri = JenkinsApi::Client.new.uri
        uri.path += "/job/#{name}"
        warn name
        warn "    #{uri.normalize}"
      end
      warn warning_str
      warn '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    end

    def all_template_files
      Dir.glob('jenkins-jobs/templates/**/**.xml.erb')
    end

    # Standard plugins not showing up in templates but generally useful to have
    # for our CIs. These should as a general rule not change behavior or
    # add functionality or have excessive depedencies as to not slow down
    # jenkins for no good reason.
    def standard_plugins
      %w[
        greenballs
        status-view
        simple-theme-plugin
      ]
    end

    # FIXME: this installs all plugins used by all CIs, not the ones at hand
    def plugins_to_install
      plugins = []
      installed_plugins = Jenkins.plugin_manager.list_installed.keys
      all_template_files.each do |path|
        File.readlines(path).each do |line|
          match = line.match(/.*plugin="(.+)".*/)
          next unless match && match.size == 2
          plugin = match[1].split('@').first
          next if installed_plugins.include?(plugin)
          plugins << plugin
        end
      end
      plugins.uniq.compact
    end

    def enqueue(obj)
      @job_queue << obj
      @job_names << obj.job_name
      obj
    end

    def run_queue
      BlockingThreadPool.run do
        until @job_queue.empty?
          job = @job_queue.pop(true)
          job.update
        end
      end
    end
  end
end
