#!/usr/bin/expect -f

set timeout 60
set send_human {.05 0.1 1 .07 1.5}
set sshAlias [lindex $argv 0]
set sshAccount [lindex $argv 1]

if {$argc != 2} {
    send_user "Usage: connect.sh host account_uuid\n"
    exit 1
}

set sshPass [exec security -i find-generic-password -a $sshAccount -s "org.hejki.osx.sshce.connector" -w]

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
