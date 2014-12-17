require 'logger'
require 'fileutils'
require 'json'
require_relative 'dci/lib/logger'

logger = new_logger

RELEASE = `grep Distribution #{ARGV[1]}`.split(':')[-1].strip
PACKAGE = `grep Source #{ARGV[1]}`.split(':')[-1].strip
RESULT_DIR = '/var/lib/sbuild/build'
REPOS_FILE = 'debian/meta/extra_repos.json'

logger.info("Starting binary build for #{RELEASE}")
repos = []
Dir.chdir("#{ENV['WORKSPACE']}/packaging") do
  if File.exist? REPOS_FILE
      repos = JSON::parse(File.read(REPOS_FILE))['repos']
  end
end

repos = repos.join(',')

# TODO: Extend this so that we don't hardcode amd64 here, and instead use something from the job
system("schroot -u root -c #{RELEASE}-amd64 -d #{ENV['WORKSPACE']} -- ruby ./tooling/ci-tooling/dci.rb build -r #{repos} -w #{ENV['WORKSPACE']}/tooling/data #{ARGV[1]}")

FileUtils.mkdir_p('build/binary') unless Dir.exists? 'build/binary'
changes_files = Dir.glob("#{RESULT_DIR}/#{PACKAGE}*changes").select { |changes| !changes.include? 'source' }

changes_files.each do |changes_file|
    logger.info("Copying over #{changes_file} into Jenkins")
    system("dcmd mv #{changes_file} build/binary/")
end
