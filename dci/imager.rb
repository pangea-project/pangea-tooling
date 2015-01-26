require_relative '../ci-tooling/lib/logger'

fail 'Need a release to build for!' unless ARGV[1]
fail 'Need a flavor!' unless ARGV[2]

RELEASE = ARGV[1]
FLAVOR = ARGV[2]

$logger = DCILogger.instance

$logger.info("Starting ISO build for #{ARGV[1]}")
system("schroot -u root -c #{RELEASE}-amd64 -d #{ENV['WORKSPACE']} \
        -o jenkins.workspace=#{ENV['WORKSPACE']} \
        -- ruby ./tooling/ci-tooling/dci.rb imager \
        #{RELEASE} #{FLAVOR}")
