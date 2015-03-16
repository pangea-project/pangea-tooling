require_relative '../ci-tooling/lib/logger'
require_relative '../ci-tooling/lib/dci'


fail 'Need target and changes file!' unless ARGV.count >= 2
DPUT_CONTENTS = "[dci]
fqdn                    = dci.pangea.pub
method                  = sftp
incoming                = /home/publisher/repos/%(dci)s/incoming
login                   = publisher
"

$logger = DCILogger.instance

ARGV.each do |a|
  next unless a.end_with? '.changes'
  # Make sure changes actually contains files
  next unless File.read(a).include? 'Files'
  dci_run_cmd("echo \"#{DPUT_CONTENTS}\" | dput -uf -c /dev/stdin dci:#{ARGV[1]} #{a}")

end

$logger.close
