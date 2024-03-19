#!/bin/bash

# script name: aks-flp-storage.sh
# Version v0.0.7 20240315
# Set of tools to deploy AKS troubleshooting labs

# "-l|--lab" Lab scenario to deploy
# "-g|--resource-group" resource group to deploy the resources
# "-r|--region" region to deploy the resources
# "-s|--sku" nodes SKU
# "-u|--user" User alias to add on the lab name
# "-v|--validate" validate resolution
# "-h|--help" help info
# "--version" print version

# read the options
TEMP=`getopt -o g:n:l:r:s:u:hv --long resource-group:,name:,lab:,region:,sku:,user:,help,validate,version -n 'aks-flp-storage.sh' -- "$@"`
eval set -- "$TEMP"

# set an initial value for the flags
RESOURCE_GROUP=""
CLUSTER_NAME=""
LAB_SCENARIO=""
USER_ALIAS=""
LOCATION="uksouth"
SKU="Standard_DC2s_v2"
VALIDATE=0
HELP=0
VERSION=0

while true ;
do
    case "$1" in
        -h|--help) HELP=1; shift;;
        -g|--resource-group) case "$2" in
            "") shift 2;;
            *) RESOURCE_GROUP="$2"; shift 2;;
            esac;;
        -n|--name) case "$2" in
            "") shift 2;;
            *) CLUSTER_NAME="$2"; shift 2;;
            esac;;
        -l|--lab) case "$2" in
            "") shift 2;;
            *) LAB_SCENARIO="$2"; shift 2;;
            esac;;
        -r|--region) case "$2" in
            "") shift 2;;
            *) LOCATION="$2"; shift 2;;
            esac;;
        -s|--sku) case "$2" in
            "") shift 2;;
            *) SKU="$2"; shift 2;;
            esac;;
        -u|--user) case "$2" in
            "") shift 2;;
            *) USER_ALIAS="$2"; shift 2;;
            esac;;    
        -v|--validate) VALIDATE=1; shift;;
        --version) VERSION=1; shift;;
        --) shift ; break ;;
        *) echo -e "Error: invalid argument\n" ; exit 3 ;;
    esac
done

# Variable definition
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPT_NAME="$(echo $0 | sed 's|\.\/||g')"
SCRIPT_VERSION="Version v0.0.7 20240315"

# Funtion definition

# az login check
function az_login_check () {
    if $(az account list 2>&1 | grep -q 'az login')
    then
        echo -e "\n--> Warning: You have to login first with the 'az login' command before you can run this lab tool\n"
        az login -o table
    fi
}

# validate SKU availability
function check_sku_availability () {
    SKU="$1"
    
    echo -e "\n--> Checking if SKU \"$SKU\" is available in your subscription at region \"$LOCATION\" ...\n"
    while true; do for s in / - \\ \|; do printf "\r$s"; sleep 1; done; done &  # running spiner
    SKU_LIST="$(az vm list-skus -l $LOCATION -o table | grep -v -E '(disk|hostGroups/hosts|snapshots|availabilitySets|NotAvailableForSubscription|Name|^--)')"
    kill $!; trap 'kill $!' SIGTERM # kill spiner
    if ! $(echo "$SKU_LIST" | grep -q -w "$SKU")
    then
        echo -e "\n--> ERROR: The SKU \"${SKU}\" is not available in your subscription at region \"${LOCATION}\".\n"
        echo -e "The SKUs currently available in your subscription for region \"${LOCATION}\" are:\n"
        echo "$SKU_LIST" | awk '{print $3}' | pr -7 -s" | " -T
        echo -e "\n\n--> Please try with one of the above SKUs (if any) or try with a different region.\n"
        exit 4
    else
        echo -e "\n--> SKU \"${SKU}\" is available in your subscription at region \"${LOCATION}\"\n"
    fi
}

# check resource group and cluster
function check_resourcegroup_cluster () {
    RESOURCE_GROUP="$1"
    CLUSTER_NAME="$2"

    RG_EXIST=$(az group show -g $RESOURCE_GROUP &>/dev/null; echo $?)
    if [ $RG_EXIST -ne 0 ]
    then
        echo -e "\n--> Creating resource group ${RESOURCE_GROUP}...\n"
        az group create --name $RESOURCE_GROUP --location $LOCATION -o table &>/dev/null
    else
        echo -e "\nResource group $RESOURCE_GROUP already exists...\n"
    fi

    CLUSTER_EXIST=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null; echo $?)
    if [ $CLUSTER_EXIST -eq 0 ]
    then
        echo -e "\n--> Cluster $CLUSTER_NAME already exists...\n"
        echo -e "Please remove that one before you can proceed with the lab.\n"
        exit 5
    fi
}

