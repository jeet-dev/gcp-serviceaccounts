#!/bin/bash
#getServiceAccount.sh

PROJECTS=$(gcloud projects list --format="value(projectId)")
#PROJECTS="terraform-gcp-sa"

find . -type f -name '*.txt' -exec rm -f {} \;
find . -type f -name '*.csv' -exec rm -f {} \;

for PROJECT in ${PROJECTS}
do
  echo "Project: ${PROJECT}"
  
  ROBOTS=$(\
    gcloud iam service-accounts list \
    --project=${PROJECT} \
    --format="csv[no-heading](displayName.split(\" \").slice(0),email,email.split(\"@\").slice(0),disabled)")
 
   for ROBOT in ${ROBOTS}
  do
     # Parse results
    NAME=`echo $ROBOT | awk  -F',' '{print $1}'`
    DISABLED=`echo $ROBOT | awk -F',' '{print $4}'`
    EMAIL=`echo $ROBOT | awk -F',' '{print $2}'`
    ACCOUNT_ID=`echo $ROBOT | awk -F',' '{print $3}'`
    echo "----------------------------"
    echo "  Service Account: ${NAME}"
    echo "  Disabled: ${DISABLED}"
    echo "  Email: ${EMAIL}"
    echo "----------------------------"
    # Keys
    KEYS=$(\
        gcloud iam service-accounts keys list --iam-account=${EMAIL} \
        --project=${PROJECT} \
        --format="value(name.scope(keys))")
    for KEY in ${KEYS}
    do
      echo "    Key: ${KEY}"
    done
    # Creation (Only searches back 30-days!)
FILTER1=""\
"logName=\"projects/${PROJECT}/logs/cloudaudit.googleapis.com%2Factivity\" "\
"resource.type=\"service_account\" "\
"protoPayload.methodName=\"google.iam.admin.v1.CreateServiceAccount\" "\
"protoPayload.request.account_id=\"${ACCOUNT_ID}\" "

# Last Authentication Time

FILTER2=""\
"activities.full_resource_name=\"//iam.googleapis.com/projects/${PROJECT}/serviceAccounts/${EMAIL}\" "

    LOG=$(\
        gcloud logging read "${FILTER1}" \
        --project=${PROJECT} \
        --format=json \
        --freshness=30d \
        --format="value(timestamp)")
    
    LAST_ACTIVITY=$(\
        gcloud policy-intelligence query-activity \
        --activity-type=serviceAccountLastAuthentication \
        --project ${PROJECT} \
        --query-filter="${FILTER2}" \
        --format="json"| jq '.[0] .activity.lastAuthenticatedTime')

    echo " Created: ${LOG}"
    echo " Last Activity: ${LAST_ACTIVITY}"

    awk -v EMAIL="${EMAIL}" -v DISABLED="${DISABLED}" -v CREATED="${LOG}" 'BEGIN {print EMAIL,DISABLED,CREATED >> "output.csv"; close("output.csv");}'
  done
done
awk 'BEGIN{print "EMAIL DISABLED CREATED"}1' output.csv > ${PROJECT}_service_accounts.csv
