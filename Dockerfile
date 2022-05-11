FROM postgres:13
WORKDIR /app

ARG SOURCE_TYPE="postgres"
ARG SOURCE_NAME="undefined"
ARG SOURCE_HOSTNAME="localhost"
ARG SOURCE_USERNAME="root"
ARG SOURCE_PASSWORD="root"
ARG DESTINATION_AZURE_STORAGE_CONTAINER_NAME="backup"
ARG DESTINATION_AZURE_STORAGE_ACCOUNT=""
ARG DESTINATION_AZURE_STORAGE_KEY=""
ARG ENCRYPTION_PASSPHRASE="1234"
ARG INTEGRATION_HEALTHCHECKSIO_URL

ENV SOURCE_TYPE=$SOURCE_TYPE
ENV SOURCE_NAME=$SOURCE_NAME
ENV SOURCE_HOSTNAME=$SOURCE_HOSTNAME
ENV SOURCE_USERNAME=$SOURCE_USERNAME
ENV SOURCE_PASSWORD=$SOURCE_PASSWORD
ENV DESTINATION_AZURE_STORAGE_CONTAINER_NAME=$DESTINATION_AZURE_STORAGE_CONTAINER_NAME
ENV DESTINATION_AZURE_STORAGE_ACCOUNT=$DESTINATION_AZURE_STORAGE_ACCOUNT
ENV DESTINATION_AZURE_STORAGE_KEY=$DESTINATION_AZURE_STORAGE_KEY
ENV ENCRYPTION_PASSPHRASE=$ENCRYPTION_PASSPHRASE
ENV INTEGRATION_HEALTHCHECKSIO_URL=$INTEGRATION_HEALTHCHECKSIO_URL

COPY ./scripts/ scripts/

# Update apt sources
RUN apt update

# Install deps
RUN apt install curl zip --yes

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Make executable
RUN chmod -R +x ./scripts

ENTRYPOINT [ "/app/scripts/entrypoint.sh" ]