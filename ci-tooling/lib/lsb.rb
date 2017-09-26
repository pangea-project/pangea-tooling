# frozen_string_literal: true
require 'shellwords'

# Wrapper around lsb-release. Makes values available as non-introspectable
# constants. For runtime introspection to_h should be used instead.
module LSB
  @file = '/etc/lsb-release'

  def self.const_missing(name)
    return to_h[name] if to_h.key?(name)
    super(name)
  end

  module_function

  def to_h
    @hash ||= LSB.parse(File.read(@file).split($/))
  end

  def reset
    remove_instance_variable(:@hash) if defined?(@hash)
  end

  def self.parse(lines)
    hash = {}
    lines.each do |line|
      line.strip!
      key, value = line.split('=')
      value = Shellwords.split(value)
      value = value[0] if value.size == 1
      hash[key.to_sym] = value
    end
    hash
  end
end
