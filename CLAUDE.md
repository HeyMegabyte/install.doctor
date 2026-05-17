# install.doctor

## Purpose

One-line Bash developer desktop provisioning platform with safety, idempotency, and recovery focus.

## Scope

This skill contains **site-specific/domain-specific logic only**.

It is automatically composed with the shared base layer:
- `.agentskills/base-layer/SKILL.md` (folder)
- base skill slug: `cloudflare-angular-saas`

Do **not** duplicate generic process rules here (TDD loop, Playwright discipline, Semgrep, deploy verification, docs gates). Those belong to the base layer.

## Auto-Inclusion (Repository Detection)

Claude Code / Emdash should auto-select this overlay when repository evidence points to **install.doctor**:
- git remote / repo name / workspace name
- package or app names
- Cloudflare routes / deployment URLs / domains
- README / docs / branding references

If multiple overlays appear possible, choose the closest one, state the assumption, and continue.

## Site-Specific Focus Areas

- Bootstrap scripts, package install logic, and idempotent provisioning
- Privilege boundaries, `sudo` prompts, and rollback/recovery safeguards
- OS/environment detection and compatibility matrices
- Docs with command tables, troubleshooting, and verification checklists
