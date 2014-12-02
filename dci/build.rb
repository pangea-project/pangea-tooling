raise "Need a .changes file!" unless ARGV[1].end_with?(".changes")

release = `grep Distribution #{ARGV[1]}`.split(':')[-1].strip

puts "== Building #{ARGV[1]} for #{release} =="

system("sbuild -s --force-orig-source -A --run-lintian -j`nproc` -d #{release} #{ARGV[1]}")
