require 'jenkins_api_client'

# Monkey patch for Client to fold in our config data.
# This is entirely and only necessary because the silly default client
# doesn't allow setting default values on the module or class.
module AutoConfigJenkinsClient
  # Monkey patched initialize. Merges the passed args with the data read
  # from the config file and then calls the proper initialize.
  def initialize(args = {})
    config_file = args.delete(:config_file) || "#{ENV['HOME']}/.config/pangea-jenkins.json"
    config_data = {}
    if File.exist?(config_file)
      config_data = JSON.parse(File.read(config_file), symbolize_names: true)
    end
    config_data[:server_ip] ||= 'kci.pangea.pub'
    config_data[:server_port] ||= '80'
    config_data[:log_level] ||= Logger::FATAL
    config_data.merge!(args)
    super(config_data)
  end
end

module JenkinsApi
  # Standard client with prepended config supremacy. See
  # {AutoConfigJenkinsClient}.
  class Client
    prepend AutoConfigJenkinsClient
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
end

# @deprecated Use {Jenkins.client}.
def new_jenkins(args = {})
  warn 'warning: calling new_jenkins is deprecated'
  warn 'warning: arguments passed to new_jenkins are not passed along' if args
  Jenkins.client
end
