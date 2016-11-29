require 'docker'

REQUIRED_DOCKER_API_VERSION = Gem::Version.new(1.24)
DOCKER_MAX_API_VERSION = Gem::Version.new(Docker.version.fetch('Version'))
if (Gem::Version.new(Docker::API_VERSION) < REQUIRED_DOCKER_API_VERSION) &&
   (DOCKER_MAX_API_VERSION >= REQUIRED_DOCKER_API_VERSION)
  Docker::API_VERSION = REQUIRED_DOCKER_API_VERSION
end