# validate cluster exists
function validate_cluster_exists () {
    RESOURCE_GROUP="$1"
    CLUSTER_NAME="$2"

    CLUSTER_EXIST=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null; echo $?)
    if [ $CLUSTER_EXIST -ne 0 ]
    then
        echo -e "\n--> ERROR: Failed to create cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP ...\n"
        exit 5
    fi
}

# Usage text
function print_usage_text () {
    NAME_EXEC="aks-flp-storage"
    echo -e "$NAME_EXEC usage: $NAME_EXEC -l <LAB#> -u <USER_ALIAS> [-g|--resource-group] [-v|--validate] [-r|--region] [-s|--sku] [-h|--help] [--version]"
    echo -e "\nHere is the list of current labs available:
*************************************************************************************
*\t 1. AKS disk attach issues
*\t 2. AKS disk multiattach issues
*************************************************************************************\n"
echo -e '"-l|--lab" Lab scenario to deploy (3 possible options)
"-u|--user" User alias to add on the lab name
"-r|--region" region to create the resources
"-s|--sku" nodes SKU
"-v|--validate" validate resolution
"--version" print version of the tool
"-h|--help" help info\n'
}

# Lab scenario 1
function lab_scenario_1 () {
    CLUSTER_NAME=aks-storage-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=${RESOURCE_GROUP:-aks-storage-ex${LAB_SCENARIO}-rg-${USER_ALIAS}}
    
    #check_sku_availability "$SKU"
    check_resourcegroup_cluster $RESOURCE_GROUP $CLUSTER_NAME

    echo -e "\n--> Deploying cluster for lab${LAB_SCENARIO}...\n"

    az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --location $LOCATION \
    --node-count 1 \
    --node-vm-size "$SKU" \
    --tag aks-storage-lab=${LAB_SCENARIO} \
    --generate-ssh-keys \
    --yes \
    -o table

    validate_cluster_exists $RESOURCE_GROUP $CLUSTER_NAME

    echo -e "\n\n--> Please wait while we are preparing the environment for you to troubleshoot...\n"
    az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME --overwrite-existing &>/dev/null
    az disk create \
    --resource-group $RESOURCE_GROUP \
    --name datadisk1 \
    --size-gb 5 &>/dev/null
    DISK_URI="$(az disk show -g $RESOURCE_GROUP -n datadisk1 -o tsv --query id)"

kubectl create ns workload &>/dev/null
cat <<EOF | kubectl -n workload apply -f &>/dev/null -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mydeployment
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:latest
        name: mypod
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
        volumeMounts:
          - name: azure
            mountPath: /mnt/azure
      volumes:
        - name: azure
          azureDisk:
            kind: Managed
            diskName: datadisk1
            diskURI: $DISK_URI
            fsType: ext4
EOF

    CLUSTER_URI="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)"
    echo -e "\n\n************************************************************************\n"
    echo -e "\n--> Issue description: \n AKS cluster with pods in failed status on workload namespace\n"
    echo -e "Cluster uri == ${CLUSTER_URI}\n"
}

function lab_scenario_1_validation () {
    CLUSTER_NAME=aks-storage-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=${RESOURCE_GROUP:-aks-storage-ex${LAB_SCENARIO}-rg-${USER_ALIAS}}
    validate_cluster_exists $RESOURCE_GROUP $CLUSTER_NAME

    LAB_TAG="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query tags -o yaml 2>/dev/null | grep aks-storage-lab | cut -d ' ' -f2 | tr -d "'")"
    echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "--> Running validation for Lab scenario $LAB_SCENARIO\n"
    if [ -z $LAB_TAG ]
    then
        echo -e "\n--> Error: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    elif [ $LAB_TAG -eq $LAB_SCENARIO ]
    then
        az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME --overwrite-existing &>/dev/null
        NUMBER_OF_PODS="$(kubectl get po -n workload --field-selector=status.phase=Running | grep ^mydeployment | wc -l)"
        if [ $NUMBER_OF_PODS -ge 1 ]
        then
            echo -e "\n\n========================================================"
            echo -e "\nThe pods in $CLUSTER_NAME look good now\n"
        else
            echo -e "\nScenario $LAB_SCENARIO is still FAILED\n"
        fi
    else
        echo -e "\n--> Error: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    fi
}

