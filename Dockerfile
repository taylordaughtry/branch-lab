FROM alpine

MAINTAINER Taylor Daughtry <taylor@vectormediagroup.com>

LABEL "com.github.actions.name"="Branch Lab"
LABEL "com.github.actions.description"="Manage discrete webroots for merge requests"
LABEL "com.github.actions.icon"="git-pull-request"
LABEL "com.github.actions.color"="red"

RUN apk add jq openssh-client

ADD entrypoint.sh /entrypoint.sh
ADD branch-update.sh /branch-update.sh

ENTRYPOINT ["/entrypoint.sh"]
