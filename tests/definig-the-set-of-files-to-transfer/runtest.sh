#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsync/Sanity/definig-the-set-of-files-to-transfer
#   Description: Tests the options which modifie the list of files to be transfered
#   Author: Michal Trunecka <mtruneck@redhat.com>
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsync"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE

        rlFileBackup --clean /etc/rsyncd.conf
        START_DATE_TIME=`date "+%m/%d/%Y %T"`

        REMOTE="/tmp/remote"
        LOCAL="/tmp/local"
        LOCAL_2="/root/another_local"
        TMP_FILE=`mktemp`
        TMP_FILE_2=`mktemp`
        SERVER_LOG_FILE=`mktemp`
        rlRun "chcon -t rsync_log_t $SERVER_LOG_FILE"
        LOG_FILE=`mktemp`
        rlRun "chcon -t rsync_log_t $LOG_FILE"

        rlRun "mkdir $REMOTE"
        rlRun "chcon -t rsync_tmp_t $REMOTE"
        rlRun "mkdir $LOCAL"
        rlRun "chcon -t rsync_tmp_t $LOCAL"

        rlRun "dd if=/dev/zero of=${LOCAL}/bigfile bs=1000 count=20000"
        rlRun "dd if=/dev/zero of=${LOCAL}/smallfile bs=1000 count=2"
        rlRun "echo 'First file' > ${LOCAL}/first"
        rlRun "echo 'Second file' > ${LOCAL}/second"
        rlRun "echo 'Third file' > ${LOCAL}/third"
        if ! rlIsRHEL 5 6; then
            if ! ls /usr/lib/systemd/system/rsyncd@.service
            then
                WORKAROUNDED=true
                rlFail "The /usr/lib/systemd/system/rsyncd@.service file is missing (bz#1082496), will be workarounded for now"
                rlRun "cp rsyncd@.service /usr/lib/systemd/system/"
            else
                rlPass "The bz#1082496 is probably fixed, no workaround needed."
            fi
        fi

        rlRun "cat > /etc/rsyncd.conf <<EOF
pid file = /var/run/rsyncd.pid
log file = $SERVER_LOG_FILE

[remote]
    path = $REMOTE
    hosts allow = 127.0.0.1, ::1
    read only = no
    uid = root
    gid = root
EOF"
	if rlIsRHEL 5 6; then
          rlRun "chkconfig rsync on"
          rlServiceStart xinetd
	else 
	  systemctl status rsyncd.socket && STOPPED=false || STOPPED=true
	  rlServiceStop rsyncd
	  rlRun "systemctl restart rsyncd.socket"
	fi
 
    rlPhaseEnd

    rlPhaseStartTest "-c --checksum"

#       -c, --checksum
#              This  changes the way rsync checks if the files have been changed and are in
#              need of a transfer.  Without this option, rsync uses a  “quick  check”  that
#              (by  default) checks if each file’s size and time of last modification match
#              between the sender and receiver.  This option  changes  this  to  compare  a
#              128-bit  checksum  for  each  file that has a matching size.  Generating the
#              checksums means that both sides will expend a lot of disk  I/O  reading  all
#              the data in the files in the transfer (and this is prior to any reading that
#              will be done to transfer changed files), so this can slow things  down  sig-
#              nificantly.
#
#              The  sending  side generates its checksums while it is doing the file-system
#              scan that builds the list of the available files.   The  receiver  generates
#              its  checksums  when it is scanning for changed files, and will checksum any
#              file that has the same size as the corresponding sender’s file:  files  with
#              either a changed size or a changed checksum are selected for transfer.
#
        rlRun "rsync -av -i ${LOCAL}/first localhost::remote | grep first"
        rlRun "rsync -av -i ${LOCAL}/first localhost::remote | grep first" 1
        rlRun "MODIF_DATE=\"`date -r ${REMOTE}/first`\""
        # Modified content, but preserved the size
        rlRun "echo 'first file' > ${REMOTE}/first"
        # set the same dates to both local and remote file
        rlRun "touch -d \"$MODIF_DATE\" ${REMOTE}/first"
        rlRun "touch -d \"$MODIF_DATE\" ${LOCAL}/first"
        rlRun "rsync -av -i ${LOCAL}/first localhost::remote | grep first" 1
        rlRun "rsync -av -i -c ${LOCAL}/first localhost::remote | grep first"

    rlPhaseEnd

    rlPhaseStartTest "--ignore-existing"

