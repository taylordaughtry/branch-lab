#! /bin/bash

set -eu

# TODO: Source .env these instead of passing a thousand params?
MERGE_IID=$1
ACTION=$2
OWNER=$3
REPO=$4
GITHUB_TOKEN=$5
WEB_DIRECTORY=$6 # DEV: The directory where you'd like PRs to be served from, as well as the 'root' site.
APP_CONTAINER_NAME=$7 # DEV: The Docker container where your app lives. (For composer installation)
MYSQL_CONTAINER_NAME=$8 # DEV: The Docker container where MySQL is running. (To manage independent PR DBs)
DB_NAME=$9 # DEV: The prefix of each PR's DB. (i.e. project_[$PR_ID])
REFERENCE_DB=${10} # DEV: The DB that all PRs should clone when being created. # TODO: Remove this when source .env is added

# TODO: Abstract to ENV for usage across all projects
MYSQL_USER=root
MYSQL_PASS=root

cd $WEB_DIRECTORY

if [[ $ACTION == "closed" || $ACTION == "merged" ]]; then
	if [ -d "$MERGE_IID" ]; then
		echo "Merge Request $MERGE_IID closed; deleting branch directory..."
		sudo rm -rf $MERGE_IID

		echo "Removing database..."
		docker exec $MYSQL_CONTAINER_NAME sh -c "mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'DROP SCHEMA $DB_NAME$MERGE_IID'"

		exit 0
	else
		echo "Action was $ACTION, but no directory matching IID $MERGE_IID was found."
	fi
fi

# DEV: If this Merge Request is new, create a directory
# for it and populate it with the project repo.
if [ ! -d "$MERGE_IID" ]; then
	echo 'New merge request detected. Creating directory...'
    sudo mkdir $MERGE_IID

    echo 'Cloning repo into directory...'
    sudo git clone -q https://$OWNER:$GITHUB_TOKEN@github.com/$OWNER/$REPO.git $MERGE_IID

    cd $MERGE_IID

    echo 'Installing dependencies...'
    docker exec $APP_CONTAINER_NAME sh -c "cd web/$MERGE_IID && composer install"

    echo 'Cloning default .env file...'
    sudo cp ../default/.env .env
    sudo sed -i -e "s/DB_DATABASE=\(.*\)$/DB_DATABASE=$DB_NAME$MERGE_IID/" .env

    docker exec $MYSQL_CONTAINER_NAME sh -c "mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'CREATE DATABASE $DB_NAME$MERGE_IID'"

    docker exec $MYSQL_CONTAINER_NAME sh -c "mysqldump -u$MYSQL_USER -p$MYSQL_PASS $REFERENCE_DB | mysql -u$MYSQL_USER -p$MYSQL_PASS $DB_NAME$MERGE_IID"

    cd .. && sudo chown -R www-data:www-data $MERGE_IID/

	# curl -X POST \
	# 	https://api.github.com/repos/$OWNER/$REPO/issues/$MERGE_IID/comments \
	# 	-H "Authorization: Bearer $GITHUB_TOKEN" \
	# 	-d '{"body": "**Branch Lab\n\nA new lab has been created for this Pull Request. You can view it here: [TODO]"}'
fi

echo "Pulling the PR's commits into the directory..."
cd $MERGE_IID && sudo git pull origin pull/$MERGE_IID/head

rm /home/ubuntu/branch-update.sh

echo 'Complete.'

exit 0
