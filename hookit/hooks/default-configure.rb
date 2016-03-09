
include Hooky::Postgresql

if payload[:platform] == 'local'
  memcap = 128
  user   = 'nanobox'
else
  total_mem = `vmstat -s | grep 'total memory' | awk '{print $1}'`.to_i
  cgroup_mem = `cat /sys/fs/cgroup/memory/memory.limit_in_bytes`.to_i
  memcap = [ total_mem / 1024, cgroup_mem / 1024 / 1024 ].min
end

# Setup
boxfile = converge( BOXFILE_DEFAULTS, payload[:boxfile] )

execute 'generate locale' do
  command "locale-gen #{boxfile[:locale]} && update-locale"
end

directory '/data/var/db/postgresql' do
  recursive true
end

# chown data/var/db/postgresql for gonano
execute 'chown /data/var/db/postgresql' do
  command 'chown -R gonano:gonano /data/var/db/postgresql'
end

directory '/var/log/pgsql' do
  owner 'gonano'
  group 'gonano'
end

file '/var/log/pgsql/pgsql.log' do
  owner 'gonano'
  group 'gonano'
end

execute 'rm -rf /var/pgsql'

execute '/data/bin/initdb -E UTF8 /data/var/db/postgresql' do
  user 'gonano'
  not_if { ::Dir.exists? '/data/var/db/postgresql/base' }
end

users = []
databases = []

if payload[:platform] == 'local'
  users = [
    {
      :username => "nanobox",
      :password => "password",
      :meta => {
        :privileges => [
          {
            :privilege => "ALL PRIVILEGES",
            :on => "DATABASE gonano",
            :with_grant => true
          }
        ],
        :roles => [
          "SUPERUSER"
        ]
      }
    }
  ]
  databases = ['gonano']
else
  users = payload[:users]
  databases = payload[:databases]
end

template '/data/var/db/postgresql/postgresql.conf' do
  mode 0644
  variables ({
    boxfile: boxfile,
    memcap: memcap
  })
  owner 'gonano'
  group 'gonano'
end

template '/data/var/db/postgresql/pg_hba.conf' do
  mode 0600
  owner 'gonano'
  group 'gonano'
  variables ({ users: users, platform: payload[:platform] })
end

# Import service (and start)
directory '/etc/service/db' do
  recursive true
end

directory '/etc/service/db/log' do
  recursive true
end

template '/etc/service/db/log/run' do
  mode 0755
  source 'log-run.erb'
  variables ({ svc: "db" })
end

file '/etc/service/db/run' do
  mode 0755
  content File.read("/opt/gonano/hookit/mod/files/postgresql-run")
end

# Configure narc
template '/opt/gonano/etc/narc.conf' do
  variables ({ uid: payload[:uid], app: "nanobox", logtap: payload[:logtap_host] })
end

directory '/etc/service/narc'

file '/etc/service/narc/run' do
  mode 0755
  content File.read("/opt/gonano/hookit/mod/files/narc-run")
end

# Wait for server to start
until File.exists?( "/tmp/.s.PGSQL.5432" )
   sleep( 1 )
end

# Wait for server to start
ensure_socket 'db' do
  port '(4400|5432)'
  action :listening
end

databases.each do |database|
  execute "create #{database} database" do
    command "/data/bin/psql -U gonano postgres -c 'CREATE DATABASE #{database};'"
    user 'gonano'
    not_if { `/data/bin/psql -U gonano #{database} -c ';' > /dev/null 2>&1`; $?.exitstatus == 0 }
  end
end

users.each do |user|
  execute "create #{user[:username]} user" do
    command "/data/bin/psql -c \"CREATE USER #{user[:username]} ENCRYPTED PASSWORD '#{user[:password]}'\""
    user 'gonano'
    not_if { `/data/bin/psql -U gonano -t -c "SELECT EXISTS(SELECT usename FROM pg_catalog.pg_user WHERE usename='#{user[:username]}');"`.to_s.strip == 't' }
  end
  if user[:meta] and user[:meta][:privileges]
    user[:meta][:privileges].each do |privilege|
      execute "grant #{privilege[:privilege]} to #{user[:username]} user on #{privilege[:on]}" do
        command "/data/bin/psql -c \"GRANT #{privilege[:privilege]} ON #{privilege[:on]} TO #{user[:username]}\""
        user 'gonano'
        not_if { `/data/bin/psql -U gonano -t -c "SELECT * FROM has_database_privilege('#{user[:username]}', 'gonano', 'create');"`.to_s.strip == 't' }
      end
    end
  end
  if user[:meta] and user[:meta][:roles]
    user[:meta][:roles].each do |role|
      execute "escalate #{user[:username]} user to #{role}" do
        command "/data/bin/psql -c 'ALTER USER #{user[:username]} WITH #{role};'"
        user 'gonano'
        not_if { `/data/bin/psql -U gonano -t -c "SELECT rolsuper FROM pg_authid WHERE rolname = 'nanobox';"`.to_s.strip == 't' }
      end
    end
  end
end


