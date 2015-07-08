#!/usr/bin/env ruby
require 'yaml'

require_relative '../ci-tooling/lib/ci/build_source'

RELEASE = ENV.fetch('RELEASE')

s = VcsSourceBuilder.new(series: RELEASE)
r = s.run
# Write out metadata
open('build/source.yaml', 'w+') { |f| f.write(YAML.dump(r)) }
