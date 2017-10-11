#!/bin/bash

readonly DOCKERHUB_USER="${1}"
readonly DOCKERHUB_PASS="${2}"
readonly DOCKERHUB_ORG="${3}"
readonly LAUNCH_APB_ON_BIND="${4}"
readonly ORIGIN_VERSION="v3.6.0"
readonly TEMPLATE_URL="https://raw.githubusercontent.com/openshift/ansible-service-broker/master/templates/deploy-ansible-service-broker.template.yaml"

# Add additional parameters for 3.6 vs 3.7
if [ "${ORIGIN_VERSION}" = "latest" ]; then
    ENABLE_BASIC_AUTH="false"
    VARS="-p BROKER_CA_CERT=$(oc get secret -n kube-service-catalog -o go-template='{{ range .items }}{{ if eq .type "kubernetes.io/service-account-token" }}{{ index .data "service-ca.crt" }}{{end}}{{"\n"}}{{end}}' | tail -n 1)"
else
    ENABLE_BASIC_AUTH=${ENABLE_BASIC_AUTH:-"true"}
    BROKER_AUTH=$(echo -e "{\"basicAuthSecret\":{\"namespace\":\"ansible-service-broker\",\"name\":\"asb-auth-secret\"}}")
    VARS="-p BROKER_KIND=Broker \
        -p BROKER_AUTH=$BROKER_AUTH"
fi

curl -s TEMPLATE_URL > /tmp/deploy-ansible-service-broker.template.yaml

oc login -u system:admin
oc new-project ansible-service-broker
oc process -f /tmp/deploy-ansible-service-broker.template.yaml \
    -n ansible-service-broker \
    -p DOCKERHUB_USER="${DOCKERHUB_USER}" \
    -p DOCKERHUB_PASS="${DOCKERHUB_PASS}" \
    -p DOCKERHUB_ORG="${DOCKERHUB_ORG}" \
    -p ENABLE_BASIC_AUTH=${ENABLE_BASIC_AUTH} \
    -p SANDBOX_ROLE="admin" \
    -p ROUTING_SUFFIX="192.168.37.1.nip.io" \
    -p LAUNCH_APB_ON_BIND="${LAUNCH_APB_ON_BIND}" | oc create -f -

if [ "${?}" -ne 0 ]; then
	echo "Error processing template and creating deployment"
	exit
fi