#       --ignore-existing
#              This  tells  rsync to skip updating files that already exist on the destina-
#              tion (this does not ignore existing directories, or nothing would get done).
#              See also --existing.
#
#              This  option  is  a  transfer rule, not an exclude, so it doesn’t affect the
#              data that goes into the file-lists, and thus it  doesn’t  affect  deletions.
#              It just limits the files that the receiver requests to be transferred.
#
#              This  option  can  be  useful  for those doing backups using the --link-dest
#              option when they need to continue a backup run that got interrupted.   Since
#              a  --link-dest run is copied into a new directory hierarchy (when it is used
#              properly), using --ignore existing  will  ensure  that  the  already-handled
#              files  don’t  get tweaked (which avoids a change in permissions on the hard-
#              linked files).  This does mean that this  option  is  only  looking  at  the
#              existing files in the destination hierarchy itself.

        rlRun "echo 'lorem ipsum' > ${REMOTE}/first"
        rlRun "echo 'dolor sit amet' > ${REMOTE}/second"
        rlRun "echo 'consectetur adipiscing elit' > ${REMOTE}/third"
        rlRun "echo 'lorem ipsum' > ${REMOTE}/smallfile"
        rlRun "echo 'dolor sit amet' > ${REMOTE}/bigfile"

        rlRun "rsync -avv -i -c --ignore-existing ${LOCAL}/ localhost::remote | egrep 'first|second|third|smallfile|bigfile'" 1
        rlRun "rsync -avv -i --size-only --ignore-existing ${LOCAL}/ localhost::remote | egrep 'first|second|third|smallfile|bigfile'" 1
        rlRun "rsync -avv -i -I --ignore-existing ${LOCAL}/ localhost::remote | egrep 'first|second|third|smallfile|bigfile'" 1
        rlRun "rsync -avv -i ${LOCAL}/ localhost::remote | egrep 'first|second|third|smallfile|bigfile'"

        rlRun "rm -rf ${REMOTE}/*"

    rlPhaseEnd

    rlPhaseStartTest "--max-size --min-size"

#       --max-size=SIZE
#              This tells rsync to avoid transferring any file  that  is  larger  than  the
#              specified  SIZE.  The SIZE value can be suffixed with a string to indicate a
#              size multiplier, and may be a fractional value (e.g. “--max-size=1.5m”).
#
#              This option is a transfer rule, not an exclude, so  it  doesn’t  affect  the
#              data  that  goes  into the file-lists, and thus it doesn’t affect deletions.
#              It just limits the files that the receiver requests to be transferred.
#
#              The suffixes are as follows: “K” (or “KiB”) is a kibibyte  (1024),  “M”  (or
#              “MiB”)  is  a  mebibyte  (1024*1024),  and  “G”  (or  “GiB”)  is  a gibibyte
#              (1024*1024*1024).  If you want the multiplier to be 1000  instead  of  1024,
#              use  “KB”,  “MB”,  or “GB”.  (Note: lower-case is also accepted for all val-
#              ues.)  Finally, if the suffix ends in either “+1” or “-1”, the value will be
#              offset by one byte in the indicated direction.
#
#              Examples:  --max-size=1.5mb-1  is  1499999  bytes,  and  --max-size=2g+1  is
#              2147483649 bytes.
#
#       --min-size=SIZE
#              This tells rsync to avoid transferring any file that  is  smaller  than  the
#              specified  SIZE,  which can help in not transferring small, junk files.  See
#              the --max-size option for a description of SIZE and other information.

        for SIZE in 1K 1M 1KB 1MB; do
            rlRun "dd if=/dev/zero of=${LOCAL}/testfile bs=1 count=${SIZE}"
            rlRun "rsync -avh --max-size ${SIZE}-1 ${LOCAL}/testfile localhost::remote | grep testfile" 1
            rlRun "rsync -avh --min-size ${SIZE}+1 ${LOCAL}/testfile localhost::remote | grep testfile" 1
            rlRun "rsync -avh --max-size ${SIZE} ${LOCAL}/testfile localhost::remote | grep testfile"
            rlRun "rm -f ${REMOTE}/testfile"
            rlRun "rsync -avh --max-size ${SIZE} ${LOCAL}/testfile localhost::remote | grep testfile"
            rlRun "rm -f ${REMOTE}/testfile"
        done

    rlPhaseEnd

    rlPhaseStartTest "--size-only"

