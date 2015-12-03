#!/usr/bin/env ruby

require 'jenkins_api_client'

client = JenkinsApi::Client.new(server_ip: 'mobile.kci.pangea.pub',
                                server_port: 8080)

while client.queue.list.include?('mgmt_test') ||
      client.job.status('mgmt_test') == 'running'
  puts 'Waiting for deployment to finish'
  sleep 10
end
