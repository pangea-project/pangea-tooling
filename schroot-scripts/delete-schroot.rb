#!/usr/bin/ruby

if ARGV[0].nil? or ARGV[1] == ""
    puts "Usage:"
    puts "  ./delete-schroot.sh SCHROOTNAME"
    exit 1
end

name = ARGV[0]
location = `schroot --exclude-aliases --location -c #{name}`
if $? != 0
    puts "schroot '#{name}' does not appear to exist...."
    exit 1
end

require 'fileutils'
FileUtils::rm_rf("/etc/schroot/chroot.d/#{name}.conf")
FileUtils::rm_rf(location)
