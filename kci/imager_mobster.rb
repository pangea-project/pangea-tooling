#!/usr/bin/env ruby

require 'fileutils'

require_relative '../lib/docker/containment'

TOOLING_PATH = File.dirname(__dir__)

JOB_NAME = ENV.fetch('JOB_NAME')
DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
ARCH = ENV.fetch('ARCH')
CNAME = "jenkins-imager-#{DIST}-#{TYPE}-#{ARCH}"

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

binds = [
  "#{TOOLING_PATH}:#{TOOLING_PATH}",
  "#{Dir.pwd}:#{Dir.pwd}"
]

c = CI::Containment.new(JOB_NAME,
                        image: CI::PangeaImage.new(:ubuntu, DIST),
                        binds: binds,
                        privileged: true)
cmd = ["#{TOOLING_PATH}/kci/imager/build_mobster.sh", Dir.pwd, DIST, ARCH, TYPE]
status_code = c.run(Cmd: cmd)
exit status_code unless status_code == 0

DATE = File.read('result/date_stamp').strip
PUB_PATH = "/mnt/s3/mobile.kci/images/#{DATE}"
FileUtils.mkpath(PUB_PATH)

%w(iso manifest zsync).each do |type|
  unless system("cp -avr result/*.#{type} #{PUB_PATH}/")
    abort "Failed to copy #{type} files"
  end
end

exit 0
