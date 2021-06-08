#/bin/bash

# Usage: ./create_repo.sh --name=<repo_name> --install_go --install_helm --install_operator_sdk --install_oc --existing
#
# Pre-requisites: direnv
# - direnv: Not packages for CentOS / RHEL system, see https://github.com/direnv/direnv/issues/362


### Set default values
BASE_DIR="/home/mgoerens/dev"
INSTALL_GO=false
INSTALL_HELM=false
INSTALL_OPERATOR_SDK=false
INSTALL_OC=false
EXISTING=false

### Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    -n) REPO_NAME="$2"; shift 2;;
    -g) INSTALL_GO=true; shift 1;;
    -h) INSTALL_HELM=true; shift 1;;
    -o) INSTALL_OPERATOR_SDK=true; shift 1;;
    -c) INSTALL_OC=true; shift 1;;
    -e) EXISTING=true; shift 1;;

    --name=*) REPO_NAME="${1#*=}"; shift 1;;
    --install_go) INSTALL_GO=true; shift 1;;
    --install_helm) INSTALL_HELM=true; shift 1;;
    --install_operator_sdk) INSTALL_OPERATOR_SDK=true; shift 1;;
    --install_oc) INSTALL_OC=true; shift 1;;
    --existing) EXISTING=true; shift 1;;
     
    *) echo "unknown option: $1" >&2; echo "Usage: ./create_repo.sh --name=<repo_name> --install_go --install_helm --install_operator_sdk --install_oc" && exit 1;;
#    *) handle_argument "$1"; shift 1;;
  esac
done

### Arg validation
if [ ! -d $BASE_DIR ]; then
  echo "Base directory $BASE_DIR doesn't exist"
  exit 1
fi

if [ -z $REPO_NAME ]; then
  echo "Name of the repo to create missing"
  exit 1
fi

FULL_REPO_PATH="$BASE_DIR/$REPO_NAME"

# Test if repo already exists
if [[ -d $FULL_REPO_PATH && ! $EXISTING ]]; then
  echo "Directory $REPO_NAME already exists in $BASE_DIR"
  exit 1
fi

### Create repository, install packages, and configure direnv

echo "----Create basic directory structure and add binary directory in .envrc"

if [ ! $EXISTING ]; then
  mkdir $FULL_REPO_PATH
fi
cd $FULL_REPO_PATH
mkdir "$FULL_REPO_PATH/bin"
echo "export PATH=\$PATH:$FULL_REPO_PATH/bin" >> .envrc
direnv allow

GIT_EXCLUDE_PATH="$FULL_REPO_PATH/.git/info/exclude"

echo $GIT_EXCLUDE_PATH

if [ -f $GIT_EXCLUDE_PATH ]; then
  echo "bin" >> $GIT_EXCLUDE_PATH
  echo ".direnv" >> $GIT_EXCLUDE_PATH
fi


# Adapted procedure from https://golang.org/doc/install and https://linuxize.com/post/how-to-install-go-on-ubuntu-20-04/
# TODO: set go version
if $INSTALL_GO; then
  echo "----Install Go and configure .direnv accordingly"

  # Downlod Go
  wget https://golang.org/dl/go1.16.4.linux-amd64.tar.gz
  tar -zxvf go1.16.4.linux-amd64.tar.gz
  rm go1.16.4.linux-amd64.tar.gz

  # Configure direnv
  echo "layout go" >> .envrc
  echo "export PATH=\$PATH:$FULL_REPO_PATH/go/bin" >> .envrc
  direnv allow
fi

# TODO: set go version
if $INSTALL_HELM; then
  echo "----Install Helm"
  
  # Download binary
  wget https://get.helm.sh/helm-v3.6.0-linux-amd64.tar.gz
  tar -zxvf helm-v3.6.0-linux-amd64.tar.gz 
  mv linux-amd64/helm bin/
  rm -rf linux-amd64/
#  helm version
  rm helm-v3.6.0-linux-amd64.tar.gz

  # Configure direnv
  # TODO: check Helm cache path
fi

# Adapted procedure from: https://sdk.operatorframework.io/docs/installation/
if $INSTALL_OPERATOR_SDK; then
  echo "----Install the Operator SDK"

  # Download binary
  export ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(uname -m) ;; esac)
  export OS=$(uname | awk '{print tolower($0)}')
  export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/download/v1.8.0
  curl -LO ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
  gpg --keyserver keyserver.ubuntu.com --recv-keys 052996E2A20B5C7E
  curl -LO ${OPERATOR_SDK_DL_URL}/checksums.txt
  curl -LO ${OPERATOR_SDK_DL_URL}/checksums.txt.asc
  gpg -u "Operator SDK (release) <cncf-operator-sdk@cncf.io>" --verify checksums.txt.asc
  grep operator-sdk_${OS}_${ARCH} checksums.txt | sha256sum -c -
  chmod +x operator-sdk_${OS}_${ARCH} && mv operator-sdk_${OS}_${ARCH} bin/operator-sdk
  rm checksums.txt*
fi

# TODO: https://kubernetes.io/docs/reference/kubectl/cheatsheet/#kubectl-autocomplete
if $INSTALL_OC; then
  echo "----Install oc"

  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
  tar -zxvf openshift-client-linux.tar.gz -C bin/
  rm openshift-client-linux.tar.gz bin/README.md
fi

