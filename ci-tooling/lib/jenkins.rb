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

require 'addressable/uri'
require 'jenkins_api_client'

# Monkey patch for Client to fold in our config data.
# This is entirely and only necessary because the silly default client
# doesn't allow setting default values on the module or class.
module AutoConfigJenkinsClient
  # Monkey patched initialize. Merges the passed args with the data read
  # from the config file and then calls the proper initialize.
  def initialize(args = {})
    config_file = args.delete(:config_file)
    kwords = config_file ? config(file: config_file) : config
    kwords.merge!(args)
    super(kwords)
  end

  module_function

  def config(file: "#{ENV['HOME']}/.config/pangea-jenkins.json")
    kwords = default_config_data
    if File.exist?(file)
      kwords.merge!(JSON.parse(File.read(file), symbolize_names: true))
    end
    kwords
  end

  def default_config_data
    # If we ported the entire autoconf shebang to URIs we'd not have to have
    # so many key words :(
    {
      ssl: false,
      server_ip: 'kci.pangea.pub',
      server_port: '80',
      log_level: Logger::FATAL
    }
  end
end

module JenkinsApi
  # Standard client with prepended config supremacy. See
  # {AutoConfigJenkinsClient}.
  class Client
    prepend AutoConfigJenkinsClient

    attr_reader :server_ip

    def uri
      Addressable::URI.new(scheme: @ssl ? 'https' : 'http', host: @server_ip,
                           port: @server_port, path: @jenkins_path)
    end

    # Monkey patch to not be broken.
    class View
      # Upstream version applies a filter via list(filter) which means view_name
      # is in fact view_regex as list() internally regexes the name. So if the
      # name includes () things explode if they call exists?.
      # https://github.com/arangamani/jenkins_api_client/issues/232
      def exists?(view_name)
        list.include?(view_name)
      end
    end

    # Extends Job with some useful methods not in upstream (probably could be).
    class Job
      def building?(job_name, build_number = nil)
        build_number ||= get_current_build_number(job_name)
        raise "No builds for #{job_name}" unless build_number
        @client.api_get_request(
          "/job/#{path_encode job_name}/#{build_number}"
        )['building']
      end

      # Send term call (must be after abort and waiting a bit)
      def term(job_name, build_number = nil)
        build_number ||= get_current_build_number(job_name)
        raise "No builds for #{job_name}" unless build_number
        @logger.info "Terminating job '#{job_name}' Build ##{build_number}"
        return unless building?(build_number)
        @client.api_post_request(
          "/job/#{path_encode job_name}/#{build_number}/term"
        )
      end

      # Send a kill call (must be after term and waiting a bit)
      def kill(job_name, build_number = nil)
        build_number ||= get_current_build_number(job_name)
        raise "No builds for #{job_name}" unless build_number
        @logger.info "Killing job '#{job_name}' Build ##{build_number}"
        return unless building?(build_number)
        @client.api_post_request(
          "/job/#{path_encode job_name}/#{build_number}/kill"
        )
      end
    end
  end
end

# Convenience wrapper around JenkinsApi::Client providing a singular instance.
module Jenkins
  module_function

  # @return a singleton instance of {JenkinsApi::Client}
  def client
    @client ||= JenkinsApi::Client.new
  end

  # Convenience method wrapping {#client.job}.
  # @return a singleton instance of {JenkinsApi::Job}
  def job
    @job ||= client.job
  end

  # Convenience method wrapping {#client.plugin}.
  # @return a singleton instance of {JenkinsApi::PluginManager}
  def plugin_manager
    @plugin_manager ||= client.plugin
  end

  def system
    @system ||= client.system
  end
end

# @deprecated Use {Jenkins.client}.
def new_jenkins(args = {})
  warn 'warning: calling new_jenkins is deprecated'
  warn 'warning: arguments passed to new_jenkins are not passed along' if args
  Jenkins.client
end
