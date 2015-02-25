#!/usr/bin/env ruby

JENKINS_PATH = '/var/lib/jenkins'
TOOLING_PATH = '$JENKINS_PATH/tooling'
CNAME="jenkins-imager-$DIST-$TYPE-$ARCH"

module Schroot
  module_function

  def exist?(chroot_name)
    system("schroot -i -c #{chroot_name}")
  end

  def in_session(chroot_name)
    session = Session.new(CNAME)
    session.start
    yield session
  ensure
    session.end
  end

  class Session
    attr_reader :id
    attr_reader :chroot_name

    def initialize(chroot_name)
      @id = ''
      @chroot_name = chroot_name
    end

    def start
      @id = "session:#{`schroot -b -c #{@chroot_name}`}"
    end

    def end
      `schroot -e -c #{@id}`
      @id = ''
    end
  end
end

unless Schroot.exist?(CNAME)
    echo "Imager schroot not set up. Talk to an admin."
    exit 1
end

# Manually handle the schroot session to prevent it from lingering after we exit.

Schroot.in_session do |session|
# FIXME: port
  system(%Q(ssh jenkins@localhost "cd #{Dir.pwd} && schroot -r -c #{session.id} #{TOOLING_PATH}/imager/build.sh #{Dir.pwd} #{DIST} #{ARCH} #{TYPE}"))
end

date = File.read('result/date_stamp').strip.chop
pubdir = "/var/www/kci/images/#{arch}/#{date}"
FileUtils.mkpath(pubdir)
files = Dir['result/*.iso'] + Dir['result/*.manifest'] + Dir['result/*.zsync']
files.each do |file|
  system("cp -r --no-preserve=ownership #{file} #{pubdir}")
end
FileUtils.chown_R('jenkins', 'www-data', pubdir, verbose: true)

FileUtils.cp(pubdir, "/mnt/s3/kci/images/#{arch}/",
             verbose: true, preserve: true)

# FIXME: todo
# ~/jobs/mgmt_tooling/workspace/s3-images-generator/generate_html.rb -o /mnt/s3/kci/index.html kci
