default[:storage][:user] = "root"
default[:storage][:group] = "root"
default[:storage][:homedir] = "/root"
default[:storage][:mount_path] = "/srv/noda"
default[:storage][:mounted_drives] = "7"



default[:storage][:proxy][:ip] = "192.168.1.111"

default[:storage][:account][:ip] = [
  "192.168.1.112",
  "192.168.1.113",
]

default[:storage][:container][:ip] = [
  "192.168.1.114",
  "192.168.1.115",
]

default[:storage][:object][:ip] = [
  "192.168.1.116",
  "192.168.1.117",
  "192.168.1.118",
  "192.168.1.119",
]
