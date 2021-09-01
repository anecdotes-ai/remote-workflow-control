#!/usr/bin/env bash

# Copyright (C) 2021 anecdotes.ai;
# Author:     Ido Ozeri <ido@anecdotes.ai>
# Maintainer: Ido Ozeri <ido@anecdotes.ai>
# Purpose: trigger a remote Github workflow and examine its exit status;

# Variables
DIR=$(dirname $0)
PROG=$(basename $0)
DEFAULT_WAIT_TIMEOUT_MINUTES=5
REQUIRED_BINARIES="openssl zcat jq curl"

SCRIPT_FULLPATH=$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)
source $SCRIPT_FULLPATH/functions || exit 1

# Process options
SHORT_OPTS="ha:b:i:u:w:"
LONG_OPTS="help,auth-token:,workflow-inputs:,workflow-branch:,workflow-url:,wait-timeout-minutes:"
OPTS=$(getopt -o $SHORT_OPTS -l $LONG_OPTS -n "$0" -- "$@")

if [ $? != 0 ] ; then
    /bin/echo "Terminating..." >&2
    exit 1
fi

eval set -- "$OPTS"

while true ; do
    case "$1" in
        # Print the long options prefixed with '--';
        -h|--help) usage ; exit 0;;
        -a|--auth-token) AUTH_TOKEN=$(echo -n $2 | base64) ; shift 2;;
        -b|--workflow-branch) WORKFLOW_BRANCH=$2 ; shift 2;;
        -i|--workflow-inputs) WORKFLOW_INPUTS=$2 ; shift 2;;
        -u|--workflow-url) WORKFLOW_URL=$2 ; shift 2;;
        -w|--wait-timeout-minutes) WAIT_TIMEOUT_MINUTES=$2 ; shift 2;;
        --) shift; break;;
    esac
done

WAIT_TIMEOUT_MINUTES=${WAIT_TIMEOUT_MINUTES:-${DEFAULT_WAIT_TIMEOUT_MINUTES}}
TRIGGER_UUID_INPUT_VAR="trigger_uuid"
TRIGGER_UUID_VALUE=$(generate_uuid)

###########################################################################################
###################################### MAIN WORKFLOW ######################################
###########################################################################################

check_required_binaries $REQUIRED_BINARIES || die 1 "cannot proceed when some binaries are missing"

verify_option_was_provided AUTH_TOKEN      "--auth-token"
verify_option_was_provided WORKFLOW_URL    "--workflow-url"
verify_option_was_provided WORKFLOW_BRANCH "--workflow-branch"

# Since the '--workflow-inputs' option requires *some* argument, 
# I wanted to refrain from having to specify it inside the variables 
# that are passed to 'action.yaml', therefore I'm setting the default
# value of inputs to 'none' and nullifying it here below if it is not provided by the user;

if [[ $WORKFLOW_INPUTS == "none" ]] ; then
    declare WORKFLOW_INPUTS=""
fi

trigger_workflow $WORKFLOW_URL $WORKFLOW_BRANCH \
    $TRIGGER_UUID_INPUT_VAR=$TRIGGER_UUID_VALUE ${WORKFLOW_INPUTS[@]}

wait_for_status $TRIGGER_UUID_VALUE $(extract_workflow_base_url $WORKFLOW_URL) $WAIT_TIMEOUT_MINUTES
#END
