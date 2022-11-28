#!/bin/bash

REPO_ZIP=${1}
oc new-project quickstarts
oc adm policy add-scc-to-user privileged -z default -n quickstarts
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

OCP_IMAGE_REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')

oc get secret -n openshift-ingress  router-certs-default -o go-template='{{index .data "tls.crt"}}' | base64 -d | sudo tee /etc/pki/ca-trust/source/anchors/${OCP_IMAGE_REGISTRY}.crt  > /dev/null
sudo update-ca-trust enable

OCP_NAMESPACE=$(oc project -q)
OCP_IMAGE=${OCP_IMAGE_REGISTRY}/${OCP_NAMESPACE}/eap-maven-repo

echo "Building container image eap-maven-repo "
podman build  --build-arg REPO_ZIP=${REPO_ZIP} -t eap-maven-repo .

echo "Login to ${OCP_IMAGE_REGISTRY}"
oc registry login
podman login  -u kube:admin -p $(oc whoami -t) ${OCP_IMAGE_REGISTRY}

echo "Pushing ${OCP_IMAGE}"
podman tag eap-maven-repo ${OCP_IMAGE}
podman push ${OCP_IMAGE}

echo "OCP Image stream for the EAP maven repo"
oc get imagestreamtag eap-maven-repo:latest

echo "Deploy the EAP Maven repo"
oc delete deployment eap-maven-repo || true
oc delete service eap-maven-repo || true
oc new-app --name eap-maven-repo --image-stream=eap-maven-repo

oc create route passthrough eap-maven-repo --service=eap-maven-repo --port=4443

echo ""
echo "You can access this EAP Maven repository inside the OpenShift cluster with the URL"
echo ""
echo "http://eap-maven-repo.${OCP_NAMESPACE}.svc.cluster.local:8080"
echo ""
