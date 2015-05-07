require 'drb/drb'

# DRB Git Service Wrapper.
module Service
  SERVER_URI = 'druby://localhost:991235'

  # @return DrbObject pointing to {Semaphore}
  def self.start
    DRb.start_service
    DRbObject.new_with_uri(SERVER_URI)
  end
end
