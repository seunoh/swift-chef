include_recipe "swift-chef::default"

%w{swift-proxy memcached}.each do |pkg|
  package pkg
end

execute "create auth cert" do
  cwd "/etc/swift"
  creates "/etc/swift/cert.crt"
  user node[:storage][:user]
  group node[:storage][:group]
  command <<-EOH
  /usr/bin/openssl req -new -x509 -nodes -out cert.crt -keyout cert.key -batch &>/dev/null 0</dev/null
  EOH
  not_if { File.exists?("/etc/swift/cert.crt") } 
end


execute "modify memcached" do
  user node[:storage][:user]
  group node[:storage][:group]
  command <<-EOH
  perl -pi -e "s/-l 127.0.0.1/-l #{node[:storage][:proxy][:ip]}/" /etc/memcached.conf
  EOH
  not_if { File.exists?("/etc/memcached.conf") }
end


service "memcached" do
  action :restart
end


template "/etc/swift/proxy-server.conf" do
  source "proxy-server.conf.erb"
  owner node[:storage][:user]
  group node[:storage][:group]
  mode "0755"
end


%w{account container object}.each do |content|
  execute "swift-ring-builder #{content}.builder create 18 1 1" do
    cwd "/etc/swift"
    user node[:storage][:user]
    group node[:storage][:group]
  end
end

node[:storage][:account][:ip].each do |ip|
  execute "swift-ring-builder account.builder add z1-#{ip}:6002/sdb1 100" do
    cwd "/etc/swift"
    user node[:storage][:user]
    group node[:storage][:group]
    only_if { File.exists?("/etc/swift/account.builder") }
  end
end

node[:storage][:container][:ip].each do |ip|
  execute "swift-ring-builder container.builder add z1-#{ip}:6001/sdb1 100" do
    cwd "/etc/swift"
    user node[:storage][:user]
    group node[:storage][:group]
    only_if { File.exists?("/etc/swift/container.builder") }
  end
end

node[:storage][:object][:ip].each do |ip|
  execute "swift-ring-builder object.builder add z1-#{ip}:6000/sdb1 100" do
    cwd "/etc/swift"
    user node[:storage][:user]
    group node[:storage][:group]
    only_if { File.exists?("/etc/swift/object.builder") }
  end
end

%w{account container object}.each do |content|
  execute "swift-ring-builder #{content}.builder" do
    cwd "/etc/swift"
    user node[:storage][:user]
    group node[:storage][:group]
  end 
end

%w{account container object}.each do |content|
  execute "swift-ring-builder #{content}.builder rebalance" do
    cwd "/etc/swift"
    user node[:storage][:user]
    group node[:storage][:group]
    not_if { File.exists? ("/etc/swift/#{content}.ring.gz") }
  end 
end

execute "swift-init proxy start" do
end