#       --size-only
#              This modifies rsync’s “quick check” algorithm for finding files that need to
#              be transferred, changing it from the  default  of  transferring  files  with
#              either  a  changed  size or a changed last-modified time to just looking for
#              files that have changed in size.  This is useful when starting to use  rsync
#              after  using  another  mirroring  system  which  may not preserve timestamps
#              exactly.

        rlRun "sleep 2"
        # Modified content, but preserved the size of the destionation 
        rlRun "echo 'Xirst file' > ${REMOTE}/first"

        rlLog "The file would be transfered with only -a option"
        rlRun "rsync -avv -n ${LOCAL}/ localhost::remote | grep first"

        rlLog "only the time  be updated with --size-only option"
        rlRun "rsync -avvv -i --size-only ${LOCAL}/ localhost::remote | grep '.f..t...... first'"
        rlRun "grep 'Xirst' ${REMOTE}/first"

        rlLog "The file won't be tranferred with -a option because of the updated time" 
        rlRun "rsync -avv -i ${LOCAL}/ localhost::remote | grep first" 1

        rlLog "..and finaly, the file will be transfered with -c option"
        rlRun "rsync -avv -i -c ${LOCAL}/ localhost::remote"
        rlRun "grep 'First' ${REMOTE}/first"

    rlPhaseEnd

    #rlPhaseStartTest "-f --filter, -F"

#       -f, --filter=RULE
#              This  option  allows  you  to add rules to selectively exclude certain files
#              from the list of files to be transferred. This is most useful in combination
#              with a recursive transfer.
#
#              You  may  use  as  many  --filter options on the command line as you like to
#              build up the list of files to exclude.  If the filter  contains  whitespace,
#              be  sure  to  quote it so that the shell gives the rule to rsync as a single
#              argument.  The text below also mentions that you can use  an  underscore  to
#              replace the space that separates a rule from its arg.
#
#              See the FILTER RULES section for detailed information on this option.
#
#       -F     The  -F option is a shorthand for adding two --filter rules to your command.
#              The first time it is used is a shorthand for this rule:
#
#                 --filter=’dir-merge /.rsync-filter’
#
#              This tells rsync to look for per-directory  .rsync-filter  files  that  have
#              been sprinkled through the hierarchy and use their rules to filter the files
#              in the transfer.  If -F is repeated, it is a shorthand for this rule:
#
#                 --filter=’exclude .rsync-filter’
#
#              This filters out the .rsync-filter files themselves from the transfer.
#
#              See the FILTER RULES section for detailed information on how  these  options
#              work.

    #rlPhaseEnd

    rlPhaseStartTest "--include --exclude"

