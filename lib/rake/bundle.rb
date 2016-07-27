# Bundler can have itself injected in the env preventing bundlers forked from
# ruby to work correctly. This helper helps with running bundlers in a way
# that they do not have a "polluted" environment.
module RakeBundleHelper
  class << self
    def run(*args)
      Bundler.clean_system(*args)
    rescue NameError
      system(*args)
    end
  end
end

def bundle(*args)
  args = ['bundle'] + args
  RakeBundleHelper.run(*args)
  raise "Command failed (#{$?}) #{args}" unless $?.zero?
end
