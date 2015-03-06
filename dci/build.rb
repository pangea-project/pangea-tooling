require 'fileutils'
require 'json'
require_relative '../ci-tooling/lib/logger'

logger = DCILogger.instance

RELEASE = `grep Distribution #{ARGV[1]}`.split(':')[-1].strip
PACKAGE = `grep Source #{ARGV[1]}`.split(':')[-1].strip
RESULT_DIR = '/var/lib/sbuild/build'
REPOS_FILE = 'debian/meta/extra_repos.json'

logger.info("Starting binary build for #{RELEASE}")
repos = ['default']

if Dir.exist? "#{ENV['WORKSPACE']}/packaging"
  Dir.chdir("#{ENV['WORKSPACE']}/packaging") do
    if File.exist? REPOS_FILE
      repos += JSON.parse(File.read(REPOS_FILE))['repos']
    end
  end
end

repos = repos.join(',')

system("schroot -u root -c #{RELEASE}-#{ENV['arch']} -d #{ENV['WORKSPACE']} \
-o jenkins.workspace=#{ENV['WORKSPACE']} \
-- ruby ./tooling/ci-tooling/dci.rb build \
-r #{repos} \
-w #{ENV['WORKSPACE']}/tooling/data \
#{ARGV[1]}")

FileUtils.mkdir_p('build/binary') unless Dir.exist? 'build/binary'
changes_files = Dir.glob("#{RESULT_DIR}/#{PACKAGE}*changes").select { |changes| !changes.end_with? '_source.changes' }

changes_files.each do |changes_file|
  logger.info("Copying over #{changes_file} into Jenkins")
  system("dcmd mv #{changes_file} build/binary/")
end
