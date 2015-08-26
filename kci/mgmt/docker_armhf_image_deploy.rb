#!/usr/bin/env ruby

require 'net/scp'
require 'logger'
require 'logger/colors'

require_relative '../../ci-tooling/lib/jenkins'

$stdout = $stderr

NAME = ENV.fetch('NAME')
VERSION = ENV.fetch('VERSION')
FLAVOR = ENV.fetch('FLAVOR')
REPO = "pangea/#{FLAVOR}"
TAG = VERSION
REPO_TAG = "#{REPO}:#{TAG}"

@log = Logger.new(STDERR)

build_node = File.read('node').strip

Jenkins.client.node.list.each do |node|
  next if node == 'master'
  next if node == build_node
  @log.info "deploying to node #{node}"
  Net::SCP.start(node, 'jenkins-slave') do |scp|
    @log.info 'uploading image'
    puts scp.upload!('image.tar', '/tmp/image.tar')
    @log.info 'importing on node'
    puts scp.session.exec!('~/tooling/kci/mgmt/docker_import.rb /tmp/image.tar')
    @log.info 'import done'
  end
end