# Lab scenario 2
function lab_scenario_2 () {
    CLUSTER_NAME=aks-storage-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=${RESOURCE_GROUP:-aks-storage-ex${LAB_SCENARIO}-rg-${USER_ALIAS}}
    
    #check_sku_availability "$SKU"
    check_resourcegroup_cluster $RESOURCE_GROUP $CLUSTER_NAME

    echo -e "\n--> Deploying cluster for lab${LAB_SCENARIO}...\n"
    az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --location $LOCATION \
    --node-count 3 \
    --node-vm-size "$SKU" \
    --generate-ssh-keys \
    --tag aks-storage-lab=${LAB_SCENARIO} \
	--yes \
    -o table

    validate_cluster_exists $RESOURCE_GROUP $CLUSTER_NAME
    
    echo -e "\n\n--> Please wait while we are preparing the environment for you to troubleshoot...\n"
    az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME --overwrite-existing &>/dev/null
    CLUSTER_URI="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)"

cat <<EOF | kubectl apply -f &>/dev/null -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azure-managed-disk
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: managed-premium
  resources:
    requests:
      storage: 5Gi
EOF
cat <<EOF | kubectl apply -f &>/dev/null -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cache
spec:
  selector:
    matchLabels:
      app: store
  replicas: 2
  template:
    metadata:
      labels:
        app: store
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - store
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: redis-server
        image: redis:3.2-alpine
        volumeMounts:
          - name: azure
            mountPath: /mnt/azure
      volumes:
        - name: azure
          persistentVolumeClaim:
            claimName: azure-managed-disk
EOF
    while true; do for s in / - \\ \|; do printf "\r$s"; sleep 1; done; done &
    sleep 40
    kill $!; trap 'kill $!' SIGTERM
    echo -e "\n\n********************************************************"
    echo -e "\n--> Issue description: \n Deployment redis-cache on default namespace has pods with issues\n"
    echo -e "Cluster uri == ${CLUSTER_URI}\n"
}

function lab_scenario_2_validation () {
    CLUSTER_NAME=aks-storage-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=${RESOURCE_GROUP:-aks-storage-ex${LAB_SCENARIO}-rg-${USER_ALIAS}}
    validate_cluster_exists $RESOURCE_GROUP $CLUSTER_NAME

    LAB_TAG="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query tags -o yaml 2>/dev/null | grep aks-storage-lab | cut -d ' ' -f2 | tr -d "'")"
    echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "--> Running validation for Lab scenario $LAB_SCENARIO\n"
    if [ -z $LAB_TAG ]
    then
        echo -e "\n--> Error: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    elif [ $LAB_TAG -eq $LAB_SCENARIO ]
    then
        az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME --overwrite-existing &>/dev/null
        REPLICAS_UNAVAILABLE="$(kubectl describe deploy redis-cache | grep ^Replicas | awk '{print $(NF-1)}')"
        if [ $REPLICAS_UNAVAILABLE -eq 0 ]
        then
            echo -e "\n\n========================================================"
            echo -e "\nThe redis-cache deployment looks good now\n"
        else
            echo -e "\nScenario $LAB_SCENARIO is still FAILED\n"
        fi
    else
        echo -e "\n--> Error: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    fi
}

#if -h | --help option is selected usage will be displayed
if [ $HELP -eq 1 ]
then
	print_usage_text
	exit 0
fi

if [ $VERSION -eq 1 ]
then
	echo -e "$SCRIPT_VERSION\n"
	exit 0
fi

if [ -z $LAB_SCENARIO ]; then
	echo -e "\n--> Error: Lab scenario value must be provided. \n"
	print_usage_text
	exit 9
fi

if [ -z $USER_ALIAS ]; then
	echo -e "Error: User alias value must be provided. \n"
	print_usage_text
	exit 10
fi

# lab scenario has a valid option
if [[ ! $LAB_SCENARIO =~ ^[1-2]+$ ]];
then
    echo -e "\n--> Error: invalid value for lab scenario '-l $LAB_SCENARIO'\nIt must be value from 1 to 2\n"
    exit 11
fi

# main
echo -e "\n--> AKS Troubleshooting sessions
********************************************

This tool will use your default subscription to deploy the lab environments.

--> Checking prerequisites...
Verifing if you are authenticated already...\n"

# Verify az cli has been authenticated
az_login_check

if [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 0 ]
then
    lab_scenario_1

elif [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_1_validation

elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 0 ]
then
    lab_scenario_2

elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_2_validation

elif [ $LAB_SCENARIO -eq 3 ] && [ $VALIDATE -eq 0 ]
then
    lab_scenario_3

elif [ $LAB_SCENARIO -eq 3 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_3_validation
else
    echo -e "\n--> Error: no valid option provided\n"
    exit 12
fi

exit 0