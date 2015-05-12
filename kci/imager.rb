#!/usr/bin/env ruby

require_relative '../lib/docker/containment'

TOOLING_PATH = File.dirname(__dir__)

JOB_NAME = ENV.fetch('JOB_NAME')
DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
ARCH = ENV.fetch('ARCH')
CNAME = "jenkins-imager-#{DIST}-#{TYPE}-#{ARCH}"

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

binds =  [
  "#{TOOLING_PATH}:#{TOOLING_PATH}",
  "#{Dir.pwd}:#{Dir.pwd}"
]

c = Containment.new(JOB_NAME, image: "jenkins/#{DIST}_#{TYPE}", binds: binds)
status_code = c.run(Cmd: ["#{TOOLING_PATH}/kci/imager/build.sh"], Privileged: true)
exit status_code unless status_code == 0


# DATE=$(cat result/date_stamp)
# PUB=/var/www/kci/images/$ARCH/$DATE
# mkdir -p $PUB
# cp -r --no-preserve=ownership result/*.iso $PUB
# cp -r --no-preserve=ownership result/*.manifest $PUB
# cp -r --no-preserve=ownership result/*.zsync $PUB
# chown jenkins:www-data -Rv $PUB
#
# cp -avr $PUB /mnt/s3/kci/images/$ARCH/
#
# ~/tooling3/s3-images-generator/generate_html.rb -o /mnt/s3/kci/index.html kci
