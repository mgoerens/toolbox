#!/bin/bash

# Usage: ./create_repo.sh <full_repo_name> --init_repo --install_helm --install_operator_sdk --install_oc --existing --kubeconfig=~/dev/kubeconfigs/my_kubeconfig
#
# Pre-requisites: direnv
# - direnv: Not packages for CentOS / RHEL system, see https://github.com/direnv/direnv/issues/362
# - gh: see https://github.com/cli/cli/blob/trunk/docs/install_linux.md

### Set default values
BASE_DIR="/home/mgoerens/dev"
INIT_REPO=false
INSTALL_HELM=false
INSTALL_OPERATOR_SDK=false
OPERATOR_SDK_VERSION=$(curl -s https://api.github.com/repos/operator-framework/operator-sdk/releases/latest | jq .name | tr -d \")
INSTALL_OC=false
EXISTING=false
REPO_FULL_NAME=""

### Parse arguments

# Get required repo name (also should matches the local directory structure)
if [ "$#" -lt 1 ]; then
  echo "Missing required repository name"
  ## TODO: print Usage (make a function)
  exit 1
fi

REPO_FULL_NAME="$1"
shift 1

while [ "$#" -gt 0 ]; do
  case "$1" in

    # TODO: Add possitibiity to clone existing repo (stop assuming this is the start of a project)
      --init_repo) INIT_REPO=true; shift 1;;
    --install_helm) INSTALL_HELM=true; shift 1;;
    --install_operator_sdk) INSTALL_OPERATOR_SDK=true; shift 1;;
    --install_operator_sdk=*) INSTALL_OPERATOR_SDK=true; OPERATOR_SDK_VERSION="${1#*=}"; shift 1;;
    --install_oc) INSTALL_OC=true; shift 1;;
    --existing) EXISTING=true; shift 1;;
    --kubeconfig=*) KUBECONFIG_PATH="${1#*=}"; shift 1;;
     
    *) echo "unknown option: $1" >&2; echo "Usage: ./create_repo.sh github.com/mgoerens/repo_name --init_repo --install_helm --install_operator_sdk --install_oc --existing --kubeconfig=~/dev/kubeconfigs/my_kubeconfig" && exit 1;;
  esac
done

### Arg validation
if [ ! -d $BASE_DIR ]; then
  echo "Base directory $BASE_DIR doesn't exist"
  exit 1
fi

FULL_REPO_PATH="$BASE_DIR/$REPO_FULL_NAME"

# Test if dir already exists
if [[ -d $FULL_REPO_PATH && ! "$EXISTING" ]]; then
  echo "Directory $REPO_FULL_NAME already exists in $BASE_DIR"
  exit 1
fi

REPO_MANAGER=$(cut -d / -f 1 <<< "$REPO_FULL_NAME")
REPO_ORG_NAME=$(cut -d / -f 2 <<< "$REPO_FULL_NAME")
REPO_NAME=$(cut -d / -f 3 <<< "$REPO_FULL_NAME")
SHOULD_NOT_UNPACKED=$(cut -d / -f 4 <<< "$REPO_FULL_NAME")
if [[ -z "$REPO_MANAGER" || -z "$REPO_ORG_NAME" || -z "$REPO_NAME" || -n "$SHOULD_NOT_UNPACKED" ]]; then
  echo "Malformatted repository name. Should be for instance \"gitlab.com/my_org/my_project\""
  exit 1
fi

if [[ ! "$REPO_MANAGER" == "github.com" && ! "$REPO_MANAGER" == "gitlab.com" ]]; then
  echo "Unsupported repository manager. Use github.com or gitlab.com."
  exit 1
fi

### Create dir, init repo, install packages, and configure direnv

echo "----Create basic directory structure and add binary directory in .envrc"

