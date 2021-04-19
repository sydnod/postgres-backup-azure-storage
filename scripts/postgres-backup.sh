#!/bin/sh

##########################################################################################
#
# Basic configuration
#
##########################################################################################

# Source
SOURCE_TYPE=$SOURCE_TYPE
SOURCE_NAME=$SOURCE_NAME
SOURCE_HOSTNAME=$SOURCE_HOSTNAME
SOURCE_USERNAME=$SOURCE_USERNAME
SOURCE_PASSWORD=$SOURCE_PASSWORD

# Destination
DESTINATION_AZURE_STORAGE_CONTAINER_NAME=$DESTINATION_AZURE_STORAGE_CONTAINER_NAME
DESTINATION_AZURE_STORAGE_ACCOUNT=$DESTINATION_AZURE_STORAGE_ACCOUNT
DESTINATION_AZURE_STORAGE_KEY=$DESTINATION_AZURE_STORAGE_KEY

# Encryption
ENCRYPTION_PASSPHRASE=$ENCRYPTION_PASSPHRASE

##########################################################################################
#
# Integrations
#
##########################################################################################

INTEGRATION_HEALTHCHECKSIO_URL=$INTEGRATION_HEALTHCHECKSIO_URL

##########################################################################################
#
# Advanced configuration
#
##########################################################################################

# Encryption
ENCRYPTION_METHOD="aes-256-cbc"
ENCRYPTION_ARGS="-md sha512 -pbkdf2 -iter 100000"

# Helpers
DATE_YYYYMMDDHHMMSS=$(date '+%Y%m%d%H%M%S')

# Backup names
BACKUP_NAME="${SOURCE_NAME}-${DATE_YYYYMMDDHHMMSS}"
BACKUP_NAME_OUTPUT="${BACKUP_NAME}.sql"
BACKUP_NAME_COMPRESSED="${BACKUP_NAME}.tar.gz"
BACKUP_NAME_ENCRYPTED="${BACKUP_NAME}-${ENCRYPTION_METHOD}.gz.enc"
BACKUP_DESTINATION_TMP="/backup/postgres"

##########################################################################################
#
# Script below
#
##########################################################################################

echo -e "SCRIPT: Start\\n"

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# Includes
. ${SCRIPTPATH}/includes/healthchecks.sh $INTEGRATION_HEALTHCHECKSIO_URL

# Exports
export AZURE_STORAGE_ACCOUNT=$DESTINATION_AZURE_STORAGE_ACCOUNT
export AZURE_STORAGE_KEY=$DESTINATION_AZURE_STORAGE_KEY

# Remove backup directory
rm -rf $BACKUP_DESTINATION_TMP

# Make directorys
mkdir -p ${BACKUP_DESTINATION_TMP} > /dev/null
mkdir -p ${BACKUP_DESTINATION_TMP}/package > /dev/null

echo
if [ $SOURCE_TYPE = "postgres" ]; then
    echo -e "Backup source: Postgres\\n"

    # Set Postgres password
    export PGPASSWORD="$SOURCE_PASSWORD"

    # Get databases
    POSTGRES_DATABASES=$(\
      psql \
      --host $SOURCE_HOSTNAME \
      --username $SOURCE_USERNAME \
      --list \
      -c "select schema_name from information_schema.schemata" -At | \
      egrep -E -i -w '(.*)\|' | cut -d '|' -f1 | grep -E -v '(template0|template1)')

    for POSTGRES_DATABASE in $POSTGRES_DATABASES; do

        echo -n "Backup of '${POSTGRES_DATABASE}'..."
        pg_dump \
          --host $SOURCE_HOSTNAME \
          --username $SOURCE_USERNAME \
          -d $POSTGRES_DATABASE \
          > "${BACKUP_DESTINATION_TMP}/${POSTGRES_DATABASE}-${BACKUP_NAME_OUTPUT}"

        echo "done"
    done
    echo

    # Tar all files
    echo -n "Packaging..."
    tar cvzf ${BACKUP_DESTINATION_TMP}/$BACKUP_NAME_COMPRESSED ${BACKUP_DESTINATION_TMP}/*${BACKUP_NAME_OUTPUT} > /dev/null 2>&1 && echo done || hc_fail

    # Remove source backup files
    rm -rf ${BACKUP_DESTINATION_TMP}/*${BACKUP_NAME_OUTPUT}

    # Encrypt
    echo -n "Encrypting..."
    openssl enc \
      -${ENCRYPTION_METHOD} ${ENCRYPTION_ARGS} \
      -salt \
      -in ${BACKUP_DESTINATION_TMP}/${BACKUP_NAME_COMPRESSED} \
      -out ${BACKUP_DESTINATION_TMP}/package/${BACKUP_NAME_ENCRYPTED} \
      -k ${ENCRYPTION_PASSPHRASE} 2>&1 > /dev/null && echo done || hc_fail

    # Remove compressed backup files
    rm -rf ${BACKUP_DESTINATION_TMP}/*${BACKUP_NAME_COMPRESSED}

    # Decryption command
    DECRYPTION_COMMAND="openssl ${ENCRYPTION_METHOD} ${ENCRYPTION_ARGS} -d -in ${BACKUP_NAME_ENCRYPTED} -out ${BACKUP_NAME_COMPRESSED} -k <decryption password>"
    RESTORE_COMMAND="PGPASSWORD=<restore_password> postgres --host ${SOURCE_HOSTNAME} --username sa.ops.restore -d <database> < [/path/to/backup]*.sql"

    # Write a message along with the encrypted file
    echo -e "Backup\\n\\nTarget:     ${SOURCE_NAME}\\nGenerated:  $(date '+%Y-%m-%d %H:%M:%S')\\n\\n# Decrypt\n${DECRYPTION_COMMAND}\\n\\n# Restore\n${RESTORE_COMMAND}\\n\\nSydnod Operations" > ${BACKUP_DESTINATION_TMP}/package/${BACKUP_NAME}.txt

    # Zip the final files
    echo -n "Zipping..."
    BACKUP_NAME_FINAL="${BACKUP_NAME}.zip"
    zip ${BACKUP_DESTINATION_TMP}/$BACKUP_NAME_FINAL ${BACKUP_DESTINATION_TMP}/package/* 2>&1 > /dev/null && echo done || hc_fail

    echo -n "Creating destination container..."
    az storage container create \
      --name $DESTINATION_AZURE_STORAGE_CONTAINER_NAME \
      2>&1 > /dev/null && echo done || hc_fail

    echo -e "\\nUploading the file to Azure storage..."
    az storage blob upload --container-name $DESTINATION_AZURE_STORAGE_CONTAINER_NAME --file ${BACKUP_DESTINATION_TMP}/${BACKUP_NAME_FINAL} --name ${BACKUP_NAME_FINAL} \
       2>&1 > /dev/null && hc_success || hc_fail

    echo -e "\\nUpload of '${BACKUP_NAME_FINAL}' successfully completed!"

fi

# Remove backup directory
rm -rf $BACKUP_DESTINATION_TMP

echo -e "\\nSCRIPT: Done"
