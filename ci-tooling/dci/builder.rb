#!/usr/bin/env ruby
require 'tmpdir'
require 'fileutils'

require_relative '../lib/ci/build_binary'
require_relative 'lib/setup_repo'

DCI.setup_repo!
Dir.mktmpdir do |tmpdir|
  builder = CI::PackageBuilder.new(tmpdir)
  builder.build
  FileUtils.cp_r("#{tmpdir}/result", Dir.pwd, verbose: true)
end
