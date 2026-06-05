# RabbitMQ Dedup Docker Image

This repository builds a RabbitMQ image with the third-party message deduplication plugin pre-installed, along with RabbitMQ Shovel and Shovel Management.

## Current Versions

- RabbitMQ: `4.2.7-management`
- RabbitMQ base digest: `sha256:be47482d5058d93be35021ead39614c25ceeb6c0f580e31ce98536e8d1326af5`
- Dedup plugin: `0.7.3`
- Elixir runtime plugin: `1.18.4`
- Logger runtime plugin: `1.18.4`

## Compatibility Note

As of 2026-06-05, upstream RabbitMQ has newer `4.3.x` releases, but the latest published `rabbitmq-message-deduplication` artifacts only cover RabbitMQ through `4.2.x`. This image therefore tracks the latest compatible RabbitMQ release instead of the absolute latest RabbitMQ release.

## Included Plugins

- `rabbitmq_message_deduplication`
- `rabbitmq_shovel`
- `rabbitmq_shovel_management`

## Pull the Image

```bash
docker pull mpolit/rabbitmq-dedup:latest
docker pull mpolit/rabbitmq-dedup:4.2.7
```

## Build the Image Locally

```bash
git clone https://github.com/mpol1t/rabbitmq-dedup.git
cd rabbitmq-dedup
docker build -t rabbitmq-dedup:local .
```

The Dockerfile pins the RabbitMQ base image by digest for reproducible rebuilds.

## Run the Container

```bash
docker run -d \
  --name rabbitmq-dedup \
  --env-file ./rabbitmq-dedup.env \
  -p 127.0.0.1:5672:5672 \
  -p 127.0.0.1:15672:15672 \
  mpolit/rabbitmq-dedup:latest
```

The management UI is then available at `http://127.0.0.1:15672`.

## Environment Variables

- `RABBITMQ_DEFAULT_USER`
- `RABBITMQ_DEFAULT_PASS`
- `RABBITMQ_DEFAULT_VHOST`

Prefer an env file that is ignored by Git and managed outside shell history.

Example `rabbitmq-dedup.env`:

```dotenv
RABBITMQ_DEFAULT_USER=replace-me
RABBITMQ_DEFAULT_PASS=replace-me
RABBITMQ_DEFAULT_VHOST=/
```

Run with that env file:

```bash
docker run -d \
  --name rabbitmq-dedup \
  --env-file ./rabbitmq-dedup.env \
  -p 127.0.0.1:5672:5672 \
  -p 127.0.0.1:15672:15672 \
  mpolit/rabbitmq-dedup:latest
```

## Docker Compose

```yaml
services:
  rabbitmq:
    image: mpolit/rabbitmq-dedup:4.2.7
    container_name: rabbitmq-dedup
    env_file:
      - ./rabbitmq-dedup.env
    ports:
      - "127.0.0.1:5672:5672"
      - "127.0.0.1:15672:15672"
    volumes:
      - rabbitmq-data:/var/lib/rabbitmq
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "rabbitmq-diagnostics check_running"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  rabbitmq-data:
```

## Updating Vendored Plugin Artifacts

The repository vendors the `.ez` plugin files to keep image builds deterministic. To refresh them from the upstream GitHub release bundle:

```bash
./scripts/update-plugins.sh
```

The refresh script also rewrites `plugins/checksums.txt`, and the Docker build verifies those checksums before enabling the plugins.
The release validator also downloads the upstream plugin bundle and checks that the vendored `.ez` files match the published upstream artifacts byte-for-byte.

Override `PLUGIN_RELEASE`, `PLUGIN_BUNDLE`, or `PLUGIN_SHA256` if you need to target a different compatible upstream asset.

## Smoke Test

Build and run the local smoke test:

```bash
docker build -t rabbitmq-dedup:local .
./scripts/smoke-test.sh rabbitmq-dedup:local
```

The smoke test:

- starts the container
- waits for the management API to become ready
- verifies the expected plugins are enabled
- verifies that duplicate messages are suppressed by the deduplication exchange

## Security

Current security controls in this repo:

- RabbitMQ runs as the non-root `rabbitmq` user
- the base image is pinned by digest
- vendored plugin artifacts are version-pinned and checksum-verified on refresh and during image build
- release validation confirms the vendored plugin binaries match the published upstream release bundle
- CI blocks releases on `HIGH` and `CRITICAL` image vulnerabilities
- the publish job promotes the exact tested `linux/amd64` image artifact instead of rebuilding it
- the promoted image receives GitHub attestations for provenance and SBOM data

Recommended production hardening:

- do not expose `15672` publicly; bind it to localhost or a private network, or place it behind a trusted proxy
- set explicit credentials and avoid `guest` outside local development
- use mounted configuration and secret management instead of committing credentials into compose files or shell history
- mount persistent storage for `/var/lib/rabbitmq`
- add container runtime restrictions after validation in your environment: `no-new-privileges`, dropped capabilities, read-only root filesystem, and resource limits
- enable TLS for management and client traffic when the broker is used outside a trusted internal network

Run the same vulnerability scan locally if needed:

```bash
trivy image --severity HIGH,CRITICAL rabbitmq-dedup:local
```

## CI/CD

The GitHub Actions workflow now:

- builds and smoke-tests every pull request
- validates release metadata before builds and before versioned tag publishes
- fails CI on actionable `HIGH` and `CRITICAL` image vulnerabilities
- validates and publishes the exact tested `linux/amd64` image artifact
- publishes GitHub provenance and SBOM attestations for the promoted image
- publishes rolling `latest` and `4.2` tags from `main`
- publishes immutable tags from git tags such as `v4.2.7`
- publishes `git-<sha>` tags for commit-level traceability

Recommended release flow:

```bash
git tag -a v4.2.7 -m "rabbitmq-dedup 4.2.7"
git push origin v4.2.7
```

## License

This project is licensed under the Mozilla Public License 2.0. See [LICENSE](LICENSE).
