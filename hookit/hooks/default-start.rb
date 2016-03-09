
service 'ssh' do
  action :enable
  init :runit
  only_if { File.exist?('/etc/service/ssh/run') }
end

ensure_socket 'ssh' do
  port '22'
  action :listening
end

service 'db' do
  action :enable
  only_if { File.exist?('/etc/service/db/run') }
end

ensure_socket 'db' do
  port '(4400|5432)'
  action :listening
end
