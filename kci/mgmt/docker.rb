#!/usr/bin/env ruby

require 'docker'

NAME = ENV.fetch('NAME')

Thread.new do
  Docker::Event.stream { |event| puts event }
end

Docker::Image.build(File.read(File.dirname(__FILE__) + '/Dockerfile'),
                    t: "jenkins/#{NAME}:latest") do |chunk|
  chunk = JSON.parse(chunk)
  chunk.values.each { |v| puts v }
end
