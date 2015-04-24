fail "Need a mozilla product to build for!" unless ARGV[1]
fail "Need a release to build for!" unless ARGV[2]

KEYID = '125B4BCF'

PACKAGE = ARGV[1]
RELEASE = ARGV[2]

UBUNTU_RELEASES = `ubuntu-distro-info -a`.split
DEBIAN_RELEASES = `debian-distro-info -a`.split

system("schroot -u root -c #{RELEASE}-amd64 -d #{ENV['WORKSPACE']} -o jenkins.workspace=#{ENV['WORKSPACE']} -- ruby ./tooling/ci-tooling/dci.rb mozilla \
    #{PACKAGE} #{RELEASE}")

Dir.mkdir('build') unless Dir.exist? 'build'

fail 'Cant move files!' unless system("dcmd mv /var/lib/sbuild/build/#{PACKAGE}*.changes build/")

unless DEBIAN_RELEASES.include? RELEASE
  fail "Can't sign!" unless system("debsign -k#{KEYID} build/*.changes")
  fail "Can't upload!" unless system("dput ppa:plasmazilla/builds build/*.changes")
end
