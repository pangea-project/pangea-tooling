require_relative 'xci'
require_relative 'logger'

$logger = DCILogger.instance

def dci_run_cmd(cmd)
  retry_count = 0
  begin
    if retry_count <= 5
      fail unless system(cmd)
    else
      $logger.fatal("#{cmd} keeps failing! :(")
      exit 1
    end
  rescue RuntimeError
    $logger.warn("Trying to run #{cmd} again!")
    retry_count += 1
    sleep(retry_count * 20)
    retry
  end
end

# Debian CI specific data.
module DCI
  extend XCI
end
