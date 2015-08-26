#!/usr/bin/env ruby

require 'docker'
require 'logger'
require 'logger/colors'

$stdout = $stderr

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.
FLAVOR = ENV.fetch('FLAVOR')
VERSION = ENV.fetch('VERSION')
REPO = "pangea/#{FLAVOR}"
TAG = VERSION
REPO_TAG = "#{REPO}:#{TAG}"

@log = Logger.new(STDERR)
@log.level = Logger::WARN

Thread.new do
  Docker::Event.stream { |event| @log.debug event }
end

container = Docker::Container.create(Image: REPO_TAG, Cmd: ['sh'])
File.open('image.tar', 'w') do |f|
  container.export { |chunk| f.write(chunk) }
end
