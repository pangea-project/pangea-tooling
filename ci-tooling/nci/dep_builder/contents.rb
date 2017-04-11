# require 'tokyocabinet'
# require 'open-uri'
#
#
# module Debian
#   class Contents
#     include TokyoCabinet
#
#     class Package
#       # Pocket a thing is in (deprecated, but still used)
#       attr_reader :area
#       # Section a thing is in (e.g. admin, x11 etc.)
#       attr_reader :section
#       # Package name
#       attr_reader :name
#
#       def initialize(str)
#         parts = str.split('/')
#         @name = parts.pop
#         @section = parts.pop
#         @area = parts.pop
#       end
#     end
#
#     def initialize(path)
#       @db = @file_to_pkgs = HDB.new
#       p =stat File.stat
#       open('http://archive.ubuntu.com/ubuntu/dists/xenial/Contents-amd64.gz',
#            'If-Modified-Since')
#       unless @db.open('casket.tch', HDB::OWRITER | HDB::OCREAT)
#         ecode = @db.ecode
#         STDERR.printf("open error: %s\n", @db.errmsg(ecode))
#       end
#       # @file_to_pkgs = {}
#       read(path)
#     end
#
#     def
#
#     # FIXME: shuld just use regex or pattern
#     def find_end_with(path)
#       @file_to_pkgs.iterinit
#       while key = @file_to_pkgs.iternext
#         return @file_to_pkgs.get(key) if key.end_with?(path)
#       end
#       nil
#     end
#
#     private
#
#     def filter?(line)
#       # Can contain boilerplate. Rip out everything before FILE line.
#       @found_start ||= line.start_with?('FILE') && line.include?('LOCATION')
#       return true unless @found_start
#       false
#     end
#
#     def parse(line)
#       matchdata = line.match(/(?<file>[^\s]+)\s+?(?<location>[^\s]+)/i)
#       return unless matchdata
#       # packages = matchdata[:location].split(',').collect do |x|
#       #   Package.new(x)
#       # end
#       unless @file_to_pkgs.put(matchdata[:file], matchdata[:location])
#         raise
#       end
#       # @file_to_pkgs[matchdata[:file]] = packages
#     end
#
#     def read(path)
#       File.open(path, 'rb') do |file|
#         file.each_line do |line|
#           next if filter?(line)
#           parse(line)
#         end
#       end
#       @db.sync
#     end
#   end
# end
#
# if __FILE__ == $PROGRAM_NAME
#   c = Debian::Contents.new("#{Dir.pwd}/meta-dep/apt-file-cache/archive.ubuntu.com_ubuntu_dists_xenial_Contents-amd64")
#   puts "loaded"
#   p c.find_end_with('FindSharedMimeInfo.cmake')
# end
