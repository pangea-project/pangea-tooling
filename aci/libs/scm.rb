require_relative 'metadata'
require 'fileutils'
require 'rugged'

# Module for source control
module SCM
  def self.git_clone_source(args = {})
    repo = Rugged::Repository.new
    url = args[:url]
    branch = args[:branch]
    dir = args[:dir]
    repo.clone_at(url, dir, checkout_branch: branch)
  end
end
