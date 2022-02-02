#!/bin/bash
#set -exo pipefail
set -fxe -o pipefail

FILTER=$1
if [[ "${FILTER}" == "" ]]; then
  FILTER="emvn-prod"
fi
names=$(docker ps --format "{{.Names}}" -qf "name=${FILTER}")
echo "tailing $names"

while read -r name
do
  # eval to show container name in jobs list
  # eval "docker logs -f --tail=500 \"$name\" | sed -e \"s/^/[-- $name --] /\" &"
  # For Ubuntu 16.04
  eval "docker logs -f --tail=500 \"$name\" |& sed -e \"s/^/[-- $name --] /\" &"
done <<< "$names"

function _exit {
  echo
  echo "Stopping tails $(jobs -p | tr '\n' ' ')"
  echo "..."

  # Using `sh -c` so that if some have exited, that error will
  # not prevent further tails from being killed.
  jobs -p | tr '\n' ' ' | xargs -I % sh -c "kill % || true"

  echo "Done"
}

# On ctrl+c, kill all tails started by this script.
# trap _exit EXIT

# For Ubuntu 16.04
trap _exit INT

# Don't exit this script until ctrl+c or all tails exit.
wait
