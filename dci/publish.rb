require_relative '../ci-tooling/lib/logger'
require_relative '../ci-tooling/lib/dci'

fail 'Need target and changes file!' unless ARGV.count >= 2
fail 'File is not a changes file!' unless ARGV[2].end_with? '.changes'

DPUT_CONTENTS = "[plasma]
fqdn = dci.pangea.pub
login = publisher
method = sftp
incoming = /home/publisher/kde/incoming
run_dinstall = 0
allow_unsigned_uploads = 1

[maui]
fqdn = dci.pangea.pub
login = publisher
method = sftp
incoming = /home/publisher/maui/incoming
run_dinstall = 0
allow_unsigned_uploads = 1

[moz-plasma]
fqdn = dci.pangea.pub
login = publisher
method = sftp
incoming = /home/publisher/moz/incoming
run_dinstall = 0
allow_unsigned_uploads = 1
"

$logger = DCILogger.instance

DPUT_CF = ENV['HOME'] + '/.dput.cf'
if File.read(DPUT_CF) != DPUT_CONTENTS
    File.open(DPUT_CF, 'w+') { |f|
        f.flock(File::LOCK_EX)
        f.puts(DPUT_CONTENTS)
        f.flush()
        f.flock(File::LOCK_UN)
    }
end

dci_run_cmd("dput #{ARGV[1]} #{ARGV[2]}")

$logger.close
