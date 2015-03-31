#!/usr/bin/env ruby

require 'docker'
require 'logger'
require 'logger/colors'

NAME = ENV.fetch('NAME')
Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

@log = Logger.new(STDOUT)
@log.level = Logger::WARN

Thread.new do
  Docker::Event.stream { |event| @log.debug event }
end

Docker::Image.build(File.read(File.dirname(__FILE__) + '/Dockerfile'),
                    t: "jenkins/#{NAME}:latest") do |chunk|
  chunk = JSON.parse(chunk)
  keys = chunk.keys
  if keys.include?('stream')
    puts chunk['stream']
  elsif keys.include?('error')
    @log.error chunk['error']
    @log.error chunk['errorDetail']
  else
    fail "Unknown response type in #{chunk}"
  end
end
