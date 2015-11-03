require 'test/unit'
require_relative '../lib/shebang'

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
end
