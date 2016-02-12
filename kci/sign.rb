#!/usr/bin/env ruby

CHANGES = ARGV[0]

raise 'No changes file/path specified.' unless CHANGES

args = []
args << '--no-re-sign'
args << '-k' << env['KEYID'] if env.key?('KEYID')
args << CHANGES

raise 'Signing the source package failed.' unless system('debsign', *args)
