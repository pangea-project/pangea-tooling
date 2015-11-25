require 'date'
require 'docker'
require 'logger'
require 'logger/colors'

require_relative '../ci/pangeaimage'

module Docker
  module Cleanup
    module_function

    # Remove exited jenkins containers.
    def containers
      containers_exited
      containers_running(days_old: 2)
    end

    def containers_exited
      containers = Docker::Container.all(all: true,
                                         filters: '{"status":["exited"]}')
      containers.each do |container|
        remove_container(container)
      end
    end

    def containers_running(days_old:)
      containers = Docker::Container.all(all: true,
                                         filters: '{"status":["running"]}')
      containers.each do |container|
        container.refresh! # List information is somewhat sparse. Get full data.
        started = container.info.fetch('State').fetch('StartedAt')
        next if (DateTime.now - started).to_i < days_old
        remove_container(container)
      end
    end

    def remove_container(container)
      image = container.info.fetch('Image') { nil }
      unless image
        abort 'While cleaning up containers we found a container that has ' \
              'no image associated with it. This should not happen: ' \
              " #{container}"
      end
      repo, _tag = Docker::Util.parse_repo_tag(image)
      # Remove all our containers and containers from a dangling image.
      # Danglign this case would be any image that isn't tagged.
      unless repo.include?(CI::PangeaImage.namespace)
        begin
          log.warn "Removing container #{container.id}"
          container.kill!
          container.remove
        rescue Docker::Error::DockerError => e
          log.warn 'Removing failed, continuing.'
          log.warn e
        end
      end
    end

    # Remove all dangling images. It doesn't appear to be documented what
    # exactly a dangling image is, but from looking at the image count of both
    # a dangling query and a regular one I am infering that dangling images are
    # images that are none:none AND are not intermediates of another image
    # (whatever an intermediate may be). So, dangling is a subset of all
    # none:none images.
    # @param filter [String] only allow dangling images with this name
    def images(filter: nil)
      # Trust docker to do something worthwhile.
      args = {
        all: true,
        filters: '{"dangling":["true"]}'
      }
      args[:filter] = filter unless filter.nil?
      Docker::Image.all(args).each do |image|
        log.warn "Removing image #{image.id}"
        image.delete
      end
    rescue Docker::Error::ConflictError => e
      log.warn e.to_s
      log.warn 'There was a conflict error, continuing.'

      # NOTE: Manual code implementing agggressive cleanups. Should docker be
      # stupid use this:

      # Docker::Image.all(all: true).each do |image|
      #   tags = image.info.fetch('RepoTags') { nil }
      #   next unless tags
      #   none_tags_only = true
      #   tags.each do |str|
      #     repo, tag = Docker::Util.parse_repo_tag(str)
      #     if repo != '<none>' && tag != '<none>'
      #       none_tags_only = false
      #       break
      #     end
      #   end
      #   next unless none_tags_only # Image used by something.
      #   begin
      #     log.warn "Removing image #{image.id}"
      #     image.delete
      #   rescue Docker::Error::ConflictError
      #     log.warn 'There was a conflict error, continuing.'
      #   rescue Docker::Error::DockerError => e
      #     log.warn 'Removing failed, continuing.'
      #     log.warn e
      #   end
      # end
    end

    def log
      @log ||= Logger.new(STDERR)
    end
  end
end
