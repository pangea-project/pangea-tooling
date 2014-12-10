require 'logger'

logger = Logger.new

RELEASE = `grep Distribution #{ARGV[1]}`.split(':')[-1].strip
PACKAGE = `grep Source #{ARGV[1]}`.split(':')[-1].strip

logger.info("Starting binary build for #{RELEASE}")

# TODO: Extend this so that we don't hardcode amd64 here, and instead use something from the job
system("schroot -u root -c #{RELEASE}-amd64 -d #{ENV['WORKSPACE']} -- ruby ./tooling/ci-tooling/dci.rb build #{ARGV[1]}")

system("dcmd mv /var/lib/sbuild/build/binary/#{PACKAGE}*.changes build/binary/")