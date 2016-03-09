
service 'db' do
  action :disable
  init :runit
  only_if { File.exist?('/etc/service/db/run') }
end

service 'ssh' do
  action :disable
  init :runit
  only_if { File.exist?('/etc/service/ssh/run') }
end

