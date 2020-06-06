#!/usr/bin/env sh

COMMIT_MSG_FILE=$1

BRANCH_NAME=$(git symbolic-ref --short HEAD)
COMMIT_MSG=$(cat "${COMMIT_MSG_FILE}")
printf "[%s] %s" "${BRANCH_NAME}" "${COMMIT_MSG}" > "${COMMIT_MSG_FILE}"
