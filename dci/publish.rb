require 'logger'

raise 'Need target and changes file!' unless ARGV.count >= 2
raise 'File is not a changes file!' unless ARGV[2].end_with? '.changes'

DCI_TARGET = "[dci]
fqdn = dci.pangea.pub
login = publisher
method = sftp
incoming = /home/publisher/reprepro/incoming
run_dinstall = 0
allow_unsigned_uploads = 1
"

$logger = Logger.new(STDOUT)

def run_cmd(cmd)
    retry_count = 0
    begin
        if retry_count <= 5
            raise unless system(cmd)
        else
            $logger.warn("Tried to run #{cmd} but retry count exceeded!")
        end
    rescue RuntimeError
        retry_count += 1
        retry
    end
end

DPUT_CF = ENV['HOME'] + '/.dput.cf'
if !File.exist?(DPUT_CF)
    File.open(DPUT_CF, 'a') { |f|
        f.puts(DCI_TARGET)
    }
end 

run_cmd("dput #{ARGV[1]} #{ARGV[2]}")