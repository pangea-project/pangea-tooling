# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

# Updates Jenkins Projects
module Jenkins
  class ProjectUpdater
    def initialize
      @job_queue = Queue.new
    end

    def update
      populate_queue
      run_queue
    end

    def install_plugins
      # Autoinstall all possibly used plugins.
      installed_plugins = Jenkins.plugin_manager.list_installed.keys
      plugins_to_install.each do |plugin|
        next if installed_plugins.include?(plugin)
        puts "--- Installing #{plugin} ---"
        Jenkins.plugin_manager.install(plugin)
      end
    end

    private

    def all_template_files
      Dir.glob('jenkins-jobs/templates/**/**.xml.erb')
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
