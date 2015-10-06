require 'test/unit'

class Shebang
  attr_reader :valid
  attr_reader :parser

  def initialize(line)
    @valid = false
    @parser = nil

    return unless line
    return unless line.start_with?('#!')

    parts = line.split(' ')

    return unless parts.size >= 1
    if parts[0].end_with?('/env')
      return unless parts.size >= 2
      @parser = parts[1]
    elsif !parts[0].include?('/') || parts[0].end_with?('/')
      return # invalid
    else
      @parser = parts[0].split('/').pop
    end

    @valid = true
  end
end

class ParseTest < Test::Unit::TestCase
  def test_shebang
    s = Shebang.new(nil)
    assert(!s.valid)

    s = Shebang.new('')
    assert(!s.valid)

    s = Shebang.new('#!')
    assert(!s.valid)

    s = Shebang.new('#!/usr/bin/env ruby')
    assert(s.valid)
    assert_equal('ruby', s.parser)

    s = Shebang.new('#!/usr/bin/bash')
    assert(s.valid)
    assert_equal('bash', s.parser)

    s = Shebang.new('#!/bin/sh -xe')
    assert(s.valid)
    assert_equal('sh', s.parser)
  end

  def test_syntax
    basedir = File.dirname(File.expand_path(File.dirname(__FILE__)))
    Dir.chdir(basedir)

    source_dirs = %w(
      dci
      kci
      lib
      test
      ci-tooling/kci
      ci-tooling/dci
      ci-tooling/lib
      ci-tooling/test
    )
    source_dirs.each do |source_dir|
      Dir.glob("#{source_dir}/**/*.rb").each do |file|
        parse_ruby(file)
      end
      Dir.glob("#{source_dir}/**/*.sh").each do |file|
        parse_shell(file)
      end
    end

    # Do not recurse the main dir.
    Dir.glob('*.rb').each do |file|
      parse_ruby(file)
    end
    Dir.glob('*.sh').each do |file|
      parse_shell(file)
    end
  end

  private

  def parse_bash(file)
    assert(system("bash -n #{file}"), "#{file} not parsing as bash.")
  end

  def parse_ruby(file)
    assert(system("ruby -c #{file} 1> /dev/null"),
           "#{file} not parsing as ruby.")
  end

  def parse_sh(file)
    assert(system("sh -n #{file}"), "#{file} not parsing as sh.")
  end

  def parse_shell(file)
    shebang = Shebang.new(File.open(file).readline)
    case shebang.parser
    when 'bash'
      parse_bash(file)
    when 'sh'
      parse_sh(file)
    else
      if shebang.valid
        warn '  shell type unknown, falling back to bash'
      else
        warn '  shebang invalid, falling back to bash'
      end
      parse_bash(file)
    end
  end
end
