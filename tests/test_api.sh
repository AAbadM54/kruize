#!/bin/bash
#
#*******************************************************************************
#* Copyright (c) 2019, 2020 IBM Corporation and others.
#*
#* Licensed under the Apache License, Version 2.0 (the "License");
#* you may not use this file except in compliance with the License.
#* You may obtain a copy of the License at
#*
#*    http://www.apache.org/licenses/LICENSE-2.0
#*
#* Unless required by applicable law or agreed to in writing, software
#* distributed under the License is distributed on an "AS IS" BASIS,
#* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#* See the License for the specific language governing permissions and
#* limitations under the License.
#*******************************************************************************/
#

KRUIZE_URL="http://localhost"
KRUIZE_PORT="31313"
AUTH_TOKEN=""
CLUSTER_TYPE=""

function usage() {
	echo
	echo "Usage: $0 [-u kruize_url] [-p kruize_port] [-a auth_token] [-c cluster_type]"
	exit -1
}

#Check required tools are installed 
function check_tool_existance() {
	if ! [ -x "$(command -v $1)" ]; then
		echo "Error: $1 is not installed."
		exit 1
	fi
}


function check_auth_token() {
	if [[ $(curl -s -o /dev/null -w "%{http_code}" ${KRUIZE_URL}:${KRUIZE_PORT}/health) == "403" ]]; then
		echo "Error: Invalid auth token"
		exit 1
	fi
}

function get_bearer_token() {
        if [[ $CLUSTER_TYPE == "openshift" ]]; then
		check_tool_existance "oc"
                AUTH_TOKEN=$(oc whoami --show-token)
        elif [[ $CLUSTER_TYPE == "ICP" ]]; then
                check_tool_existance "cloudctl"
                AUTH_TOKEN=$(cloudctl tokens | grep "Bearer"  | cut -d' ' -f5)
	else 
		echo "Error - Invalid Cluster Type"
		exit 1
	fi 
}

function get_recommendation_for_application() {
	${curl_cmd}/recommendations?application_name=$1 | jq -r '.[]'
}

function get_list_of_applications {
	${curl_cmd}/listApplications | jq -c '.[]' 
}

# Iterate through the commandline options
while getopts a:c:p:u: gopts
do
	case ${gopts} in
		u)
			KRUIZE_URL="${OPTARG}"
			;; 
		p)
			KRUIZE_PORT="${OPTARG}"
			;;
		a)
			AUTH_TOKEN="${OPTARG}"
			;;
		c)      
			CLUSTER_TYPE="${OPTARG}"
                        ;;
		[?])
			usage
	esac
done

check_tool_existance "jq"

if [[ $AUTH_TOKEN == "" ]]; then
	if [[ -z $CLUSTER_TYPE ]]; then
		echo "Error - Enter AUTH_TOKEN or set the CLUSTER_TYPE !!"
		exit 1 
	else  
		get_bearer_token ${CLUSTER_TYPE}
	fi
fi

curl_cmd="curl -s -H 'Authorization:Bearer $AUTH_TOKEN' $KRUIZE_URL:$KRUIZE_PORT"

check_auth_token

#Check if Kruize is running without issues, and fetch recommendations generated
while [[ $(${curl_cmd}/health) == "UP" ]]; do
	for row in $(get_list_of_applications); do
		application_name=$(echo "${row}" | jq -r '.application_name')
		recommendations_generated=$(echo "${row}" | jq -r '.recommendations_generated')

		if [[ "$recommendations_generated" == "yes" ]]; then
			get_recommendation_for_application ${application_name}
			echo
		fi
	done
	sleep 1m
done


