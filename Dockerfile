ARG RABBITMQ_VERSION=4.2.8-management-alpine
ARG RABBITMQ_DIGEST=sha256:797068c77460c6ccdd4750e56d7fe3f3296e73c82f44e7d4d5b85164d5dc931e

FROM rabbitmq:${RABBITMQ_VERSION}@${RABBITMQ_DIGEST}

# Copy the plugins into the RabbitMQ plugins directory
COPY plugins/checksums.txt /tmp/plugin-checksums.txt
COPY plugins/elixir-1.18.4.ez $RABBITMQ_HOME/plugins/
COPY plugins/logger-1.18.4.ez $RABBITMQ_HOME/plugins/
COPY plugins/rabbitmq_message_deduplication-0.7.3.ez $RABBITMQ_HOME/plugins/

# Verify vendored plugin artifacts before enabling them.
RUN cd $RABBITMQ_HOME/plugins && \
    sha256sum -c /tmp/plugin-checksums.txt && \
    chown -R rabbitmq:rabbitmq $RABBITMQ_HOME/plugins && \
    rabbitmq-plugins enable --offline \
    rabbitmq_message_deduplication \
    rabbitmq_shovel \
    rabbitmq_shovel_management

USER rabbitmq

# Expose RabbitMQ ports
EXPOSE 5672 15672
