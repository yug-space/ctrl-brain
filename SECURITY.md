# Security Policy

## Supported Versions

Use the latest commit on `main`.

## Reporting a Vulnerability

Please do not open a public issue for sensitive security reports. Email the
maintainer or use GitHub's private vulnerability reporting if it is enabled for
the repository.

Include:

- affected version or commit
- steps to reproduce
- impact and affected data
- any suggested mitigation

## Secrets

Ctrl+Brain reads Supermemory keys from environment variables, `.env`, or local
user defaults. Never commit real API keys, `.env` files, capture data, or local
LaunchAgent files.
