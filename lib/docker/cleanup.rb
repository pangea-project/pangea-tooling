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
      # Filter all pseudo-exited and exited states.
      filters = { status: %w(exited dead) }
      containers = Docker::Container.all(all: true,
                                         filters: JSON.generate(filters))
      containers.each do |container|
        remove_container(container)
      end
    end

    def container_creation(container)
      container.refresh! # List information is somewhat sparse. Get full data.
      created_prop = container.info.fetch('Created')
      created = if created_prop.is_a?(Numeric)
                  Time.at(created_prop)
                else
                  DateTime.parse(created_prop)
                end
      created.to_datetime
    end

    def containers_running(days_old:)
      # Filter all pseudo-running and running states.
      filters = { status: %w(created restarting running paused) }
      containers = Docker::Container.all(all: true,
                                         filters: JSON.generate(filters))
      containers.each do |container|
        created = container_creation(container)
        next if (DateTime.now - created).to_i < days_old
        remove_container(container, force: true)
      end
    end

    def remove_container(container, force: false)
      # Get the live data. Docker in various versions spits out convenience
      # data in the listing .refresh! uses, .json is the raw dump.
      # Using the raw dump we can then translate to either an image name or
      # hash.
      container_json = container.json
      # API 1.21 introduced a new property
      image_id = container_json.fetch('ImageID') { nil }
      # Before 1.21 Image was the hot stuff.
      image_id = container_json.fetch('Image') { nil } unless image_id
      image = Docker::Image.get(image_id)
      unless image
        abort 'While cleaning up containers we found a container that has ' \
              'no image associated with it. This should not happen: ' \
              " #{container}"
      end
      image.refresh! # Make sure we have live data and RepoTags available.
      repo_tags = image.info.fetch('RepoTags') { [] }
      # We only care about first possible tag.
      repo, _tag = Docker::Util.parse_repo_tag(repo_tags.first || '')
      # <shadeslayer> well, it'll be fixed as soon as Debian unstable gets
      #   fixed?
      # Also see mgmt/docker.rb
      force = true if repo == 'pangea/debian'
      # Remove all our containers and containers from a dangling image.
      # Dangling in this case would be any image that isn't tagged.
      return unless force || !repo.include?(CI::PangeaImage.namespace)
      begin
        log.warn "Removing container #{container.id}"
        container.kill!
        container.remove
      rescue Docker::Error::DockerError => e
        log.warn 'Removing failed, continuing.'
        log.warn e
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
