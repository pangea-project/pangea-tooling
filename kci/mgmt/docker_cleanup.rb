#!/usr/bin/env ruby

require 'docker'
require 'logger'
require 'logger/colors'

def cleanup_dangling_things
  # Remove exited jenkins containers.
  containers = Docker::Container.all(all: true,
                                     filters: '{"status":["exited"]}')
  containers.each do |container|
    image = container.info.fetch('Image') { nil }
    unless image
      abort 'While cleaning up containers we found a container that has no' \
            " image associated with it. This should not happen: #{container}"
    end
    repo, _tag = Docker::Util.parse_repo_tag(image)
    if repo.start_with?('jenkins/')
      begin
        @log.warn "Removing container #{container.id}"
        container.remove
      rescue Docker::Error => e
        @log.warn 'Removing failed, continuing.'
        @log.warn e
      end
    end
  end

  # Remove all dangling images. It doesn't appear to be documented what
  # exactly a dangling image is, but from looking at the image count of both
  # a dangling query and a regular one I am infering that dangling images are
  # images that are none:none AND are not intermediates of another image
  # (whatever an intermediate may be). So, dangling is a subset of all
  # none:none images.
  # To make sure we get rid of everything we are running a dangling remove
  # and hope it does something worthwhile.
  # Docker::Image.all(all: true, filters: '{"dangling":["true"]}').each(&:delete)
  Docker::Image.all(all: true).each do |image|
    tags = image.info.fetch('RepoTags') { nil }
    next unless tags
    none_tags_only = true
    tags.each do |str|
      repo, tag = Docker::Util.parse_repo_tag(str)
      if repo != '<none>' && tag != '<none>'
        none_tags_only = false
        break
      end
    end
    next unless none_tags_only # Image used by something.
    begin
      @log.warn "Removing image #{image.id}"
      image.delete
    rescue Docker::Error::ConflictError
      @log.warn 'There was a conflict error, continuing.'
    rescue Docker::Error => e
      @log.warn 'Removing failed, continuing.'
      @log.warn e
    end
  end
end

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

@log = Logger.new(STDERR)
@log.level = Logger::WARN

cleanup_dangling_things
