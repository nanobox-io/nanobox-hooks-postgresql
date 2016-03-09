
execute "dump and upload to backup container" do
  command <<-EOF
    bash -c '/data/bin/pg_dumpall -c -U gonano \
      | gzip \
        | tee >(md5sum | cut -f1 -d" " > /tmp/md5sum) \
          | ssh \
            -o StrictHostKeyChecking=no \
            #{payload[:backup][:local_ip]} \
            "cat > /data/var/db/postgresql/#{payload[:backup][:backup_id]}.gz"
    for i in ${PIPESTATUS[@]}; do
      if [[ $i -ne 0 ]]; then
        exit $i
      fi
    done
    '
  EOF
end

remote_sum = `ssh -o StrictHostKeyChecking=no #{payload[:backup][:local_ip]} "md5sum /data/var/db/postgresql/#{payload[:backup][:backup_id]}.gz"`.to_s.strip.split(' ').first

# Read POST results
local_sum = File.open('/tmp/md5sum') {|f| f.readline}.strip

# Ensure checksum match
if remote_sum != local_sum
  puts 'checksum mismatch'
  exit 1
end
