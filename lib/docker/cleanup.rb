require 'date'
require 'docker'
require 'logger'
require 'logger/colors'

require_relative '../ci/pangeaimage'

module Docker
  # helper for docker cleanup according to pangea expectations
  module Cleanup
    module_function

    # Remove exited jenkins containers.
    def containers
      containers_exited(days_old: 1)
      containers_running(days_old: 1)
    end

    def containers_exited(days_old:)
      # Filter all pseudo-exited and exited states.
      filters = { status: %w(exited dead) }
      containers = Docker::Container.all(all: true,
                                         filters: JSON.generate(filters))
      containers.each do |container|
        created = container_creation(container)
        force = ((DateTime.now - created).to_i > days_old)
        remove_container(container, force: force)
      end
    end

    def container_creation(container)
      object_creation(container)
    end

    def object_creation(obj)
      obj.refresh! # List information is somewhat sparse. Get full data.
      created_prop = obj.info.fetch('Created')
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
      puts "-- REMOVE_CONTAINER --"
      p container
      # Get the live data. Docker in various versions spits out convenience
      # data in the listing .refresh! uses, .json is the raw dump.
      # Using the raw dump we can then translate to either an image name or
      # hash.
      container_json = container.json
      # API 1.21 introduced a new property
      image_id = container_json.fetch('ImageID') { nil }
      # Before 1.21 Image was the hot stuff.
      image_id = container_json.fetch('Image') { nil } unless image_id
      begin
        image = Docker::Image.get(image_id)
      rescue Docker::Error::NotFoundError
        puts "Coulnd't find image."
        image = nil
      end
      if image
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
      else
        log.warn 'While cleaning up containers we found a container that has ' \
                 'no image associated with it. This should not happen: ' \
                 " #{container}"

      end
      begin
        log.warn "Removing container #{container.id}"
        container.kill!
        container.remove
      rescue Docker::Error::DockerError => e
        log.warn 'Removing failed, continuing.'
        log.warn e
      end
    end

    def old_images
      %w(pangea/ubuntu:wily ubuntu:wily).each do |name|
        begin
          remove_image(Docker::Image.get(name))
        rescue => e
          log.info "Failed to get #{name} :: #{e}"
          next
        end
      end
    end

    def image_broken?(image)
      tags = image.info.fetch('RepoTags', [])
      return false unless tags.any? { |x| x.start_with?('pangea/') }
      created = object_creation(image)
      # rubocop:disable Style/NumericLiterals
      return false if Time.at(1470048138).to_datetime < created.to_datetime
      # rubocop:enable Style/NumericLiterals
      true
    end

    def broken_images
      Docker::Image.all(all: true).each do |image|
        begin
          remove_image(image) if image_broken?(image)
        rescue => e
          log.info "Failed to get #{name} :: #{e}"
          next
        end
      end
    end

    def remove_image(image)
      log.warn "Removing image #{image.id}"
      image.delete
    rescue Docker::Error::ConflictError => e
      log.warn e.to_s
      log.warn 'There was a conflict error, continuing.'
    end

    # Remove all dangling images. It doesn't appear to be documented what
    # exactly a dangling image is, but from looking at the image count of both
    # a dangling query and a regular one I am infering that dangling images are
    # images that are none:none AND are not intermediates of another image
    # (whatever an intermediate may be). So, dangling is a subset of all
    # none:none images.
    # @param filter [String] only allow dangling images with this name
    def images(filter: nil)
      old_images
      broken_images
      # Trust docker to do something worthwhile.
      args = {
        all: true,
        filters: '{"dangling":["true"]}'
      }
      args[:filter] = filter unless filter.nil?
      Docker::Image.all(args).each do |image|
        remove_image(image)
      end
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
