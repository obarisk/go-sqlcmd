#------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
#------------------------------------------------------------------------------

# Example:
# docker run -it microsoft/sqlcmd ./sqlcmd --help
#

FROM debian:stable-slim AS build-env
ARG BUILD_DATE
ARG PACKAGE_VERSION

LABEL maintainer="Microsoft" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.vendor="Microsoft" \
      org.label-schema.name="SQLCMD CLI" \
      org.label-schema.version=$PACKAGE_VERSION \
      org.label-schema.license="https://github.com/microsoft/go-sqlcmd/blob/main/LICENSE" \
      org.label-schema.description="The MSSQL SQLCMD CLI tool" \
      org.label-schema.url="https://github.com/microsoft/go-sqlcmd" \
      org.label-schema.usage="https://docs.microsoft.com/sql/tools/sqlcmd-utility" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.docker.cmd="docker run -it microsoft/sqlcmd:$PACKAGE_VERSION"

RUN apt-get update
RUN apt-get install -y locales

# Locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8

COPY ./sqlcmd sqlcmd
