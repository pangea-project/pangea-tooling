# frozen_string_literal: true
require 'logger'
require 'singleton'

# Debian CI Logger
class DCILogger < Logger
  include Singleton

  def initialize
    @logdev = Logger::LogDevice.new(STDOUT)
    @level = INFO
    @formatter = proc do |severity, _datetime, _progname, msg|
      "DCI-#{severity} :: #{msg}\n"
    end
  end
end

# Deprecated, use DCILogger.instance instead
def new_logger
  warn 'Please use DCILogger.instance instead'
  DCILogger.instance
end