#       --include=PATTERN
#              This option is a simplified form of the --filter option that defaults to  an
#              include  rule and does not allow the full rule-parsing syntax of normal fil-
#              ter rules.
#
#              See the FILTER RULES section for detailed information on this option.
#
	rlLogInfo "prepare test files"
	rlRun "mkdir ${LOCAL}/include-test"
	for F in "a.c" "a.log" "b.c" "b.log" "c.c" "c.log" "d.txt"; do
	    rlRun "echo $F$F$F > ${LOCAL}/include-test/$F" 0 "Creating ${LOCAL}/include-test/$F file"
	done

	rlLogInfo "execute rsync command and verify results"
	rlRun "rsync -avv -i --include='*.c' --include='b*' --exclude='*.log' ${LOCAL}/include-test localhost::remote"
	# note: rsync checks each name to  be  transferred  against the list of include/exclude patterns in turn, and the first matching pattern is acted on
	for F in "a.c" "b.c" "c.c" "b.log" "d.txt"; do
		rlAssertExists ${REMOTE}/include-test/$F
	done
	rlAssertNotExists ${REMOTE}/include-test/a.log
	rlAssertNotExists ${REMOTE}/include-test/c.log
	rlRun "rm -rf ${REMOTE}/include-test ${LOCAL}/include-test"

    rlPhaseEnd
	
    rlPhaseStartTest "--include-from --exclude-from"
		

#       --include-from=FILE
#              This option is related to the --include option, but it specifies a FILE that
#              contains include patterns (one per line).  Blank lines in the file and lines
#              starting with ‘;’ or ‘#’ are ignored.  If FILE is -, the list will  be  read
#              from standard input.

	rlLogInfo "prepare test files"
	rlRun "mkdir ${LOCAL}/include-from-test"
	for F in "a.c" "a.log" "b.c" "b.log" "c.c" "c.log" "d.txt"; do
	    rlRun "echo $F$F$F > ${LOCAL}/include-from-test/$F" 0 "Creating ${LOCAL}/include-from-test/$F file"
	done
	rlRun "echo -e '*.c\nb*' > list-include"
	rlRun "echo -e '*.log' > list-exclude"

	rlLogInfo "execute rsync command and verify results"
	rlRun "rsync -avv -i --include-from=list-include --exclude-from=list-exclude ${LOCAL}/include-from-test localhost::remote"
	# note: rsync checks each name to  be  transferred  against the list of include/exclude patterns in turn, and the first matching pattern is acted on
	for F in "a.c" "b.c" "c.c" "b.log" "d.txt"; do
		rlAssertExists ${REMOTE}/include-from-test/$F
	done
	rlAssertNotExists ${REMOTE}/include-from-test/a.log
	rlAssertNotExists ${REMOTE}/include-from-test/c.log
	rlRun "rm -rf ${REMOTE}/include-from-test ${LOCAL}/include-from-test list-include list-exclude"

    rlPhaseEnd

    #rlPhaseStartTest "-0, --from0"
#
#       -0, --from0
#              This tells rsync that the rules/filenames it reads from a  file  are  termi-
#              nated  by  a  null  (’\0’)  character, not a NL, CR, or CR+LF.  This affects
#              --exclude-from, --include-from, --files-from, and any merged files specified
#              in  a --filter rule.  It does not affect --cvs-exclude (since all names read
#              from a .cvsignore file are split on whitespace).
#
#              If the --iconv and --protect-args options are specified and the --files-from
#              filenames  are  being  sent  from one host to another, the filenames will be
#              translated from the sending host’s charset to the receiving host’s  charset.

    #rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf $REMOTE"
        rlRun "rm -rf $LOCAL"
        rlRun "rm -rf $SERVER_LOG_FILE"
        rlRun "rm -rf $LOG_FILE"
        rlFileRestore
        if rlIsRHEL 5 6; then
            rlRun "chkconfig rsync off"
            rlServiceRestore xinetd
        else 
            rlRun "systemctl stop rsyncd.socket"
            rlServiceRestore rsyncd
            $STOPPED || rlRun "systemctl start rsyncd.socket"
        fi
        if [ -n "$WORKAROUNDED" ]; then
	    rlLog "Cleanup of the workaround for bz#1082496"
	    rlRun "rm -rf /usr/lib/systemd/system/rsyncd@.service"
        fi
        sleep 2
        rlRun "ausearch -m AVC -m SELINUX_ERR -ts ${START_DATE_TIME} > ${TMP_FILE}" 0,1
        LINE_COUNT=`wc -l < ${TMP_FILE}`
        rlRun "cat ${TMP_FILE}"
        rlAssert0 "number of lines in ${TMP_FILE} should be 0" ${LINE_COUNT}

    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
