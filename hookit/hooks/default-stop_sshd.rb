
service 'ssh' do
  action :disable
  init :runit
  only_if { File.exist?('/etc/service/db/run') }
end

# directory '/etc/service/ssh' do
#   action :delete
# end