#!/usr/bin/env bash

SCRIPT=$(realpath "${0}")
SCRIPTPATH=$(dirname "${SCRIPT}")

source "${SCRIPTPATH}/../session/.secret"

S3_FILE=$1
S3_KEY=$2

AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" aws s3 --endpoint-url "$S3_ENDPOINT" cp "$S3_FILE" "s3://$S3_BUCKET/${S3_KEY_PREFIX}${S3_KEY}"
