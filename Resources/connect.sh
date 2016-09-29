#!/usr/bin/expect -f

set timeout 60
set send_human {.05 0.1 1 .07 1.5}
set sshAlias [lindex $argv 0]
set sshAccount [lindex $argv 1]

if {$argc != 2} {
    send_user "Usage: connect.sh alias account_uuid\n"
    exit 1
}

set passexPath "[file dirname $::argv0]/passex"
set sshPass [exec $passexPath $sshAccount]
#log_user 0 # turns off the output to STDOUT (printing the output to the screen)

eval spawn ssh -q -o StrictHostKeyChecking=no -o PubkeyAuthentication=no $sshAlias

expect {
    timeout {
        send_error "\nFailed to get password prompt\n"
        exit
    }
    eof {
        send_error "\nSSH connection failure for $sshAlias\n"
        exit
    }
    -re ".*\[pP\]assword:?" {
        sleep 0.1
        send -- $sshPass
        send -- "\r"
        sleep 0.3
    }
}

interact
