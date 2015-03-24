require_relative '../ci-tooling/lib/logger'

fail 'Need a release to build for!' unless ARGV[1]
fail 'Need a flavor!' unless ARGV[2]

RELEASE = ARGV[1]
FLAVOR = ARGV[2]

$logger = DCILogger.instance

$logger.info("Starting ISO build for #{RELEASE}")
system("schroot -u root -c #{RELEASE}-amd64 -d #{ENV['WORKSPACE']} \
        -o jenkins.workspace=#{ENV['WORKSPACE']} \
        -- ruby ./tooling/ci-tooling/dci.rb imager \
        #{RELEASE} #{FLAVOR}")

Dir.mkdir('build') unless Dir.exist? 'build'
system('mv',
       '-v',
       '/var/lib/sbuild/build/live-image*',
       '/var/lib/sbuild/build/MD5SUM',
       '/var/lib/sbuild/build/SHA256SUM',
       'build/')
