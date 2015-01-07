fail "Need a mozilla product to build for!" unless ARGV[1]
fail "Need a release to build for!" unless ARGV[2]

PACKAGE = ARGV[1]
RELEASE = ARGV[2]

system("schroot -u root -c #{RELEASE}-amd64 -d #{ENV['WORKSPACE']} -- ruby ./tooling/ci-tooling/dci.rb mozilla \
    #{PACKAGE} #{RELEASE}")

Dir.mkdir('build') unless Dir.exist? 'build'

raise 'Cant move files!' unless system("dcmd mv /var/lib/sbuild/build/#{PACKAGE}*.changes build/")
