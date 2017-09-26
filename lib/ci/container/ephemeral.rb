# frozen_string_literal: true
require_relative '../container'

module CI
  # An ephemeral container. It gets automatically removed after it closes.
  # This is slightly more reliable than Docker's own implementation as
  # this goes to extra lengths to make sure the container disappears.
  class EphemeralContainer < Container
    class EphemeralContainerUnhandledState < StandardError; end

    @safety_sleep = 5
    RUNNING_STATES = %w[created exited running].freeze

    class << self
      # @!attribute rw safety_sleep
      #    How long to sleep before attempting to kill a container. This is
      #    to prevent docker consistency issues at unmounting. The longer the
      #    sleep the more reliable.
      attr_accessor :safety_sleep
    end

    def stop(options = {})
      super(options)
      # TODO: this should really be kill not kill!, but changing it would
      #   require re-recording a lot of tests.
      kill!(options) if running?
      rescued_remove
    end

    def running?
      state = json.fetch('State')
      unless RUNNING_STATES.include?(state.fetch('Status'))
        raise EphemeralContainerUnhandledState
      end
      state.fetch('Running')
    end

    private

    def rescued_remove
      # https://github.com/docker/docker/issues/9665
      # Possibly related as well:
      # https://github.com/docker/docker/issues/7636
      # Apparently the AUFS backend is a bit meh and craps out randomly when
      # removing a container. To prevent this from making a build fail two
      # things happen here:
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
      sleep self.class.safety_sleep
      remove
      # :nocov:
    rescue Docker::Error::ServerError => e
      # FIXME: no logging in this class
      @log.error e
      # :nocov:
    end
  end
end
