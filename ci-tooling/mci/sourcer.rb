#!/usr/bin/env ruby
require_relative '../lib/ci/build_source'
require_relative '../lib/apt'

DIST = ENV.fetch('DIST')

# Packages need a newer pkg-kde-tools which I've put in the mobile.kci archive, jr
Apt::Repository.add("deb http://mobile.kci.pangea.pub #{DIST} main")
Apt::Key.add("#{__dir__}/Pangea CI.gpg.key")
Apt.update
Apt.install(%w(pkg-kde-tools))

builder = CI::VcsSourceBuilder.new(release: DIST)
source = builder.run
# Write out metadata
File.write('build/source.yaml', YAML.dump(source))
