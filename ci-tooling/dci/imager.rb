require 'fileutils'
require 'date'
require 'pp'
require_relative '../lib/logger'
require_relative '../lib/dci'

pp ENV.to_h

raise 'Need a release to build for!' unless ARGV[1]
raise 'Need a flavor to  build!' unless ARGV[2]

RELEASE = ARGV[1]
FLAVOR = ARGV[2]

OWNCLOUD_PREF = "config/archives/owncloud.pref << EOF
Package: owncloud*
Pin: release o=\"http://pangea-data.s3.amazonaws.com/dci\"
Pin-Priority: 1001".freeze

REPO_KEY = '-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1

mQINBFRXlYIBEADrbnEhGbFCjEkYASk95azW9YURTDcffWzTdlirg1wpHa3wAZwc
3+zL0xPpulQakKNGNmHxN3HIlKG6hURrJBPb259ODKuz6VoQLvAbD0j3xik9YJ1Y
uDc2xbMTvXj67OMchXdNjiJKd2/3I7TSB1Obtqm/y1bOKVoxauK4fXodiq7GUB8o
QseJ6K2/aob00ebwQsHGEjmV7Y5rRevKofb+NuR2pUsZf6lJwzJx3caNIZmktJFy
Hn1s4TGbBwDBrVMYSHm5TgS6LCNhKJ3XfztulsvyaE0pyvZxLv+L7FhEy6xA7W1L
ljcwMM7neGlGrKh9BkHV00TGlwpDGbzuCT3H/yUm+4N71o9hSbNGijvHmm6L1YGB
TDijosSPAFD8M2TMSpa5sQawRPe89IN29i+ZiyGlIF+SZT+yy1d1uqadHxf4lyuj
6mYkrZn2Zeozh/ZFim066Jtc3O4/ChITOZvZ20H03gZJIsNlkbZFgjG4itm0Bra6
C4plzSAkEeOIIIweJzXsSPZ/eTKOCPf7Iqijx1i31DVcV/d117vWcGzv8trQqvyi
wEQgP27xgy7x3FKdvpflSomftu29i5e4wTkFqaW7TpssVBscaiUj2YC5D1Bc+dn6
93dQoi7ZF4ofNV2va6YBnhZ89LUwjZBaZgAgyGwLA6cQfj+AI4dQ95xDbwARAQAB
tC1EZWJpYW4gQ0kgUGFja2FnZSBQdWJsaXNoZXIgPG51bGxAcGFuZ2VhLnB1Yj6J
AjcEEwEKACEFAlRXlYICGwMFCwkIBwMFFQoJCAsFFgMCAQACHgECF4AACgkQsr1N
9K8QcGmtNRAA4gzO1N0pgeldJwqA2fSCqxyUkyFJYN6nJ+iyx9c+/V1nlG0IR2h8
t0B89oGhkBLrSjVprLOvqBbe0Mr+WI8fsbGcZqzWkinC88HS4tKSG3mTb3zhHrPW
XXNgZBFoEzr9coK2FPb1Wf+OZlt/1KYFD9fsXH09t7S65+LGN6Rwt90HRM/rLQhS
7QZEDGTekbfEFEWU4IhuadFd6Iogg3w/3Ak4jLn3AZl6C4I9erxXlbd1nNXjh8Kh
v1oMQHxWBfQq7fSlk8T2e9UTETcQek3ySpoTRuwv/w6r+OZ3QY67zbdZrl7TLjwU
iOtAqOfvMH5MYAExlWgZ9QRFr1q9wBsyDZI6V977kvfgS2obrHL9JVJzcH7oLBz7
9ZBcLzpj4eJdSGVgffoAqZzNQA3QYg8y2GRHwR53jjs+5atMaEWazRdZbtoYTr/G
GeJgPYw9q9+L/XoYLC9K3SW/e7tgnAxRXaX8puQkqEtSGxQbrnI2KAzXKtvzolhJ
GZCJiO0hg8SivtuaIUOyg2ppJ7GL8yDTbqeEv/vuR6u3FIInf5fkoq8UAVZW1kk9
E8h+hEwC9yn+GErgrWtihLpm7ZHIePi3vhCkwiMh7wJQSvHQfd4k037jj8v3Tf4M
a4hw1LvfpbOxVBwDdqEFgH6LQI5eXNGwR9Ps3F1KA3yNVI2FKbArVPQ=
=UBq7
-----END PGP PUBLIC KEY BLOCK-----'.freeze

def workarounds
  system('rm -rf config/bootloaders/*')

  File.open('config/package-lists/live.list.chroot', 'a') do |f|
    f.puts('live-config')
    f.puts('live-config-systemd')
    f.puts('live-boot')
    f.puts('live-boot-initramfs-tools')
  end

  contents = File.read('config/package-lists/desktop.list.chroot')
  File.open('config/package-lists/desktop.list.chroot', 'w') do |f|
    contents.gsub!(/plymouth-drm/, '')
    contents.gsub!(/task-kde-desktop/, '')
    f.puts(contents)
  end
  puts `grep -iR plymouth-drm config/package-lists`

  Dir.glob('config/package-lists/dkms.list.*').each do |f|
    File.delete(f)
  end

  # Workarounds for ARM
  return unless RbConfig::CONFIG['host_cpu'] == 'arm'
  Dir.glob('config/package-lists/memtest.list.*').each do |f|
    File.delete(f)
  end

  contents = File.read('config/package-lists/desktop.list.chroot')
  File.open('config/package-lists/desktop.list.chroot', 'w') do |f|
    contents.gsub!(/i965-va-driver/, '')
    f.puts(contents)
  end
end

