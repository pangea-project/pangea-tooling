#!/usr/bin/env ruby

require 'jenkins_api_client'

JOB_NAME = ENV.fetch('JOB_NAME')

client = JenkinsApi::Client.new(server_ip: 'mobile.neon.pangea.pub',
                                server_port: 8080)

while client.queue.list.include?(JOB_NAME) ||
      client.job.status(JOB_NAME) == 'running'
  puts 'Waiting for deployment to finish'
  sleep 10
end
