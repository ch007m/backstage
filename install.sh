#!/usr/bin/env bash

set -o errexit

#
# Script to install backstage on k8s and to configure the ConfigMap
#
# See CHANGELOG.md file
#

###################################
# Defining some colors for output
###################################
NC='\033[0m' # No Color
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

newline=$'\n'

###################################
# Logging
###################################
generate_eyecatcher(){
  COLOR=${1}
	for i in {1..50}; do echo -ne "${!COLOR}$2${NC}"; done
}

log() {
  COLOR=${1}
  MSG="${@:2}"
  echo -e "${!COLOR}${MSG}${NC}"
}

info() {
  log "CYAN" ${1}
}

warn() {
  log "YELLOW" ${1}
}

fail() {
  log "RED" ${1}
}

section() {
  echo; generate_eyecatcher ${1} '#'; echo -e "\n${!1}${2}${NC}"; generate_eyecatcher ${1} '#'; echo
}

###################################
# HELP_CONTEN
###################################
HELP_CONTENT="
Usage: install.sh [OPTIONS]
Options:

[Global Mandatory Flags]
  --action: What action to take ?
    \"deploy\": Installing backstage
    \"remove\": Deleting backstage

[Global Optional Flags]
  -h or -help: Show this help menu

[Mandatory Flags - Used by the Instance/Delete Action]
  --ip-domain-name: VM IP and domain name (e.g 192.168.1.100.sslp.io)
"

############################################################################
## Check if flags are passed and set the variables using the flogs passed
############################################################################
if [[ $# == 0 ]]; then
  fail "No Flags were passed to: ./install.sh. Run with -h | --help flag to get usage information"
  exit 1
fi

while test $# -gt 0; do
  case "$1" in
     -a | --action)
      shift
      action=$1
      shift;;
     --ip-domain-name)
      shift
      ip_domain_name=$1
      shift;;
     -h | --help)
      echo "$HELP_CONTENT"
      exit 1;;
    *)
      fail "$1 is note a recognized flag!"
      exit 1
      ;;
  esac
done

#######################################################
## Set default values when no optional flags are passed
#######################################################
#: ${tds_version:="1.7.3"}

#######################################################
## Set local default values
#######################################################
#postgres_api_group="sql.tanzu.vmware.com"

if ! command -v kind &> /dev/null; then
  fail "kind could not be found. See doc page to install it: https://kind.sigs.k8s.io/#installation-and-usage"
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
  fail "kubectl could not be found. See doc page to install it: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
  exit 1
fi

if ! command -v helm &> /dev/null; then
  fail "Helm could not be found. See doc page to install it: https://helm.sh/docs/intro/install/"
  exit 1
fi

# Actions to executed
case $action in
  deploy)
    # Validate if Mandatory Flags were supplied
    if ! [[ ${ip_domain_name} ]]; then
      fail "Mandatory flags were note passed: --ip-domain-name"
      exit 1
    fi
    info "Creating the my-values.yml file containing the backstage helm values at $(pwd)/temp/my-values.yml"
    cat <<EOF > $(pwd)/temp/my-values.yml
ingress:
  enabled: true
  host: backstage.${ip_domain_name}
  className: nginx
backstage:
  image:
    registry: "docker.io/library"
    repository: "backstage"
    tag: "dev"
    pullPolicy: "IfNotPresent"
  extraAppConfig:
    - filename: app-config.extra.yaml
      configMapRef: my-app-config
postgresql:
  enabled: false
EOF
    info "Creating the backstage app-config.extra.yaml file"
    cat <<EOF > $(pwd)/temp/app-config.extra.yaml
app:
  baseUrl: http://backstage.${ip_domain_name}
  title: Backstage
backend:
  baseUrl: http://backstage.${ip_domain_name}
  cors:
    origin: http://backstage.${ip_domain_name}
    methods: [GET, POST, PUT, DELETE]
    credentials: true
  csp:
    connect-src: ['self','http:','https:']
  database:
    client: better-sqlite3
    connection: ':memory:'
  cache:
    store: memory
techdocs:
  builder: 'local' # Alternatives - 'external'
  generator:
    runIn: 'docker' # Alternatives - 'local'
  publisher:
    type: 'local' # Alternatives - 'googleGcs' or 'awsS3'. Read documentation for using alternatives.
catalog:
  locations:
  - type: url
    target: https://github.com/mclarke47/dice-roller/blob/master/catalog-info.yaml
EOF
    info "Deploying backstage using helm"
    helm upgrade --install \
      my-backstage \
      backstage \
      --repo https://vinzscam.github.io/backstage-chart \
      -f $(pwd)/temp/my-values.yml \
      --create-namespace \
      -n backstage

    info "Creating the backstage cluster admin role for the service account of backstage"
    cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage
  namespace: backstage
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: sa-admin
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: backstage
    namespace: backstage
EOF
    info "Updating the backstage config app file to configure the kubernetes plugin. Rollout backstage deployment"
    cat <<EOF >>  $(pwd)/temp/app-config.extra.yaml
kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'
  clusterLocatorMethods:
  - type: 'config'
    clusters:
      - url: https://kubernetes.default.svc
        name: kind
        authProvider: 'serviceAccount'
        skipTLSVerify: true
        skipMetricsLookup: true
        serviceAccountToken: /var/run/secrets/kubernetes.io/serviceaccount/token
EOF

    kubectl create configmap my-app-config -n backstage \
      --from-file=app-config.extra.yaml=$(pwd)/temp/app-config.extra.yaml \
      -o yaml \
      --dry-run=client | kubectl apply -n backstage -f -

    kubectl rollout restart deployment/my-backstage -n backstage

    section "CYAN" "Backstage deployed successfully under the namespace: backstage"
    info "You can access the UI within your browser using the address: http://backstage.${ip_domain_name}";;
  remove)
    helm uninstall my-backstage -n backstage
    kubectl delete ClusterRoleBinding/sa-admin
    kubectl delete sa/backstage -n backstage
    info "Removed.";;
  *)
   fail "Unknown action passed: $action. Please use --help."
   exit 1
esac