# if payload[:platform] == 'local'

#   # Create nanobox user and databases
#   execute 'create gonano db' do
#     command "/data/bin/psql postgres -c 'CREATE DATABASE gonano;'"
#     user 'gonano'
#     not_if { `/data/bin/psql -U gonano gonano -c ';' > /dev/null 2>&1`; $?.exitstatus == 0 }
#   end

#   execute 'create nanobox user' do
#     command "/data/bin/psql -c \"CREATE USER nanobox ENCRYPTED PASSWORD 'password'\""
#     user 'gonano'
#     not_if { `/data/bin/psql -U gonano -t -c "SELECT EXISTS(SELECT usename FROM pg_catalog.pg_user WHERE usename='nanobox');"`.to_s.strip == 't' }
#   end

#   execute 'grant all to nanobox user on gonano' do
#     command "/data/bin/psql -c \"GRANT ALL PRIVILEGES ON DATABASE gonano TO nanobox\""
#     user 'gonano'
#     not_if { `/data/bin/psql -U gonano -t -c "SELECT * FROM has_database_privilege('nanobox', 'gonano', 'create');"`.to_s.strip == 't' }
#   end

#   execute "escalate nanobox user to be a super user" do
#     command "/data/bin/psql -c 'ALTER USER nanobox WITH SUPERUSER;'"
#     user 'gonano'
#     not_if { `/data/bin/psql -U gonano -t -c "SELECT rolsuper FROM pg_authid WHERE rolname = 'nanobox';"`.to_s.strip == 't' }
#   end

# else

#   users = payload[:users]

#   # Create users and databases
#   execute 'create gonano db' do
#     command "/data/bin/psql postgres -c 'CREATE DATABASE gonano;'"
#     user 'gonano'
#     not_if { `/data/bin/psql -U gonano gonano -c ';'`; $?.exitstatus == 0 }
#   end

#   execute 'create default user' do
#     command "/data/bin/psql -c \"CREATE USER #{users[:default][:name]} ENCRYPTED PASSWORD '#{users[:default][:password]}'\""
#     user 'gonano'
#     not_if { `/data/bin/psql -U gonano -t -c "SELECT EXISTS(SELECT usename FROM pg_catalog.pg_user WHERE usename='#{users[:default][:name]}');"`.to_s.strip == 't' }
#   end

#   execute 'grant all to default user on gonano' do
#     command "/data/bin/psql -c \"GRANT ALL PRIVILEGES ON DATABASE gonano TO #{users[:default][:name]}\""
#     user 'gonano'
#     not_if { `/data/bin/psql -U gonano -t -c "SELECT * FROM has_database_privilege('#{users[:default][:name]}', 'gonano', 'create');"`.to_s.strip == 't' }
#   end

# end

boxfile[:extensions].each do |extension|

  execute 'create extension' do
    command "/data/bin/psql -c \"CREATE EXTENSION IF NOT EXISTS \\\"#{extension}\\\"\""
    user 'gonano'
  end

end

if payload[:platform] != 'local'

  # Setup root keys for data migrations
  directory '/root/.ssh' do
    recursive true
  end

  file '/root/.ssh/id_rsa' do
    content payload[:ssh][:admin_key][:private_key]
    mode 0600
  end

  file '/root/.ssh/id_rsa.pub' do
    content payload[:ssh][:admin_key][:public_key]
  end

  file '/root/.ssh/authorized_keys' do
    content payload[:ssh][:admin_key][:public_key]
  end

  # Create some ssh host keys
  execute "ssh-keygen -f /opt/gonano/etc/ssh/ssh_host_rsa_key -N '' -t rsa" do
    not_if { ::File.exists? '/opt/gonano/etc/ssh/ssh_host_rsa_key' }
  end

  execute "ssh-keygen -f /opt/gonano/etc/ssh/ssh_host_dsa_key -N '' -t dsa" do
    not_if { ::File.exists? '/opt/gonano/etc/ssh/ssh_host_dsa_key' }
  end

  execute "ssh-keygen -f /opt/gonano/etc/ssh/ssh_host_ecdsa_key -N '' -t ecdsa" do
    not_if { ::File.exists? '/opt/gonano/etc/ssh/ssh_host_ecdsa_key' }
  end

  execute "ssh-keygen -f /opt/gonano/etc/ssh/ssh_host_ed25519_key -N '' -t ed25519" do
    not_if { ::File.exists? '/opt/gonano/etc/ssh/ssh_host_ed25519_key' }
  end

  # Configure sshd
  directory '/etc/service/ssh' do
    recursive true
  end

  directory '/etc/service/ssh/log' do
    recursive true
  end

  template '/etc/service/ssh/log/run' do
    mode 0755
    source 'log-run.erb'
    variables ({ svc: "ssh" })
  end

  template '/etc/service/ssh/run' do
    mode 0755
    source 'run-root.erb'
    variables ({ exec: "/opt/gonano/sbin/sshd -D -e 2>&1" })
  end

  ensure_socket 'ssh' do
    port '(22)'
    action :listening
  end

end
