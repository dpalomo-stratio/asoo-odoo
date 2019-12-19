FROM debian:buster-slim
MAINTAINER Aselcis Consulting S.L. <info@aselcis.com>

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

ENV B_LOG_VERSION 0.4.7
ENV KM_UTILS_VERSION 0.4.7

RUN mkdir /opt/stratio

ADD http://sodio.stratio.com/repository/paas/kms_utils/${KM_UTILS_VERSION}/kms_utils-${KM_UTILS_VERSION}.sh /opt/stratio/kms_utils.sh
ADD http://sodio.stratio.com/repository/paas/log_utils/${B_LOG_VERSION}/b-log-${B_LOG_VERSION}.sh /opt/stratio/b-log.sh
ADD http://sodio.stratio.com/repository/paas/ansible/jq-linux64 /usr/sbin/jq

RUN chmod ugo+x /opt/stratio/b-log.sh && \
    chmod ugo+x /usr/sbin/jq && \
    chmod ugo+x /opt/stratio/kms_utils.sh

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            ca-certificates \
            curl \
            dirmngr \
            fonts-noto-cjk \
            gnupg \
            libssl-dev \
            node-less \
            npm \
            python3-num2words \
            python3-pip \
            python3-phonenumbers \
            python3-pyldap \
            python3-qrcode \
            python3-renderpm \
            python3-setuptools \
            python3-vobject \
            python3-watchdog \
            python3-xlwt \
            xz-utils \
        && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.stretch_amd64.deb \
        && echo '7e35a63f9db14f93ec7feeb0fce76b30c08f2057 wkhtmltox.deb' | sha1sum -c - \
        && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
        && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# install latest postgresql-client
RUN set -x; \
        echo 'deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main' > etc/apt/sources.list.d/pgdg.list \
        && export GNUPGHOME="$(mktemp -d)" \
        && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
        && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
        && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
        && gpgconf --kill all \
        && rm -rf "$GNUPGHOME" \
        && apt-get update  \
        && apt-get install -y postgresql-client \
        && rm -rf /var/lib/apt/lists/*

# Install rtlcss (on Debian buster)
RUN set -x; \
    npm install -g rtlcss

# Install Odoo
ENV ODOO_VERSION 13.0
ARG ODOO_RELEASE=20191025
ARG ODOO_SHA=d005d05fee244657fafb0a1ca5a9dad290574f1d
RUN set -x; \
        curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
        && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
        && dpkg --force-depends -i odoo.deb \
        && apt-get update \
        && apt-get -y install -f --no-install-recommends \
        && rm -rf /var/lib/apt/lists/* odoo.deb

# Install python requirements.txt
ADD ./requirements.txt /requirements.txt
RUN pip3 install -r /requirements.txt

# Override Odoo files
COPY ./odoo/sql_db.py /usr/lib/python3/dist-packages/odoo/sql_db.py
COPY ./odoo/config.py /usr/lib/python3/dist-packages/odoo/tools/config.py

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./config/odoo.conf /etc/odoo/
RUN chown odoo /etc/odoo/odoo.conf && \
    chown odoo /opt/stratio/b-log.sh && \
    chown odoo /opt/stratio/kms_utils.sh &&\
    chown odoo /usr/sbin/jq &&\
    chown -R odoo /usr/lib/python3/dist-packages/odoo

RUN chown -R odoo /opt/stratio/

COPY ./addons/Aselcis-Consulting/ /mnt/Aselcis-Consulting
COPY ./addons/enterprise/ /mnt/enterprise
COPY ./addons/extra-addons/ /mnt/extra-addons
COPY ./addons/OCA/ /mnt/OCA

RUN  chown -R odoo /mnt/extra-addons
RUN  chown -R odoo /mnt/Aselcis-Consulting
RUN  chown -R odoo /mnt/enterprise
RUN  chown -R odoo /mnt/OCA

VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8072

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Set default user when running the container

USER odoo
ENTRYPOINT ["/entrypoint.sh"]

CMD ["odoo"]
