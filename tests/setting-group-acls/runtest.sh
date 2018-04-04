#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of setting-group-acls
#   Description: If you are using the -A/--acls option and you are not running as root and are not using the --numeric-ids option then if you have an ACL that includes a group entry for a group you are not a member of on the receiving side, then acl_set_file will return EINVAL, b/c rsync mistakenly maps the group name to gid GID_NONE (-1), which (fortunately) fails.
#   Author: Ales Marecek <amarecek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
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

# Include rhts environment
. /usr/bin/rhts-environment.sh
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="rsync"
_TEST_USER="rsynctestuser"
_TEST_USER_PASSWORD="redhat"
_TEST_USER_HOME_DIR="/home/${_TEST_USER}"
_TEST_USER_SRC_TEST_DIR="${_TEST_USER_HOME_DIR}/src_rsync"
_TEST_USER_DST_TEST_DIR="${_TEST_USER_HOME_DIR}/dst_rsync"
_TEST_RAND_FILENAME="random.data"
_TEST_TEXT_FILENAME="hello_world.txt"
_TEST_RAND_FILE="${_TEST_USER_SRC_TEST_DIR}/${_TEST_RAND_FILENAME}"
_TEST_TEXT_FILE="${_TEST_USER_SRC_TEST_DIR}/${_TEST_TEXT_FILENAME}"
_TEST_RAND_FILE_SIZE=10

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
	id ${_TEST_USER} >/dev/null 2>&1 || rlRun "useradd -d ${_TEST_USER_HOME_DIR} -m ${_TEST_USER}" 0 "Creating a test user"
	rlRun "echo \"${_TEST_USER_PASSWORD}\" | passwd --stdin ${_TEST_USER} >/dev/null 2>&1" 0 "Setting user's password"
	rlRun "su - ${_TEST_USER} -c \"mkdir -p ${_TEST_USER_SRC_TEST_DIR} ${_TEST_USER_DST_TEST_DIR}\"" 0 "Creating directories for test data"
	rlRun "su ${_TEST_USER} -c \"dd if=/dev/urandom of=${_TEST_RAND_FILE} bs=1M count=${_TEST_RAND_FILE_SIZE}\"" 0 "Generating random data file"
	rlRun "su ${_TEST_USER} -c \"echo 'Hello world' >${_TEST_TEXT_FILE}\"" 0 "Generating text data file"
	rlRun "setfacl -m g:root:--- ${_TEST_RAND_FILE}" 0 "Setting ACL for random data file"
	rlRun "setfacl -m g:root:--- ${_TEST_TEXT_FILE}" 0 "Setting ACL for text data file"
    rlPhaseEnd

    rlPhaseStartTest
	rlRun "su - ${_TEST_USER} -c \"rsync -A ${_TEST_RAND_FILE} ${_TEST_USER_DST_TEST_DIR}\"" 0 "Syncing random data file"
	rlRun "su - ${_TEST_USER} -c \"rsync -A ${_TEST_TEXT_FILE} ${_TEST_USER_DST_TEST_DIR}\"" 0 "Syncing text data file"
    getfacl ${_TEST_USER_DST_TEST_DIR}/${_TEST_RAND_FILENAME}
    rlRun "getfacl ${_TEST_USER_DST_TEST_DIR}/${_TEST_RAND_FILENAME} | grep 'group:root:---'" 0 "Verify that ACL was properly set"
    getfacl ${_TEST_USER_DST_TEST_DIR}/${_TEST_TEXT_FILENAME}
    rlRun "getfacl ${_TEST_USER_DST_TEST_DIR}/${_TEST_TEXT_FILENAME} | grep 'group:root:---'" 0 "Verify that ACL was properly set"
    rlPhaseEnd

    rlPhaseStartCleanup
	rlRun "userdel -r ${_TEST_USER}" 0 "Deleting test user"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

