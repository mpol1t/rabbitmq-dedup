FROM rabbitmq:4.0.4-management

# Copy the plugins into the RabbitMQ plugins directory
COPY plugins/elixir-1.16.3.ez $RABBITMQ_HOME/plugins/
COPY plugins/rabbitmq_message_deduplication-0.6.4.ez $RABBITMQ_HOME/plugins/

# Change ownership to rabbitmq for all plugins and enable required plugins
RUN chown -R rabbitmq:rabbitmq $RABBITMQ_HOME/plugins && \
    rabbitmq-plugins enable --offline \
    rabbitmq_message_deduplication \
    rabbitmq_shovel \
    rabbitmq_shovel_management

USER rabbitmq

# Expose RabbitMQ ports
EXPOSE 5672 15672