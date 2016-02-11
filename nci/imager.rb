#!/usr/bin/env ruby

require 'fileutils'

require_relative '../lib/ci/containment'

TOOLING_PATH = File.dirname(__dir__)

JOB_NAME = ENV.fetch('JOB_NAME')
DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
ARCH = ENV.fetch('ARCH')
META = ENV.fetch('META')

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

binds = [
  "#{TOOLING_PATH}:#{TOOLING_PATH}",
  "#{Dir.pwd}:#{Dir.pwd}"
]

c = CI::Containment.new(JOB_NAME,
                        image: CI::PangeaImage.new(:ubuntu, DIST),
                        binds: binds,
                        privileged: true)
cmd = ["#{TOOLING_PATH}/nci/imager/build.sh", Dir.pwd, DIST, ARCH, TYPE, META]
status_code = c.run(Cmd: cmd)
exit status_code unless status_code == 0

DATE = File.read('result/date_stamp').strip
WEBSITE_PATH = "/var/www/images/#{META}-#{TYPE}-proposed/"
PUB_PATH = "#{WEBSITE_PATH}#{DATE}"
FileUtils.mkpath(PUB_PATH)
%w(iso manifest zsync).each do |type|
  unless system("cp -r --no-preserve=ownership result/*.#{type} #{PUB_PATH}/")
    abort "File type #{type} failed to copy to public directory."
  end
end

FileUtils.rm("#{WEBSITE_PATH}current", :force => true)
FileUtils.ln_s(PUB_PATH, "#{WEBSITE_PATH}current")

exit 0
