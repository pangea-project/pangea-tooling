#!/usr/bin/env ruby

require 'net/scp'

NAME = ENV.fetch('NAME')
VERSION = ENV.fetch('VERSION')
REPO = "jenkins/#{NAME}"
TAG = 'latest'
REPO_TAG = "#{REPO}:#{TAG}"

%w(alpha beta gamma delta).each do |node|
  Net::SCP.start(node, 'jenkins-slave') do |scp|
    puts scp.upload!('image.tar', '/tmp/image.tar')
    puts ssh.exec!("docker import /tmp/image.tar #{REPO_TAG}")
  end
end
