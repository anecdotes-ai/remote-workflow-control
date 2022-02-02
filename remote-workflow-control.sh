#!/usr/bin/env bash

# Copyright (C) 2021 anecdotes.ai;
# Author:     Ido Ozeri <ido@anecdotes.ai>
# Maintainer: Ido Ozeri <ido@anecdotes.ai>
# Purpose: trigger a remote Github workflow and examine its exit status;

# Variables
DIR=$(dirname $0)
PROG=$(basename $0)

SCRIPT_FULLPATH=$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)

# Load everything we need;
source $SCRIPT_FULLPATH/functions || exit 1
source $SCRIPT_FULLPATH/variables || exit 1

# Process options
SHORT_OPTS="ha:b:i:w:o:r:y:"
LONG_OPTS="help,auth-token:,workflow-inputs:,workflow-branch:,wait-timeout-minutes:,workflow-repo:,workflow-yaml:,workflow-org:"
OPTS=$(getopt -o $SHORT_OPTS -l $LONG_OPTS -n "$0" -- "$@")

if [ $? != 0 ] ; then
    /bin/echo "Terminating..." >&2
    exit 1
fi

eval set -- "$OPTS"

while true ; do
    case "$1" in
        -h|--help) usage ; exit 0;;
        -a|--auth-token) AUTH_TOKEN=$(echo -n $2 | base64) ; shift 2;;
        -o|--workflow-org) WORKFLOW_ORG=$2 ; shift 2;;
        -r|--workflow-repo) WORKFLOW_REPO=$2 ; shift 2;;
        -y|--workflow-yaml) WORKFLOW_YAML=$2 ; shift 2;;
        -b|--workflow-branch) WORKFLOW_BRANCH=$2 ; shift 2;;
        -i|--workflow-inputs) WORKFLOW_INPUTS=$2 ; shift 2;;
        -w|--wait-timeout-minutes) WAIT_TIMEOUT_MINUTES=$2 ; shift 2;;
        --) shift; break;;
    esac
done

WAIT_TIMEOUT_MINUTES=${WAIT_TIMEOUT_MINUTES:-${DEFAULT_WAIT_TIMEOUT_MINUTES}}
TRIGGER_UUID_VALUE=$(generate_uuid)

###########################################################################################
###################################### MAIN WORKFLOW ######################################
###########################################################################################

check_required_binaries $REQUIRED_BINARIES || die 1 "cannot proceed when some binaries are missing"

verify_option_was_provided AUTH_TOKEN      "--auth-token"
verify_option_was_provided WORKFLOW_ORG    "--workflow-org"
verify_option_was_provided WORKFLOW_REPO   "--workflow-repo"
verify_option_was_provided WORKFLOW_YAML   "--workflow-yaml"
verify_option_was_provided WORKFLOW_BRANCH "--workflow-branch"

# Since the '--workflow-inputs' option requires *some* argument, 
# I wanted to refrain from having to specify it inside the variables 
# that are passed to 'action.yaml', therefore I'm setting the default
# value of inputs to 'none' and nullifying it here below if it is not provided by the user;

mandatory_inputs="{\"ref\": \"$WORKFLOW_BRANCH\", \"inputs\": {\"trigger_uuid\": \"$TRIGGER_UUID_VALUE\"}}"

if [[ $WORKFLOW_INPUTS == "none" ]] ; then
    curl_post_data="{\"ref\": \"$WORKFLOW_BRANCH\", \"inputs\": {\"trigger_uuid\": \"$TRIGGER_UUID_VALUE\"}}"
    declare WORKFLOW_INPUTS=""
else
    curl_post_data=$(jq -c '.inputs += '"$WORKFLOW_INPUTS"''<<<"$mandatory_inputs")
fi

# Building the relevant URLs based on user input;
WORKFLOW_BASE_URL="$GITHUB_API_BASEURL/$WORKFLOW_ORG/$WORKFLOW_REPO/actions"
WORKFLOW_ARTIFACTS_URL="$WORKFLOW_BASE_URL/artifacts"
WORKFLOW_DISPATCH_URL="$WORKFLOW_BASE_URL/workflows/$WORKFLOW_YAML/dispatches"

trigger_workflow $WORKFLOW_DISPATCH_URL $WORKFLOW_BRANCH \
    "$curl_post_data"

wait_for_status $TRIGGER_UUID_VALUE $WORKFLOW_ARTIFACTS_URL $WAIT_TIMEOUT_MINUTES
#END
