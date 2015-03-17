require_relative '../ci-tooling/lib/logger'

fail 'Need a release to build for!' unless ARGV[0]
fail 'Need a flavor!' unless ARGV[1]

RELEASE = ARGV[0]
FLAVOR = ARGV[1]

$logger = DCILogger.instance

$logger.info("Starting ISO build for #{FLAVOR}")
system("schroot -u root -c #{RELEASE}-amd64 -d #{ENV['WORKSPACE']} \
        -o jenkins.workspace=#{ENV['WORKSPACE']} \
        -- ruby ./tooling/ci-tooling/dci.rb imager \
        #{RELEASE} #{FLAVOR}")
