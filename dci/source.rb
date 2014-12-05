require 'logger'
require_relative '../ci-tooling/lib/debian/changelog'

logger = Logger.new(STDOUT)

logger.info("Starting source only build")

Dir.chdir('packaging') do
    $changelog = Changelog.new
end

SOURCE_NAME = $changelog.name

system("schroot -u root -c unstable-amd64 -d #{ENV['WORKSPACE']} -- ruby ./tooling/ci-tooling/dci.rb source #{ENV['WORKSPACE']}")
system("dcmd mv /var/lib/sbuild/build/#{SOURCE_NAME}*.changes build/")
