# Security Policy

## Scope

This repository publishes a public Docker image for RabbitMQ with the message deduplication plugin pre-installed.

Supported image line:

- `4.2.x-alpine`

Older tags may remain visible for historical reasons, but only the current supported line should be assumed to receive security and maintenance updates.

## Reporting a Vulnerability

Do not open public GitHub issues for suspected security vulnerabilities.

Report vulnerabilities privately by using GitHub's security advisory workflow for this repository if available. If that is not available or appropriate, contact the maintainer directly through a private channel before public disclosure.

When reporting, include:

- affected image tag or digest
- a clear description of the issue
- reproduction steps if applicable
- impact assessment
- any known mitigations or upstream references

## Response Expectations

Target expectations:

- initial triage acknowledgement within 7 days
- confirmation of severity and scope as soon as reasonably possible
- coordinated disclosure after a fix, mitigation, or clear operational guidance is available

These are targets, not guarantees.

## Upstream Dependencies

Some security issues may originate in:

- the official RabbitMQ base image
- Alpine packages
- vendored RabbitMQ plugin artifacts
- GitHub Actions or release workflow dependencies

Where the issue is upstream, fixes may depend on upstream releases or repository-specific mitigations.
