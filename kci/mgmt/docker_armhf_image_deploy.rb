#!/usr/bin/env ruby

require 'net/scp'

require_relative '../../ci-tooling/lib/jenkins'

NAME = ENV.fetch('NAME')
VERSION = ENV.fetch('VERSION')
REPO = "jenkins/#{NAME}"
TAG = 'latest'
REPO_TAG = "#{REPO}:#{TAG}"

Jenkins.client.node.list.each do |node|
  next if node == 'master'
  Net::SCP.start(node, 'jenkins-slave') do |scp|
    puts scp.upload!('image.tar', '/tmp/image.tar')
    puts ssh.exec!("docker import /tmp/image.tar #{REPO_TAG}")
  end
end
