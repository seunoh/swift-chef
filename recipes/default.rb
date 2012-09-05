#
# Cookbook Name:: cloudfi
# Recipe:: default
#
# Copyright 2010, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#include_recipe 'apt'


%w{curl gcc git-core memcached python-configobj python-coverage python-dev python-nose python-setuptools python-simplejson python-xattr sqlite3 xfsprogs python-webob python-eventlet python-greenlet python-pastedeploy python-netifaces}.each do |pkg_name|
  package pkg_name
end

directory "/srv" do
    owner node[:cloudfiles][:user] 
    group node[:cloudfiles][:group] 
    mode "0755"
    recursive true
end

execute "build swiftfs" do
  command "dd if=/dev/zero of=/srv/swift-disk bs=1024 count=0 seek=1000000" 
  not_if { File.exists?("/srv/swift-disk") }
end

execute "associate loopback" do
  command "losetup /dev/loop0 /srv/swift-disk" 
  not_if { `losetup /dev/loop0` =~ /swift-disk/ }
end

execute "build filesystem" do
  command "mkfs.xfs -i size=1024 /dev/loop0"
  not_if 'xfs_admin -u /dev/loop0'
end

directory "/mnt/sdb1" do 
    owner node[:cloudfiles][:user] 
    group node[:cloudfiles][:group] 
    mode "0755"
end

execute "update fstab" do
  command "echo '/dev/loop0 /mnt/sdb1 xfs noatime,nodiratime,nobarrier,logbufs=8 0 0' >> /etc/fstab"
  not_if "grep '/dev/loop0' /etc/fstab"
end

execute "mount /mnt/sdb1" do
  not_if "df | grep /dev/loop0"
end

%w{1 2 3 4}.each do |swift_dir|
  directory "/mnt/sdb1/#{swift_dir}" do
    owner node[:cloudfiles][:user] 
    group node[:cloudfiles][:group] 
    mode "0755"
  end

  link "/tmp/#{swift_dir}" do
    to "/mnt/sdb1/#{swift_dir}"
  end

  link "/srv/#{swift_dir}" do
    to "/mnt/sdb1/#{swift_dir}"
  end
end

directory "/etc/swift" do
  owner node[:cloudfiles][:user]
  group node[:cloudfiles][:group]
  mode "0755"
end

%w{1 2 3 4}.each do |swift_dir|
	directory "/srv/#{swift_dir}/node/sdb/#{swift_dir}" do
		owner node[:cloudfiles][:user]
		group node[:cloudfiles][:group]
		mode "0755"
		recursive true
	end
end
	
%w{/etc/swift/object-server /etc/swift/container-server /etc/swift/account-server /var/run/swift}.each do |new_dir|
  directory new_dir do
    owner node[:cloudfiles][:user]
    group node[:cloudfiles][:group]
    recursive true
    mode "0755"
  end
end

template "/etc/rc.local" do
	source "rc.local.erb"
end

template "/etc/rsyncd.conf" do
  source "rsyncd.conf.erb"
end

cookbook_file "/etc/default/rsync" do
  source "default-rsync"
end

service "rsync" do
  action :start
end

template "/etc/rsyslog.d/10-swift.conf" do
	source "10-swift.conf.erb"
end

directory "/var/log/swifti/hourly" do
	owner "#{node[:cloudfiles][:user]}"
	group "#{node[:cloudfiles][:group]}"
	mode "0755"
	recursive true
end

service "rsyslog" do
	action :restart
end

directory "#{node[:cloudfiles][:homedir]}/bin" do
  owner node[:cloudfiles][:user]
  group node[:cloudfiles][:group]
  mode "0755"
end

git "#{node[:cloudfiles][:homedir]}/swift" do
	repository "https://github.com/openstack/swift.git"
	destination "#{node[:cloudfiles][:homedir]}/swift"
end

execute "python setup.py develop" do
  cwd "#{node[:cloudfiles][:homedir]}/swift"
end

git "#{node[:cloudfiles][:homedir]}/python-swiftclient" do
	repository "https://github.com/openstack/python-swiftclient.git"
	destination "#{node[:cloudfiles][:homedir]}/python-swiftclient"
end

execute "python setup.py develop" do
  cwd "#{node[:cloudfiles][:homedir]}/python-swiftclient"
end

ENV["PYTHONPATH"] = "#{node[:cloudfiles][:homedir]}/swift"
ENV["SWIFT_TEST_CONFIG_FILE"] = '/etc/swift/test.conf'
ENV["PATH"] += ":~/bin"

[ 
  'export PYTHONPATH=~/swift',
  'export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf',
  'export PATH=${PATH}:~/bin' 
].each do |bash_bit|
  execute "echo '#{bash_bit}' >> ~/.bashrc; . ~/.bashrc" do
    not_if "grep '#{bash_bit}' ~/.bashrc"
  end
end

template "/etc/swift/auth-server.conf" do
  source "auth-server.conf.erb"
  mode "0644"
  owner node[:cloudfiles][:user]
  group node[:cloudfiles][:group]
end

template "/etc/swift/proxy-server.conf" do
  source "proxy-server.conf.erb"
  mode "0644"
  owner node[:cloudfiles][:user]
  group node[:cloudfiles][:group]
end

template "/etc/swift/swift.conf" do
  source "swift.conf.erb"
  mode "0644"
  owner node[:cloudfiles][:user]
  group node[:cloudfiles][:group]
end

%w{1 2 3 4}.each do |server_num|
  %w{account container object}.each do |server_type|
    template "/etc/swift/#{server_type}-server/#{server_num}.conf" do
      variables({ :server_num => server_num })
      source "#{server_type}-server-conf.erb"
      mode "0644"
      owner node[:cloudfiles][:user]
      group node[:cloudfiles][:group]
    end
  end
end

%w{resetswift remakerings startmain startrest}.each do |bin_file|
  template "#{node[:cloudfiles][:homedir]}/bin/#{bin_file}" do
    source "#{bin_file}.erb"
    owner node[:cloudfiles][:user]
    group node[:cloudfiles][:group]
    mode "0755"
  end
end

template "/etc/swift/test.conf" do
  source "sample.conf.erb"
  owner node[:cloudfiles][:user]
  group node[:cloudfiles][:group]
  mode "0644"
end

execute "remakerings" do
	command "remakerings"
	not_if { File.exists?("~/bin/remakerings") }
end

execute "startmain" do
	command "startmain"
	not_if { File.exists?("~/bin/startmain") }
end

execute "storage and auth token" do
	command "curl -v -H 'X-Storage-User: test:tester' -H 'X-Storage-Pass: testing' http://127.0.0.1:8080/auth/v1.0"
end

execute "test swift" do
	command "swift -A http://127.0.0.1:8080/auth/v1.0 -U test:tester -K testing stat"
end
