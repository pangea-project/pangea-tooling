require 'open-uri'
require_relative 'ci-tooling/lib/apt'

RUBY_2_3_1 = '/tmp/2.3.1'

if RbConfig::CONFIG['MAJOR'] < 2 && RbConfig::CONFIG['MINOR'] < 2
  Apt.install(*%w(ruby-build curl))
  File.write(RUBY_2_3_1, open('https://raw.githubusercontent.com/rbenv/ruby-build/master/share/ruby-build/2.3.1').read)
  system("ruby-build #{RUBY_2_3_1} /usr/local")
end

Gem.install('rake') unless Gem::Specification.map(&:name).include? 'rake'
