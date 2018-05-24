#!/bin/sh
set -ue

SWAP_SIZE=${SWAP_SIZE:-"4"}
SWAP_LEVEL=${SWAP_LEVEL:-"10"}

ARTIFACT_STORAGE=${ARTIFACT_STORAGE:-"/storage/artifacts"}
REGISTRY_STORAGE=${REGISTRY_STORAGE:-"/storage/registry"}

GITLAB_CONFIG='/etc/gitlab/gitlab.rb'

############################################## CREATE SWAP ####################################################

# Create swap (default to 8G)
if ! swapon -s | grep /swapfile; then
  echo "No swapfile, create and enable"
  fallocate -l "${SWAP_SIZE}G" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  cp /etc/fstab /etc/fstab.bak
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Set default swappiness to 10
cat /proc/sys/vm/swappiness

sudo sysctl vm.swappiness=${SWAP_LEVEL}
echo 'vm.swappiness=${SWAP_LEVEL}' | sudo tee -a /etc/sysctl.conf

#################################################################################################################

appendConfig() {
  grep_search=$1
  content_config=$2
  # append if not found this setting in config file
  if ! grep "^${grep_search}" ${GITLAB_CONFIG}; then
    echo "Append this setting to ${GITLAB_CONFIG}:"
    echo "${content_config}"
    cat >>${GITLAB_CONFIG}<<EOL
${content_config}
EOL
  fi
}

# setup external url
if ! [ -z ${EXT_URL+x} ]; then
  appendConfig "external_url" "external_url \"${EXT_URL}\""
fi

# setup for registry url
if ! [ -z ${REG_EXT_URL+x} ]; then
  appendConfig "registry_external_url" "registry_external_url \"${REG_EXT_URL}\""
  appendConfig "gitlab_rails\['registry_enabled'\]" "gitlab_rails['registry_enabled'] = true"
  appendConfig "gitlab_rails\['registry_host'\]" "gitlab_rails['registry_host'] = \"${REG_EXT_URL}\""
fi

# if use cloudfare as a proxy
if ! [ -z ${CLOUDFARE+x} ]; then
  if [ "$CLOUDFARE" = "true" ]; then
    # if using gitlab domain with SSL under Cloudfare, should pass this env
    appendConfig "nginx\['listen_port'\]" "nginx['listen_port'] = 80"
    appendConfig "nginx\['listen_https'\]" "nginx['listen_https'] = false"
    appendConfig "registry_nginx\['listen_port'\]" "registry_nginx['listen_port'] = 80"
    appendConfig "registry_nginx\['listen_https'\]" "registry_nginx['listen_https'] = false"
  fi
fi

# setup storage for registry & artifacts
mkdir -p ${ARTIFACT_STORAGE} || true
mkdir -p ${REGISTRY_STORAGE} || true
appendConfig "gitlab_rails\['artifacts_enabled'\]" "gitlab_rails['artifacts_enabled'] = true"
appendConfig "gitlab_rails\['artifacts_path'\]" "gitlab_rails['artifacts_path'] = \"${ARTIFACT_STORAGE}\""
appendConfig "gitlab_rails\['registry_path'\]" "gitlab_rails['registry_path'] = \"${REGISTRY_STORAGE}\""

#################################################################################################################

# setup OAuth app for gitlab.com
if ! [ -z ${GITLAB_APP_ID+x} ] && ! [ -z ${GITLAB_APP_SECRET+x} ]; then
  setting=$(cat <<EOF
gitlab_rails['omniauth_providers'] = [
  {
    "name" => "gitlab",
    "app_id" => "${GITLAB_APP_ID}",
    "app_secret" => "${GITLAB_APP_SECRET}",
    "args" => { "scope" => "api" }
  }
]
EOF
)
  appendConfig "gitlab_rails\['omniauth_providers'\]" "${setting}"
fi

#################################################################################################################

echo "Final config for gitlab"
cat /etc/gitlab/gitlab.rb

echo "DONE SETUP for gitlab server"

