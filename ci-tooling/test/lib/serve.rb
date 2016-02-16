require 'webrick'

module Test
  @children = []

  def self.http_serve(dir, port: '9473')
    case pid = fork
    when nil # child
      log = WEBrick::Log.new(nil, WEBrick::BasicLog::FATAL)
      s = WEBrick::HTTPServer.new(DocumentRoot: dir,
                                  Port: port,
                                  AccessLog: [],
                                  Logger: log)
      s.start
      exit(0)
    else # parent
      @children << pid
      at_exit { nuke } # Make sure the child dies even on raised error exits.
      yield
    end
  ensure
    if pid
      kill(pid)
      @children.delete(pid)
    end
  end

  def self.kill(pid)
    Process.kill('KILL', pid)
    Process.waitpid(pid)
  end

  def self.nuke
    @children.each do |pid|
      kill(pid)
    end
  end
end
