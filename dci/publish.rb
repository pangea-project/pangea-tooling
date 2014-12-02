raise "Need a .changes file!" unless ARGV[1].end_with?(".changes")

puts "== Uploading #{ARGV[1]} to Debian CI =="

system("dput dci #{ARGV[1]}")