require_relative '../container'

module CI
  class EphemeralContainer < Container
    def stop(options = {})
      super(options)
      kill!(options)
      rescued_remove
    end

    # def kill!(options = {})
    #   super(options)
    #   rescued_remove
    # end

    private

    def rescued_remove
      # https://github.com/docker/docker/issues/9665
      # Possibly related as well:
      # https://github.com/docker/docker/issues/7636
      # Apparently the AUFS backend is a bit meh and craps out randomly when
      # removing a container. To prevent this from making a build fail two things
      # happen here:
      # 1. sleep 5 seconds before trying to kill. This avoids an apparently also
      #    existing timing issue which might or might not be the root of this.
      # 2. catch server errors from remove and turn them into logable offences
      #    without impact. Since this method is only supposed to be called from
      #    {run} there is no strict requirement for the container to be actually
      #    removed as a subsequent containment instance will attempt to tear it
      #    down anyway. Which might then be fatal, but given the 5 second sleep
      #    and additional time spent doing other things it is unlikely that this
      #    would happen. Should it happen though we still want it to be fatal
      #    though as the assumption is that a containment always is clean which
      #    we couldn't ensure if a previous container can not be removed.
      sleep 5
      remove
      # :nocov:
    rescue Docker::Error::ServerError => e
      # FIXME: no logging in this class
      @log.error e
      # :nocov:
    end
  end
end
