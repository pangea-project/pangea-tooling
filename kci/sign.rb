#!/usr/bin/env ruby

CHANGES = ARGV[0]

fail 'No changes file/path specified.' unless CHANGES

args = []
args << '--no-re-sign'
args << '-k' << env['KEYID'] if env.key?('KEYID')
args << CHANGES

fail 'Signing the source package failed.' unless system('debsign', *args)
