require 'logger'
require_relative '../ci-tooling/lib/debian/changelog'

logger = Logger.new(STDOUT)

logger.info("Starting source only build")

Dir.chdir('packaging') do
    $changelog = Changelog.new
end

REPOS_FILE = 'debian/meta/add_repos.json'

repos = []
Dir.chdir("#{ENV['WORKSPACE']}/packaging") do
  if File.exist? REPOS_FILE
      repos = JSON::Parse(File.read(REPOS_FILE))['repos']
  end
end

repos = repos.join(',')

SOURCE_NAME = $changelog.name

RELEASE = ENV['JOB_NAME'].split('_')[-1]

system("schroot -u root -c #{RELEASE}-amd64 -d #{ENV['WORKSPACE']} -- ruby ./tooling/ci-tooling/dci.rb source -r #{repos} -w #{ENV['WORKSPACE']}/tooling/data #{ENV['WORKSPACE']} #{RELEASE}")
Dir.mkdir('build') unless Dir.exist? 'build'

raise 'Cant move files!' unless system("dcmd mv /var/lib/sbuild/build/#{SOURCE_NAME}*.changes build/")
