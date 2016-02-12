require_relative '../ci-tooling/lib/logger'
require 'fileutils'

raise 'Need a release to build for!' unless ARGV[1]
raise 'Need a flavor!' unless ARGV[2]

RELEASE = ARGV[1]
FLAVOR = ARGV[2]

logger = DCILogger.instance

logger.info("Starting ISO build for #{RELEASE}")

system("schroot -u root -c #{RELEASE}-#{ENV['arch']} -d #{ENV['WORKSPACE']} \
        -o jenkins.workspace=#{ENV['WORKSPACE']} \
        -- ruby ./tooling/ci-tooling/dci.rb imager \
        #{RELEASE} #{FLAVOR}")

Dir.mkdir('build') unless Dir.exist? 'build'

FileUtils.rm_rf('build/*')

# FileUtils.mv("/var/lib/sbuild/build/#{FLAVOR}",
#              'build/',
#              verbose: true,
#              force: true)

system("mv -vf /var/lib/sbuild/build/#{FLAVOR} build/")

logger.close
