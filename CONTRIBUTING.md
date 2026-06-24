# Contributing

## Workflow

All changes to `main` must go through a pull request.

Repository policy expects:

- no direct pushes to `main`
- no force pushes to `main`
- rebase merge as the only merge method
- clean commit history on pull request branches before merge

Force-pushing feature branches is acceptable when cleaning up branch history for review.

## Before Opening a Pull Request

Run the repository checks locally where applicable:

```bash
docker build --platform linux/amd64 -t rabbitmq-dedup:local .
./scripts/validate-release.sh
DOCKER_PLATFORM=linux/amd64 ./scripts/smoke-test.sh rabbitmq-dedup:local
./scripts/scan-image.sh rabbitmq-dedup:local
```

If your change affects vendored plugins, also run:

```bash
./scripts/update-plugins.sh
```

## Commit Expectations

Keep commits logical and reviewable.

Preferred characteristics:

- one concern per commit where practical
- commit messages in lowercase
- no placeholder or exploratory commits left in the branch before merge

## Pull Request Expectations

Pull requests should:

- explain the user-visible or operational impact
- describe any release-process or workflow impact
- mention any follow-up work or limitations
- include verification notes

Changes affecting these paths deserve extra care:

- `.github/workflows/`
- `Dockerfile`
- `scripts/`
- `plugins/`

## Release Tags

Immutable release publication is driven by Git tags matching:

```text
v<major>.<minor>.<patch>
```

Example:

```bash
git tag -a v4.2.8 -m "rabbitmq-dedup 4.2.8"
git push origin v4.2.8
```

Do not create or move release tags casually.

## Security

If your change affects workflow security, release provenance, image publication, or credentials handling, call that out explicitly in the pull request.

For suspected vulnerabilities, follow [SECURITY.md](SECURITY.md) instead of opening a public issue with exploit details.
