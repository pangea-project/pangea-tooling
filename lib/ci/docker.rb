require 'docker'

if Gem::Version.new(Docker::API_VERSION) < Gem::Version.new(1.24)
  Docker::API_VERSION = '1.24'.freeze
end
