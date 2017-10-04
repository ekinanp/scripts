#!/usr/bin/expect -f

set usage "Usage: $argv0 <vm-host>"

set vm_host [lindex $argv 0]

if {$vm_host eq ""} {
  puts "ERROR: vm host not specified!"
  puts $usage
  exit 1
}

spawn ssh ${vm_host}
expect "# "
send "puppet-access login -lifetime 1y\r"
expect "sername: "
send "admin\r"
expect "assword: "
send "puppetlabs\r"
expect "saved to: .*"
expect "# "
send "exit\r"
