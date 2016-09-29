#!/usr/bin/expect -f

set timeout 60
set send_human {.05 0.1 1 .07 1.5}
set ssh_alias [lindex $argv 0]
set ssh_account [lindex $argv 1]

if {[llength $argv] != 2} {
    send_user "Usage: connect.sh alias account_uuid\n"
    exit 1
}

set ssh_pass [exec security -i find-generic-password -a $ssh_account -s "org.hejki.osx.sshce" -w]
#log_user 0 # turns off the output to STDOUT (printing the output to the screen)

eval spawn ssh -q -o StrictHostKeyChecking=no -o PubkeyAuthentication=no $ssh_alias

expect {
    timeout {
        send_user "\nFailed to get password prompt\n"
        exit
    }
    eof {
        send_user "\nSSH connection failure for $ssh_alias\n"
        exit
    }
    -re ".*\[pP\]assword:?" {
        sleep 0.1
        send -- $ssh_pass
        send -- "\r"
        sleep 0.3
    }
}

interact
