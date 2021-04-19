#!/bin/sh

LOGGING_OUTPUT_FILE="/tmp/__output.log"
export LOGGING_OUTPUT_FILE=$LOGGING_OUTPUT_FILE

. ./scripts/postgres-backup.sh 2>&1 | tee $LOGGING_OUTPUT_FILE
