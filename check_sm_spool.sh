#!/bin/bash

usage() { 
  echo "Usage: $0 -h <Smartermail host> -u <username> -p <password> [-q <default|waiting|virus|spam>] -w <warning limit> -c <critical limit>" 1>&2; exit 1; 
}

inputValidationError() {
  echo "Invalid argument $2 for option -$1"
  usage
}

isnumber='^[0-9]+$'
QUEUE='default'

while getopts h:u:p:q:w:c: option
do
  case "${option}"
    in
    h ) HOST=${OPTARG};;
    u ) USER=${OPTARG};;
    p ) PASS=${OPTARG};;
    q ) VALIDARG="default waiting virus spam"
      if [[ "$VALIDARG" == *"$OPTARG"* ]] ; then
        QUEUE=${OPTARG}
      else
        inputValidationError $option $OPTARG
      fi
      ;;
    w ) if [[ $OPTARG =~ $isnumber ]] ; then
        WARNING=${OPTARG}
      else
        inputValidationError $option $OPTARG
      fi
      ;;
    c ) if [[ $OPTARG =~ $isnumber ]] ; then
        CRITICAL=${OPTARG}
      else
        inputValidationError $option $OPTARG
      fi
      ;;
    \?) echo "Unknown option: -${option}"
      usage
      ;;
    : ) echo "Missing option argument for -${option}"      
      usage
      ;;
    * ) echo "Unimplemented option: -${option}"
      usage
      ;;
  esac
done

if [[ ! ${HOST} || ! ${USER} || ! ${PASS} || ! ${WARNING} || ! ${CRITICAL} ]]; then
  echo "Required option missing"
  usage
fi

if ((${WARNING} >= ${CRITICAL})); then
  echo "Critical threshold -c ${CRITICAL} should be greater than warning threshold -w ${WARNING}" 1>&2; exit 1; 
fi

# Check for curl
type curl >/dev/null 2>&1 || { echo >&2 "curl is required but isn't installed. Aborting."; exit 1; }
# Check for jq
type jq >/dev/null 2>&1 || { echo >&2 "jq is required but isn't installed. Aborting."; exit 1; }

PAYLOAD='{"username": "'${USER}'", "password": "'${PASS}'"}'

#Authenticate to the SmarterMail API
RESPONSE=`curl -s --request POST -H "Content-Type:application/json" https://${HOST}/api/v1/auth/authenticate-user --data "${PAYLOAD}" --show-error`
if [[ 0 -lt $? ]]; then echo "Failed to connect to ${HOST} see error above."; exit 3; fi;

TOKEN=`echo $RESPONSE | jq -r ".accessToken"` 

#Call the SmarterMail API with the AccessToken
RESPONSE=`curl -s --request GET -H "Content-Type:application/json" -H "Content-Length: 0" -H "Authorization: Bearer ${TOKEN}" https://${HOST}/api/v1/settings/sysadmin/spool-message-counts --show-error`
if [[ 0 -lt $? ]]; then echo "Failed to connect to ${HOST} see error above."; exit 3; fi;

#Filter Response for specific queue
QUEUECOUNT=`echo $RESPONSE | jq ".counts.${QUEUE}"`

#Compare the queue count to the supplied thresholds.
if ! [[ $QUEUECOUNT =~ $isnumber ]] ; then
  echo "error: invalid data received from server: $QUEUECOUNT" >&2; exit 3
fi

if [[ $QUEUECOUNT -lt $WARNING ]]; then
  echo "OK - $QUEUECOUNT messages in the ${QUEUE} queue."
  exit 0
elif [[ $QUEUECOUNT -ge $WARNING ]] && [[ $QUEUECOUNT -lt $CRITICAL ]]; then
  echo "WARNING - $QUEUECOUNT messages in the ${QUEUE} queue."
  exit 1
elif [[ $QUEUECOUNT -ge $CRITICAL ]]; then
  echo "CRITICAL - $QUEUECOUNT messages in the ${QUEUE} queue."
  exit 2
else
  echo "UNKNOWN - $QUEUECOUNT messages in the ${QUEUE} queue."
  exit 3
fi
