# frozen_string_literal: true

# Docker module.
module Docker
  # Monkey patch to support forced disconnect.
  class Network
    def disconnect(container, opts = {}, force: false)
      body = MultiJson.dump({ container: container }.merge(force: force))
      Docker::Util.parse_json(
        connection.post(path_for('disconnect'), opts, body: body)
      )
      reload
    end
  end
end
