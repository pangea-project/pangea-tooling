# frozen_string_literal: true

require 'docker'

REQUIRED_DOCKER_API_VERSION = Gem::Version.new(1.24)
DOCKER_MAX_API_VERSION = Gem::Version.new(Docker.version.fetch('ApiVersion'))

if (Gem::Version.new(Docker::API_VERSION) < REQUIRED_DOCKER_API_VERSION) &&
   (DOCKER_MAX_API_VERSION >= REQUIRED_DOCKER_API_VERSION)
  # Monkey patched docker
  module Docker
    remove_const :API_VERSION
    API_VERSION = REQUIRED_DOCKER_API_VERSION
  end
end

# Reset connection in order to pick up any connection options one might set
# after requiring this file
Docker.reset_connection!
