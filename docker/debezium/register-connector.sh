#!/bin/sh
set -eu

: "${DEBEZIUM_CONNECT_URL:=http://debezium:8083}"
: "${DEBEZIUM_DB_HOST:=postgres}"
: "${DEBEZIUM_DB_PORT:=5432}"

export PGPASSWORD="$DEBEZIUM_PASSWORD"

echo "Waiting for Kafka Connect REST API..."
attempt=0
until curl -fsS "${DEBEZIUM_CONNECT_URL}/connectors" >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 90 ]; then
        echo "Kafka Connect REST API did not become available within 180 seconds." >&2
        exit 1
    fi
    sleep 2
done

echo "Waiting for PostgreSQL publication converter.outbox..."
attempt=0
while :; do
    result="$(
        psql \
          --host="$DEBEZIUM_DB_HOST" \
          --port="$DEBEZIUM_DB_PORT" \
          --username="$DEBEZIUM_DB_USER" \
          --dbname="$DEBEZIUM_DB_NAME" \
          --no-psqlrc \
          --tuples-only \
          --no-align \
          --quiet \
          --command="
            SELECT 1
            FROM pg_publication_tables
            WHERE pubname = 'file_converter_publication'
              AND schemaname = 'converter'
              AND tablename = 'outbox'
            LIMIT 1;
          " 2>/dev/null
    )" || result=""

    if [ "$result" = "1" ]; then
        break
    fi

    attempt=$((attempt + 1))
    if [ "$attempt" -ge 90 ]; then
        echo "Publication file_converter_publication for converter.outbox was not found or is not accessible." >&2
        exit 1
    fi
    sleep 2
done

echo "Rendering connector configuration..."
envsubst \
  '${DEBEZIUM_DB_HOST} ${DEBEZIUM_DB_PORT} ${DEBEZIUM_DB_USER} ${DEBEZIUM_PASSWORD} ${DEBEZIUM_DB_NAME} ${DEBEZIUM_TOPIC_PREFIX} ${KAFKA_OUTPUT_TOPIC}' \
  < /config/connector-config.json.template \
  > /tmp/connector-config.json

# PUT makes this operation repeatable: it creates the config if absent,
# or updates the existing connector config if it already exists.
echo "Registering/updating Debezium connector..."
curl -fsS \
  -X PUT \
  "${DEBEZIUM_CONNECT_URL}/connectors/file-converter-outbox-connector/config" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/connector-config.json

echo
echo "Connector configuration submitted. Check status at:"
echo "${DEBEZIUM_CONNECT_URL}/connectors/file-converter-outbox-connector/status"
