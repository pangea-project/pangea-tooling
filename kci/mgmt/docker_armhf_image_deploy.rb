#!/usr/bin/env ruby

require 'net/scp'
require 'logger'
require 'logger/colors'

require_relative '../../ci-tooling/lib/jenkins'

NAME = ENV.fetch('NAME')
VERSION = ENV.fetch('VERSION')
REPO = "jenkins/#{NAME}"
TAG = 'latest'
REPO_TAG = "#{REPO}:#{TAG}"

@log = Logger.new(STDERR)

Jenkins.client.node.list.each do |node|
  next if node == 'master'
  @log.info "deploying to node #{node}"
  Net::SCP.start(node, 'jenkins-slave') do |scp|
    @log.info 'uploading image'
    puts scp.upload!('image.tar', '/tmp/image.tar')
    @log.info 'importing'
    puts scp.session.exec!("cat /tmp/image.tar | docker import - #{REPO_TAG}")
    @log.info 'import done'
  end
end
