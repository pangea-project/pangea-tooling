#!/usr/bin/env ruby

require 'fileutils'

require_relative '../lib/ci/containment'

TOOLING_PATH = File.dirname(__dir__)

JOB_NAME = ENV.fetch('JOB_NAME')
DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
ARCH = ENV.fetch('ARCH')

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

binds = [
  "#{TOOLING_PATH}:#{TOOLING_PATH}",
  "#{Dir.pwd}:#{Dir.pwd}"
]

c = CI::Containment.new(JOB_NAME,
                        image: CI::PangeaImage.new(:ubuntu, DIST),
                        binds: binds,
                        privileged: true)
cmd = ["#{TOOLING_PATH}/kci/imager/build.sh", Dir.pwd, DIST, ARCH, TYPE]
status_code = c.run(Cmd: cmd)
exit status_code unless status_code == 0

DATE = File.read('result/date_stamp').strip
PUB_PATH = "/var/www/kci/images/#{ARCH}/#{DATE}"
FileUtils.mkpath(PUB_PATH)
%w(iso manifest zsync).each do |type|
  unless system("cp -r --no-preserve=ownership result/*.#{type} #{PUB_PATH}/")
    abort "File type #{type} failed to copy to public directory."
  end
end
FileUtils.chown_R('jenkins', 'www-data', PUB_PATH, verbose: true)
unless system("cp -avr #{PUB_PATH} /mnt/s3/kci/images/#{ARCH}/")
  abort 'Failed to copy to s3 bucket.'
end

generate_html_cmd = ["#{__dir__}/../generate_html.rb"]
generate_html_cmd << '-o' << '/mnt/s3/kci/index.html'
generate_html_cmd << 'kci'
system(*generate_html_cmd) # Ignore return value as this is not too important.

exit 0