if ! $EXISTING; then
  echo "Creating $FULL_REPO_PATH"
  mkdir -p "$FULL_REPO_PATH"
  cd "$FULL_REPO_PATH" || exit
  git init

  if $INIT_REPO; then
    echo "Creating repository $REPO_FULL_NAME"
    case "$REPO_MANAGER" in
      github.com)
        # This automatically creates the repo and adds the new remote
        # TODO: automatic login
        gh repo create --private -y "$REPO_ORG_NAME"/"$REPO_NAME";;
      gitlab.com)
        # This only adds the new remote. The repo will actually be created at the first push
        git remote add origin git@"$REPO_FULL_NAME".git;;
    esac
  fi

else
  cd "$FULL_REPO_PATH" || exit
fi

# TODO: only create .bin if necessary
mkdir "$FULL_REPO_PATH/.bin"
echo "export PATH=\$PATH:$FULL_REPO_PATH/.bin" >> .envrc

GIT_EXCLUDE_PATH="$FULL_REPO_PATH/.git/info/exclude"
if [ -f "$GIT_EXCLUDE_PATH" ]; then
  echo ".bin" >> "$GIT_EXCLUDE_PATH"
  echo ".envrc" >> "$GIT_EXCLUDE_PATH"
fi

direnv allow

# TODO: set helm version
if $INSTALL_HELM; then
  echo "----Install Helm"
  
  # Download binary
  wget https://get.helm.sh/helm-v3.6.0-linux-amd64.tar.gz
  tar -zxvf helm-v3.6.0-linux-amd64.tar.gz 
  mv linux-amd64/helm .bin/
  rm -rf linux-amd64/
#  helm version
  rm helm-v3.6.0-linux-amd64.tar.gz

  # TODO: NOT TESTED
  # if [ -f $FULL_REPO_PATH/.helmignore ]; then
  #   echo ".bin/" >> $FULL_REPO_PATH/.helmignore
  #   echo ".envrc" >> $FULL_REPO_PATH/.helmignore
  #   echo "KUBECONFIG" >> $FULL_REPO_PATH/.helmignore
  # fi

  # Configure direnv
  # TODO: check Helm cache path
fi

# Adapted procedure from: https://sdk.operatorframework.io/docs/installation/
if $INSTALL_OPERATOR_SDK; then
  echo "----Install the Operator SDK"
  echo "----Version: $OPERATOR_SDK_VERSION"

  # Download binary
  ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n "$(uname -m)" ;; esac)
  OS=$(uname | awk '{print tolower($0)}')
  OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}
  curl -LO "${OPERATOR_SDK_DL_URL}"/operator-sdk_"${OS}"_"${ARCH}"
  gpg --keyserver keyserver.ubuntu.com --recv-keys 052996E2A20B5C7E
  curl -LO "${OPERATOR_SDK_DL_URL}"/checksums.txt
  curl -LO "${OPERATOR_SDK_DL_URL}"/checksums.txt.asc
  gpg -u "Operator SDK (release) <cncf-operator-sdk@cncf.io>" --verify checksums.txt.asc
  grep operator-sdk_"${OS}"_"${ARCH}" checksums.txt | sha256sum -c -
  chmod +x operator-sdk_"${OS}"_"${ARCH}" && mv operator-sdk_"${OS}"_"${ARCH}" .bin/operator-sdk
  rm checksums.txt*
fi

if $INSTALL_OC; then
  echo "----Install oc"

  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
  tar -zxvf openshift-client-linux.tar.gz -C .bin/
  rm openshift-client-linux.tar.gz .bin/README.md

  echo "source <(kubectl completion bash)" >> .envrc
fi

if [ "$KUBECONFIG_PATH" ]; then
  cp -v "$KUBECONFIG_PATH" "$FULL_REPO_PATH/KUBECONFIG"
  chmod 600 "$FULL_REPO_PATH/KUBECONFIG"
  echo "export KUBECONFIG=$FULL_REPO_PATH/KUBECONFIG" >> .envrc
  direnv allow
  if [ -f "$GIT_EXCLUDE_PATH" ]; then
    echo "KUBECONFIG" >> "$GIT_EXCLUDE_PATH"
  fi
fi
