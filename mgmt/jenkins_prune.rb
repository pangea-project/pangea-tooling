#!/usr/bin/env ruby

require_relative '../lib/jenkins/jobdir.rb'

Dir.glob("#{Dir.home}/jobs/*").each do |jobdir|
  Jenkins::JobDir.prune_logs(jobdir)
end