def deb_from_url(url)
  packages_chroot = 'config/packages.chroot/'
  FileUtils.mkdir_p(packages_chroot) unless Dir.exist?(packages_chroot)
  system("wget -P #{packages_chroot} #{url}")
end

logger = DCILogger.instance

Dir.mkdir('build') unless Dir.exist? 'build'

MIRROR = 'http://127.0.0.1:3142/debian'.freeze
CLOUDFRONT_MIRROR = 'http://cloudfront.debian.net/debian'.freeze
Dir.chdir('build') do
  logger.info('Installing some extra utils')
  dci_run_cmd('apt-get update')
  system('apt-get -y install live-images live-build live-tools')
  system('lb clean --purge')

  extra_opts = []
  packages = []
  packages_from_url = []
  repos = []

  case FLAVOR
  when /.*netrunner.*desktop/
    repos = %w(qt5 frameworks plasma netrunner calamares plasmazilla extras)
    # live build is a bit shit at handling multi arch at the moment
    # So we need to explicitly specify that we need skype-bin:i386 on the ISO
    packages = %w(netrunner-desktop calamares calamares-branding skype-bin:i386)
    packages_from_url = %w(http://media.steampowered.com/client/installer/steam.deb)

    # Install the netrunner-syslinux-theme
    system('apt-get -y install syslinux-themes-netrunner')
    extra_opts << '--debian-installer-gui false'

  when /.*netrunner.*cloud/
    repos = %w(qt5 frameworks plasma netrunner calamares)
    packages = %w(netrunner-desktop calamares)

    File.write('config/archives/owncloud.pref', OWNCLOUD_PREF)

  when /.*maui.*/
    repos = %w(qt5 frameworks plasma maui calamares)
    packages = %w(hawaii-shell)

  when /.*netrunner.*armhf/
    repos = %w(qt5 frameworks plasma netrunner extras)
    packages = %w(netrunner-desktop)
    extra_opts << '--binary-images tar'
    # Don't need no kernels in my rootfs
    extra_opts << '--linux-flavours none'
    extra_opts << '--linux-packages none'
    extra_opts << '--binary-filesystem ext4'
    extra_opts << '--bootloader none'
    extra_opts << '--debian-installer-gui false'
  else
    logger.error("Don't understand the flavor #{FLAVOR}")
    exit 1
  end

  system("lb config --config kde-desktop \
  --distribution #{RELEASE} \
  -m #{MIRROR} \
  --mirror-bootstrap #{CLOUDFRONT_MIRROR} \
  --mirror-chroot #{CLOUDFRONT_MIRROR} \
  --mirror-binary #{CLOUDFRONT_MIRROR} \
  --debian-installer false \
  --source false \
  --security false \
  --archive-areas 'main contrib non-free' \
  --updates false \
  #{extra_opts.join(' ')}")

  FileUtils.mkdir_p('config/archives')
  workarounds

  # Copy over bootloader modifications post config
  case FLAVOR
  when /.*netrunner.*desktop/
    isolinux_dir = 'config/bootloaders/isolinux/'
    FileUtils.mkdir_p(isolinux_dir) unless Dir.exist?(isolinux_dir)
    system('cp -avRL /usr/share/syslinux/themes/netrunner/isolinux-live/* '\
           "#{isolinux_dir}")
  end

  packages.each do |package|
    File.write('config/package-lists/netrunner.list.chroot',
               package + "\n", mode: 'a')
  end

  unless packages_from_url.empty?
    packages_from_url.each do |package|
      deb_from_url(package)
    end

    # Packages MUST follow a certain naming scheme according to the
    # live-build manual
    Dir.glob('config/packages.chroot/*.deb').each do |deb|
      system("dpkg-name #{deb}")
    end
  end

  dci_archive = 'config/archives/dci.list'
  File.delete(dci_archive) if File.exist? dci_archive
  repos.each do |repo|
    logger.info("Adding #{repo} to ISO")
    url = "http://pangea-data.s3.amazonaws.com/dci/#{repo}/debian"
    line = "deb #{url} #{RELEASE} main\n"
    File.write(dci_archive, line, mode: 'a')
  end

  File.write('config/archives/dci.key', REPO_KEY)

  FileUtils.mkdir_p('config/includes.chroot/lib/live/config')
  wtf_random_dir = File.expand_path(File.dirname(File.dirname(__dir__)))
  wtf_random_path = "#{wtf_random_dir}/data/imager/."
  FileUtils.cp_r(wtf_random_path,
                 'config/includes.chroot/lib/live/config')

  system('lb build')

  raise 'Oops! Something went wrong, see the log' unless $?.success?

  files = Dir.glob('live-image*')
  new_files = []

  time = DateTime.now.strftime('%Y%m%d%H%M')
  FileUtils.mkdir_p("/build/#{FLAVOR}")

  arch = `dpkg-architecture -qDEB_BUILD_ARCH`.strip!

  files.each do |f|
    new_name = f.gsub("live-image-#{arch}",
                      "netrunner-debian-#{arch}-#{time}")
    File.rename(f, new_name)
    new_files << new_name
  end

  FileUtils.chown_R('jenkins-slave',
                    'jenkins-slave',
                    "/build/#{FLAVOR}",
                    verbose: true)

  if Dir.glob('*.iso').size > 0
    md5sum = `md5sum *.iso`
    File.write('MD5SUM', md5sum)
    sha256sum = `sha256sum *.iso`
    File.write('SHA256SUM', sha256sum)
    FileUtils.mv(%w(SHA256SUM MD5SUM), "/build/#{FLAVOR}")
  end

  FileUtils.mv(new_files, "/build/#{FLAVOR}")
end
