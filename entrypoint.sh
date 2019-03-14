#!/bin/sh

# TODO: Post a comment in the PR notifying everybody of creation/update/deletion
# when Branch Lab runs. Use the GitHub API for this; Actions have a context.

# DEV: Make Bash a bit more like higher-order languages. (Bail on error, no
# unset vars)
set -eu

SSH_PATH="$HOME/.ssh"

mkdir "$SSH_PATH"
touch "$SSH_PATH/known_hosts"

echo "$PRIVATE_KEY" > "$SSH_PATH/id_rsa"

chmod 700 "$SSH_PATH"
chmod 400 "$SSH_PATH/known_hosts"
chmod 400 "$SSH_PATH/id_rsa"

eval $(ssh-agent)
ssh-add "$SSH_PATH/id_rsa"

ssh-keyscan -t rsa $HOST >> "$SSH_PATH/known_hosts"

cd /

REQUEST_ID=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")

ACTION=$(jq --raw-output .action "$GITHUB_EVENT_PATH")

OWNER=$(jq --raw-output .repository.owner.login "$GITHUB_EVENT_PATH")

REPO=$(jq --raw-output .repository.name "$GITHUB_EVENT_PATH")

if [ -z $ACTION ]; then
	MERGED=$(jq --raw-output .pull_request.merged "$GITHUB_EVENT_PATH")

	if [ "$MERGED" == "true" ]; then
		ACTION="merged"
	fi
fi

# DEV: This would be updated for VMG staging.
scp -o 'StrictHostKeyChecking=no' branch-update.sh $USER@$HOST:"/home/ubuntu"

ssh -A -tt -o 'StrictHostKeyChecking=no' -p ${PORT:-22} $USER@$HOST "bash /home/ubuntu/branch-update.sh $REQUEST_ID $ACTION $OWNER $REPO $GITHUB_TOKEN $WEB_DIRECTORY $APP_CONTAINER_NAME $MYSQL_CONTAINER_NAME $DB_NAME_PREFIX $REFERENCE_DB"

echo 'Success!'

exit 0
