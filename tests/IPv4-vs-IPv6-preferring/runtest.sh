#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsync/Sanity/IPv4-vs-IPv6-preferring
#   Description: Test if connection over IPv4 or IPv6 is used
#   Author: Martin Zeleny <mzeleny@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
[ -e /usr/bin/rhts-environment.sh ] && . /usr/bin/rhts-environment.sh
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsync"
port=873
ipv4="0.0.0.0:${port}"
ipv6=":::${port}"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE

        if [ ! -e /etc/rsyncd.conf ]; then
            rsyncdConfCreated=1
            rlRun "touch /etc/rsyncd.conf"
        fi
    rlPhaseEnd

    rlPhaseStartTest "rsync with without IPv4 or IPv6 specification"
        rlRun "rsync --daemon --no-detach &" 0 "Start the rsync daemon"
        rsyncPid=$! # use nodetach and detach for saving the pid

        rlRun -s "netstat -apn | grep ${rsyncPid}/rsync"
        rlAssertGrep ${ipv4} ${rlRun_LOG}
        rlAssertGrep ${ipv6} ${rlRun_LOG}
        rlRun "rm ${rlRun_LOG}"

        rlRun "kill ${rsyncPid}" 0 "Kill rsync daemon"
    rlPhaseEnd
    sleep 1 # get rest for port releasing

    for param in '--ipv4' '-4'; do # equivalent parameters
        rlPhaseStartTest "rsync with ${param} parameter"
            rlRun "rsync --daemon ${param} --no-detach &" 0 "Start the rsync daemon"
            rsyncPid=$! # use nodetach and detach for saving the pid

            rlRun -s "netstat -apn | grep ${rsyncPid}/rsync"
            rlAssertGrep    ${ipv4} ${rlRun_LOG}
            rlAssertNotGrep ${ipv6} ${rlRun_LOG}
            rlRun "rm ${rlRun_LOG}"

            rlRun "kill ${rsyncPid}" 0 "Kill rsync daemon"
        rlPhaseEnd
        sleep 1 # get rest for port releasing
    done

    for param in '--ipv6' '-6'; do # equivalent parameters
        rlPhaseStartTest "rsync with ${param} parameter"
            rlRun "rsync --daemon ${param} --no-detach &" 0 "Start the rsync daemon"
            rsyncPid=$! # use nodetach and detach for saving the pid

            rlRun -s "netstat -apn | grep ${rsyncPid}/rsync"
            rlAssertGrep    ${ipv6} ${rlRun_LOG}
            rlAssertNotGrep ${ipv4} ${rlRun_LOG}
            rlRun "rm ${rlRun_LOG}"

            rlRun "kill ${rsyncPid}" 0 "Kill rsync daemon"
        rlPhaseEnd
        sleep 1 # get rest for port releasing
    done

    rlPhaseStartCleanup
        [ ${rsyncdConfCreated:-0} -eq 1 ] && rlRun "rm /etc/rsyncd.conf"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd

