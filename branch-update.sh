#! /bin/bash


# ==============================
# 	ENV and Bash Setup
# 	
# 	TODO: Pass an .env file instead of requiring a ton of arguments to be 
# 	passed to this script. It's way better for readability.
# ==============================

# DEV: Stop processing on errors + unbound variables.
set -eu

MERGE_IID=$1
ACTION=$2
OWNER=$3
REPO=$4
GITHUB_TOKEN=$5
WEB_DIRECTORY=$6
APP_CONTAINER_NAME=$7
MYSQL_CONTAINER_NAME=$8
DB_NAME=$9
REFERENCE_DB=${10}
MYSQL_USER=root
MYSQL_PASS=root


# ==============================
# 	Event Handling
# ==============================

cd "$WEB_DIRECTORY"

# DEV: Cleanup if the PR is no longer needed.
if [[ $ACTION == "closed" || $ACTION == "merged" ]]; then
	if [ -d "$MERGE_IID" ]; then
		echo "Merge Request $MERGE_IID closed; deleting branch directory..."
		sudo rm -rf "$MERGE_IID"

		echo "Removing database..."
		docker exec "$MYSQL_CONTAINER_NAME" sh -c \
			"mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'DROP SCHEMA $DB_NAME$MERGE_IID'"

		exit 0
	else
		echo "Error: Action is $ACTION, but the directory '$MERGE_IID' was missing."
	fi
fi

# DEV: If this is a new PR, setup the environment and directory.
if [ ! -d "$MERGE_IID" ]; then
	echo 'New merge request detected. Creating directory...'
    sudo mkdir "$MERGE_IID"

    echo 'Cloning repo into directory...'
    sudo git clone -q \
    	https://"$OWNER":"$GITHUB_TOKEN"@github.com/"$OWNER"/"$REPO".git "$MERGE_IID"

    cd "$MERGE_IID"

    echo 'Installing dependencies...'
    docker exec "$APP_CONTAINER_NAME" sh -c "cd web/$MERGE_IID && composer install"

    echo 'Cloning default .env file...'
    sudo cp ../default/.env .env
    sudo sed -i -e "s/DB_DATABASE=\(.*\)$/DB_DATABASE=$DB_NAME$MERGE_IID/" .env

    docker exec "$MYSQL_CONTAINER_NAME" sh -c \
    	"mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'CREATE DATABASE $DB_NAME$MERGE_IID'"

    docker exec "$MYSQL_CONTAINER_NAME" sh -c "\
    	mysqldump -u$MYSQL_USER -p$MYSQL_PASS $REFERENCE_DB | \
    	mysql -u$MYSQL_USER -p$MYSQL_PASS $DB_NAME$MERGE_IID"

    cd .. && sudo chown -R www-data:www-data "$MERGE_IID"/
fi

echo "Pulling the PR's commits into the directory..."
cd "$MERGE_IID" && sudo git pull origin pull/"$MERGE_IID"/head

# DEV: To keep things in sync, remove this file once it has run.
rm /home/ubuntu/branch-update.sh

exit 0
