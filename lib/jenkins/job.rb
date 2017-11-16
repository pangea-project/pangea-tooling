# frozen_string_literal: true
#
# Copyright (C) 2015-2017 Harald Sitter <sitter@kde.org>
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
  # A Jenkins Job.
  # Gives jobs a class so one can use it like a bloody OOP construct rather than
  # I don't even know what the default api client thing does...
  class Job
    attr_reader :name
    alias to_s name
    alias to_str to_s

    def initialize(name, client = JenkinsApi::Client.new)
      @client = client
      @name = name
      return unless @name.is_a?(Hash)
      @name = @name.fetch('name') { raise 'name is a Hash but has no name key' }
    end

    def delete!
      @client.job.delete(@name)
    end

    def wipe!
      @client.job.wipe_out_workspace(@name)
    end

    def enable!
      @client.job.enable(@name)
    end

    def disable!
      @client.job.disable(@name)
    end

    def remove_downstream_projects
      @client.job.remove_downstream_projects(@name)
    end

    def method_missing(name, *args)
      args = [@name] + args

      # A set method.
      if name.to_s.end_with?('=')
        return @client.job.send("set_#{name}".to_sym, *args)
      end

      # Likely a get_method, could still be an actual api method though.
      method_missing_internal(name, *args)
    end

    def respond_to?(name, include_private = false)
      if name.to_s.end_with?('=')
        return @client.job.respond_to?("set_#{name}".to_sym, include_private)
      end
      @client.job.respond_to?(name, include_private) ||
        @client.job.respond_to?("get_#{name}".to_sym, include_private) ||
        super
    end


    def exists?
      # jenkins api client is so daft it lists all jobs and then filters
      # that list. To check existance it's literally enough to hit the job
      # endpoint and see if it comes back 404.
      # With the 11k jobs we have in neon list_all vs. list_details is a
      # 1s difference!
      list_details
      true
    rescue JenkinsApi::Exceptions::NotFound
      false
    end

    private

    # Rescue helper instead of a beginrescue block.
    def method_missing_internal(name, *args)
      @client.job.send(name, *args)
    rescue NoMethodError => e
      # Try a get prefix.
      begin
        @client.job.send("get_#{name}".to_sym, *args)
      rescue NoMethodError
        raise e # Still no luck, raise original error.
      end
    end
  end
end
