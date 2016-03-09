
payload[:generation][:members].each do |member|

  if member[:type] == 'default'

    execute "send bulk data to new member" do
      command "tar -cf - /data/var/db/postgresql | ssh -o StrictHostKeyChecking=no #{member[:local_ip]} tar -xpf -"
    end

  end
end
