require 'docker'

REQUIRED_DOCKER_API_VERSION = 1.24

if (Gem::Version.new(Docker::API_VERSION) < Gem::Version.new(REQUIRED_DOCKER_API_VERSION)) &&
   (Docker.version.fetch('Version').to_f >= REQUIRED_DOCKER_API_VERSION)
  Docker::API_VERSION = REQUIRED_DOCKER_API_VERSION
end
