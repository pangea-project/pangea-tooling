#!/usr/bin/env ruby

require 'docker'
require 'logger'
require 'logger/colors'

NAME = ENV.fetch('NAME')

@log = Logger.new(STDOUT)
@log.level = Logger::WARN

Thread.new do
  Docker::Event.stream { |event| @log.debug event }
end

Docker::Image.build(File.read(File.dirname(__FILE__) + '/Dockerfile'),
                    t: "jenkins/#{NAME}:latest") do |chunk|
  chunk = JSON.parse(chunk)
  chunk.values.each { |v| puts v }
end
