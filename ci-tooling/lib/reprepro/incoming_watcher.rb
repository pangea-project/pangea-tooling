#!/usr/bin/env ruby

require 'rb-inotify'

module Reprepro
  def reprepro(*args)
    system('reprepro', *args)
  end

  class IncomingWatcher
    def self.start(path)
      repo = '/srv/apt'
      notifier = INotify::Notifier.new
      notifier.watch(path, :create) do |event|
        next unless event.name.end_with?('.changes')
        system('reprepro', '-V', '-b', repo, '--waitforlock', '1000',
               'processincoming', 'default', event.name)
        # S3MIRRORS.each do |mirror|
        #   # NOTE: Make sure that when modifying this command, the target ends
        #   # with a '/'
        #   system("s3cmd -c #{repo}/s3cfg -v sync " \
        #          "#{repo}/pool #{repo}/dists" " \
        #          "s3://#{mirror}/dci/#{FOLDER_NAME[repo]}/debian/")
        # end
      end
      notifier.run
    end
  end
end

# :nocov:
if __FILE__ == $PROGRAM_NAME
  Reprepro::IncomingWatcher.start('/srv/apt_incoming')
end
# :nocov:

require 'rb-inotify'
require 'logger'
require 'thwait'

S3MIRRORS = ['pangea-data', 'pangea-data-lax-dci']
repos = []
threads = []
FOLDER_NAME = {}

logger = Logger.new(STDOUT)
logger.info 'Starting ...'

notifier = INotify::Notifier.new

Dir['/home/publisher/repos/*'].each do |d|
  next if d.include? 'processchanges'
  repos << d if File.directory? d
end

logger.info "Will process #{repos}"

logger.info 'Initial sync ...'

# NOTE: Make sure that when modifying this command, the target ends
# with a '/'
repos.each do |repo|
  FOLDER_NAME[repo] ||= repo.split('/')[-1]
  S3MIRRORS.each do |mirror|
    logger.info "Sending to #{mirror}/#{FOLDER_NAME[repo]}"
    origin = "#{repo}/pool #{repo}/dists"
    target = "s3://#{mirror}/dci/#{FOLDER_NAME[repo]}/debian/"
    system("s3cmd -c #{repo}/s3cfg -v sync #{origin} #{target}")
  end
end
logger.info 'Intial sync complete!'

repos.each do |repo|
  threads << Thread.new do
    logger.info "Processing #{repo}"
    notifier.watch("#{repo}/incoming", :create) do |event|
      if event.name.end_with? '.changes'
        logger.info "Processing #{event.name}"
        File.open(repo, 'r') do |f|
          f.flock(File::LOCK_EX)
          logger.info 'Locked reprepro dir'
          system('reprepro', '-V', '-b', repo, '--waitforlock', '1000',
                 'processincoming', 'incoming', event.name)
          logger.info 'INFO: Uploading to S3'
          S3MIRRORS.each do |mirror|
            logger.info "Sending to #{mirror}/#{FOLDER_NAME[repo]}"
            # NOTE: Make sure that when modifying this command, the target ends
            # with a '/'
            origin = "#{repo}/pool #{repo}/dists"
            target = "s3://#{mirror}/dci/#{FOLDER_NAME[repo]}/debian/"
            system("s3cmd -c #{repo}/s3cfg -v sync #{origin} #{target}")
          end
          f.flock(File::LOCK_UN)
        end
      end
    end
    logger.info "Installed watch for #{repo}"
  end
end

notifier.run
ThreadsWait.all_waits(threads)
