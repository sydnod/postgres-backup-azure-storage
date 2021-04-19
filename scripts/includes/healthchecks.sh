#!/bin/sh

##########################################################################################
#
# Functions
#
##########################################################################################


export HEALTHCHECK_URL=$1

echo -n "Loading healthchecks..."

hc_start() {
    if [ ! -z "$HEALTHCHECK_URL" ]; then
        curl -fsS \
          --max-time 3 \
          --retry 3 \
          ${HEALTHCHECK_URL}/start > /dev/null
    fi
}

hc_success() {
    LOGGING_CONTENT=$(cat $LOGGING_OUTPUT_FILE 2>&1)

    if [ ! -z "$HEALTHCHECK_URL" ]; then
      curl -fsS \
        --max-time 3 \
        --retry 3 \
        -X POST --data-raw "${LOGGING_CONTENT}" ${HEALTHCHECK_URL} > /dev/null
    fi
}

hc_fail() {
    echo "fail"

    if [ ! -z "$HEALTHCHECK_URL" ]; then
      echo -n "\\nSending Healthcheck fail event..."
      curl -fsS \
        --max-time 3 \
        --retry 3 \
        ${HEALTHCHECK_URL}/fail > /dev/null && echo "done" || echo "fail"
    fi

    exit 1
}

echo "done"

# Start
hc_start
