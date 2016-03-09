
require 'timeout'

if File.exist?('/data/etc/yoke.ini')
  begin
    Timeout::timeout(90) do
      execute 'demote secondary' do
        command <<-EOF
          yokeadm demote -h $(yokeadm list | grep secondary | awk '{print $3}' | tr -d '\n')
          sleep 5
          yokeadm list | grep secondary | grep -v master | grep running > /dev/null
          while [ $? -ne 0 ]; do
            sleep 5
            echo 'waited'
            yokeadm list | grep secondary | grep -v master | grep running > /dev/null
          done
          sed -i 's/5432/5433/g' /data/etc/yoke.ini
        EOF
      end
    end
  rescue Timeout::Error
    puts 'failed to demote secondary'
    exit 1
  end
else
  execute 'ensure no db connections' do
    command <<-EOF
      sed -i 's/5432/5433/g' /data/var/db/postgresql/postgresql.conf
    EOF
  end
end

service 'db' do
  action :disable
  init :runit
end

service 'db' do
  action :enable
  only_if { File.exist?('/etc/service/db/run') }
end

ensure_socket 'db' do
  port '(4400|5433)'
  action :listening
end

begin
  Timeout::timeout(90) do
    execute 'try connect' do
      command <<-EOF
        bash -c 'while [ $(echo "show databases;" | /data/bin/psql -U gonano -p 5433 postgres 2>&1) = "psql: FATAL:  the database system is starting up" ]
        do
          sleep 5
        done'
      EOF
    end
  end
rescue Timeout::Error
    puts 'failed to connect to PostgreSQL'
    exit 1
end

# pipe the backup into postgres client to restore from backup
execute 'restore from backup' do
  command <<-EOF
    bash -c 'ssh -o StrictHostKeyChecking=no #{payload[:backup][:local_ip]} \
    "cat /data/var/db/postgresql/#{payload[:backup][:backup_id]}.gz" \
        | gunzip \
          | /data/bin/psql \
              -U gonano -p 5433 postgres
    for i in ${PIPESTATUS[@]}; do
      if [ $i -ne 0 ]; then
        exit $i
      fi
    done
    '
  EOF
end

if File.exist?('/data/etc/yoke.ini')
  execute 'allow db connections via yoke' do
    command <<-EOF
      sed -i 's/5433/5432/g' /data/etc/yoke.ini
    EOF
  end
else
  execute 'allow db connections' do
    # reset port, stop database causing a restart
    command <<-EOF
      sed -i 's/5433/5432/g' /data/var/db/postgresql/postgresql.conf
    EOF
  end
end

service 'db' do
  action :disable
  init :runit
end

service 'db' do
  action :enable
  only_if { File.exist?('/etc/service/db/run') }
end

ensure_socket 'db' do
  port '(4400|5432)'
  action :listening
end

begin
  Timeout::timeout(90) do
    execute 'try connect' do
      command <<-EOF
        bash -c 'while [ $(echo "show databases;" | /data/bin/psql -U gonano -p 5432 postgres 2>&1) = "psql: FATAL:  the database system is starting up" ]
        do
          sleep 5
        done'
      EOF
    end
  end
rescue Timeout::Error
    puts 'failed to connect to PostgreSQL'
    exit 1
end
