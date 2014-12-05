require 'logger'
require_relative '../ci-tooling/lib/debian/changelog'

logger = Logger.new(STDOUT)

logger.info("Starting source only build")

Dir.chdir('packaging') do
    $changelog = Changelog.new
end

SOURCE_NAME = $changelog.name

WORKSPACE_DIR = '/workspace/' + ENV['WORKSPACE'].split('/')[-1].strip

system("schroot -c unstable-amd64 -d #{WORKSPACE_DIR} -- ./tooling/contained/dci.rb source #{WORKSPACE_DIR}")
system("dcmd mv /var/lib/sbuild/build/#{SOURCE_NAME}*.changes build/")