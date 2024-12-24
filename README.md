# RabbitMQ Dedup Docker Image

This repository provides a Docker image of RabbitMQ pre-configured with the **Message Deduplication** plugin and additional useful plugins like Shovel and Shovel Management.

## Features

- **RabbitMQ Version:** 4.0.4-management
- **Pre-installed Plugins:**
    - `rabbitmq_message_deduplication`: Enables message deduplication.
    - `rabbitmq_shovel`: Supports message forwarding between RabbitMQ brokers.
    - `rabbitmq_shovel_management`: Adds UI support for Shovel.

## Getting Started

### Pull the Image

You can pull the pre-built Docker image from Docker Hub:

```bash
docker pull mpolit/rabbitmq-dedup
```

### Build the Image Locally

Alternatively, clone this repository and build the image locally:

```bash
git clone https://github.com/mpol1t/rabbitmq-dedup.git
cd rabbitmq-dedup
docker build -t rabbitmq-dedup .
```

### Run the Container

Run the RabbitMQ container:

```bash
docker run -d --name rabbitmq-dedup -p 5672:5672 -p 15672:15672 mpolit/rabbitmq-dedup
```

Access the RabbitMQ Management UI at `http://localhost:15672` (default credentials: `guest` / `guest`).

### Environment Variables

- **RABBITMQ_DEFAULT_USER**: Set the default admin username.
- **RABBITMQ_DEFAULT_PASS**: Set the default admin password.

Example:

```bash
docker run -d \
--name rabbitmq-dedup \
-e RABBITMQ_DEFAULT_USER=user \
-e RABBITMQ_DEFAULT_PASS=password \
-p 5672:5672 \
-p 15672:15672 \
mpolit/rabbitmq-dedup
```

### Using with Docker Compose

```bash
version: "3.9"
services:
  rabbitmq:
    image: mpolit/rabbitmq-dedup:latest
    container_name: rabbitmq-dedup
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_VHOST: "/"
      RABBITMQ_DEFAULT_USER: "user"
      RABBITMQ_DEFAULT_PASS: "password"
    restart: unless-stopped
    healthcheck:
      test: [ "CMD-SHELL", "rabbitmq-diagnostics check_running" ]
      interval: 10s
      timeout: 5s
      retries: 5
```


## Plugins

- **Message Deduplication Plugin**: Helps prevent duplicate messages in RabbitMQ queues.
- **Shovel**: A plugin for transferring messages between brokers.
- **Shovel Management**: Adds management UI capabilities for the Shovel plugin.

## License

This project is licensed under the Mozilla Public License 2.0. For more details, see the [LICENSE](LICENSE) file.