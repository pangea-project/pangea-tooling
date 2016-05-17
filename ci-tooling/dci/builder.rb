#!/usr/bin/env ruby
require 'tmpdir'
require 'fileutils'

require_relative '../lib/ci/build_binary'
require_relative 'lib/setup_repo'

DCI.setup_repo!
@workspace = Dir.pwd
Dir.mktmpdir do |tmpdir|
  FileUtils.cp_r("#{@workspace}/.", tmpdir, verbose: true)
  Dir.chdir(tmpdir) do
    builder = CI::PackageBuilder.new
    builder.build
  end
  FileUtils.cp_r("#{tmpdir}/result", @workspace, verbose: true)
end
