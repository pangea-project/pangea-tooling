require_relative '../ci-tooling/lib/logger'
require_relative '../ci-tooling/lib/dci'

fail 'Need target and changes file!' unless ARGV.count >= 2
fail 'File is not a changes file!' unless ARGV[2].end_with? '.changes'

DPUT_CONTENTS = "[dci]
fqdn                    = dci.pangea.pub
method                  = sftp
incoming                = /home/publisher/%\(dci\)s
login                   = publisher
"

$logger = DCILogger.instance

dci_run_cmd("echo #{DPUT_CONTENTS} | dput -c /dev/stdin dci:#{ARGV[1]} #{ARGV[2]}")

$logger.close
