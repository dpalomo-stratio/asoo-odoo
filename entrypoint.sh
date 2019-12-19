#!/bin/bash

source /opt/stratio/kms_utils.sh
source /opt/stratio/b-log.sh
B_LOG --stdout true

INFO "Start application"

declare -a VAULT_HOSTS
IFS_OLD=$IFS
IFS=',' read -r -a VAULT_HOSTS <<< "$VAULT_HOST"

declare -a MARATHON_ARRAY
OLD_IFS=$IFS
IFS='/' read -r -a MARATHON_ARRAY <<< "$MARATHON_APP_ID"
IFS=$OLD_IFS

INFO "Dynamic login with vault"
if login; then
    INFO "Vault login successful"
else
    ERROR "Vault login failed"
    exit 1
fi

export MARATHON_SERVICE_NAME=${MARATHON_ARRAY[-1]}
export SPRING_APPLICATION_NAME=${MARATHON_SERVICE_NAME}

#2 Get certs for postgres

export POSTGRES_URL=${DATASOURCE_URL}
export POSTGRES_EVENTRA=${POSTGRES_EVENTRA}

export SPRING_DATASOURCE_USERNAME=${POSTGRES_USERNAME}
export EVENTRA_DATASOURCE_USERNAME=${POSTGRES_USERNAME}

export POSTGRES_CERT="/opt/stratio/${MARATHON_SERVICE_NAME}.pem"
export POSTGRES_KEY="/opt/stratio/key.pkcs8"
export CA_BUNDLE_PEM="/opt/stratio/ca-bundle.pem"

INFO " Posgres URL - ${POSTGRES_URL}"
INFO " Posgres User - ${POSTGRES_USERNAME}"
INFO "OK: Getting marathon service name: ${MARATHON_SERVICE_NAME}"

getCert "userland" \
       ${MARATHON_SERVICE_NAME} \
       ${MARATHON_SERVICE_NAME} \
        "PEM" \
        "/opt/stratio" \
&& echo "OK: Getting ${MARATHON_SERVICE_NAME} certificate for postgres" \
|| echo "Error: Getting ${MARATHON_SERVICE_NAME} certificate for postgres"

getCAbundle "/opt/stratio" "PEM" \
&& echo "OK: Getting ca-bundle for postgres"   \
|| echo "Error: Getting ca-bundle for postgres"

echo "Datasource ${DATASOURCE_URL} connection for postgres"

HOST=${DATASOURCE_URL}
: ${PORT:=5432}}
USER=${POSTGRES_USERNAME}
PASSWORD=${POSTGRES_PASSWORD}

INFO " odoo db URL - ${HOST}"
INFO " odoo db port - ${PORT}"
INFO " odoo db user - ${USER}"
INFO " odoo db pass - ${PASSWORD}"

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if ! grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then
        DB_ARGS+=("--${param}")
        DB_ARGS+=("${value}")
   fi;
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1
