#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2016 Jonathan Riddell <jr@jriddell.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'fileutils'

require_relative '../lib/ci/containment'

TOOLING_PATH = File.dirname(__dir__)

JOB_NAME = ENV.fetch('JOB_NAME')
DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
ARCH = ENV.fetch('ARCH')
METAPACKAGE = ENV.fetch('METAPACKAGE')
IMAGENAME = ENV.fetch('IMAGENAME')
NEONARCHIVE = ENV.fetch('NEONARCHIVE')

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

binds = [
  TOOLING_PATH,
  Dir.pwd
]

c = CI::Containment.new(JOB_NAME,
                        image: CI::PangeaImage.new(:ubuntu, DIST),
                        binds: binds,
                        privileged: true,
                        no_exit_handlers: false)
cmd = ["#{TOOLING_PATH}/nci/imager/build.sh",
       Dir.pwd, DIST, ARCH, TYPE, METAPACKAGE, IMAGENAME, NEONARCHIVE]
status_code = c.run(Cmd: cmd)
exit status_code unless status_code == 0

DATE = File.read('result/date_stamp').strip
WEBSITE_PATH = "/var/www/images/#{IMAGENAME}-#{TYPE}-proposed/".freeze
PUB_PATH = "#{WEBSITE_PATH}#{DATE}".freeze
FileUtils.mkpath(PUB_PATH)
%w(iso manifest zsync sha256sum tar.xz).each do |type|
  unless system("cp -r --no-preserve=ownership result/*.#{type} #{PUB_PATH}/")
    abort "File type #{type} failed to copy to public directory."
  end
end
FileUtils.rm("#{WEBSITE_PATH}current", force: true)
FileUtils.ln_s(PUB_PATH, "#{WEBSITE_PATH}current")

# copy to depot using same directory without -proposed for now, later we want this to
# only be published if passing some QA test
WEBSITE_PATH_REMOTE = "#{IMAGENAME}-#{TYPE}/".freeze
PUB_PATH_REMOTE = "#{WEBSITE_PATH_REMOTE}#{DATE}".freeze
system("ssh neon@depot.kde.org mkdir -p neon/#{PUB_PATH_REMOTE}")
%w(amd64.iso manifest zsync sha256sum).each do |type|
  unless system("scp result/*#{type} neon@depot.kde.org:neon/#{PUB_PATH_REMOTE}/")
    abort "File type #{type} failed to scp to depot.kde.org."
  end
end
system("ssh neon@depot.kde.org cd neon/#{PUB_PATH_REMOTE}; ln -s *amd64.iso #{IMAGENAME}-#{TYPE}-current.iso")
system("ssh neon@depot.kde.org cd neon/; rm -f current; ln -s #{PUB_PATH_REMOTE} current")

exit 0
