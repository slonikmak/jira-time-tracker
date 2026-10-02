---
name: desktop-release
description: Prepare, build, verify, or publish a Jira Time Tracker desktop release using the repository changelog and GitHub Actions. Use when asked for a release, release packages, a version bump, or release publication.
---

# Desktop release

Read [the release guide](../../../docs/releases.md) and the root `AGENTS.md`.
The guide owns versioning, changelog format, package contents, and verification gates.
Operate from the repository root. Use `git`, `gh`, and the existing desktop workflow;
keep all release documentation in English.

## Prepare

1. Inspect `git status --short`, the branch, remote, recent commits, tags, and GitHub releases. Identify the requested scope: preparation, a built draft, or publication. Building a release authorizes pushing its scoped preparation commit and new tag; a preparation-only request stops before those remote writes. Publication requires explicit user authorization, which may already be present in the conversation.
2. Select the version using the guide and existing releases. Ask only if a product decision remains unresolved. Preserve unrelated changes. A package contains the tagged commit, so either commit the requested application changes after checking them or explicitly exclude unfinished work. Never stage everything in a dirty checkout.
3. Update `pubspec.yaml` and move only entries describing included changes from `Unreleased` into `## [VERSION] - YYYY-MM-DD`, using the user's current local date. Keep `Unreleased` at the top. Preserve existing release sections. Include known installation limitations in the version's notes.
4. Run `python -m unittest discover -s tool -p "test_release_notes.py"` and `python tool/release_notes.py vVERSION`. Run application checks appropriate to included changes, following specification section 13. Inspect the scoped diff and `git diff --check`. Commit the preparation when a built release was requested; otherwise leave it reviewable locally.

## Build a draft

1. Push the prepared commit to the repository's release branch. Confirm the remote commit matches the intended source and the version tag does not already exist locally or remotely. Create an annotated `vVERSION` tag on that exact commit, then push that tag. Never move an existing release tag.
2. Find the tag run with `gh run list --workflow desktop-release.yml`, verify its `headSha` against the tag, and follow it with `gh run view` / `gh run watch`. All three platform jobs and the draft-release job must succeed. Diagnose failures before rerunning failed jobs; do not claim completion while a job is pending or skipped.
3. Inspect `gh release view vVERSION --json isDraft,isPrerelease,body,assets,url`. Require a draft, the guide's prerelease status, notes matching `python tool/release_notes.py vVERSION`, and all three expected ZIPs. Download with `gh release download vVERSION --dir DIRECTORY`; inspect each archive's contents. On an authenticated machine, drafts and their assets can be accessed with `gh` even though public visitors cannot see them.
4. Test the downloaded packages using the guide's manual checks. Record the OS, architecture, package, and results. CI startup checks do not prove installation, Gatekeeper acceptance, Keychain persistence, or real Mac usability. If a required machine or credential is unavailable, keep the release as a draft and report the specific missing check; do all independent work first.

## Publish when requested

Once the guide's checks pass and publication is authorized, publish the existing
draft with `gh release edit vVERSION --draft=false`. Verify the public release and
its three assets after publication. Preserve prerelease status; never make a
preview the stable latest release. Never replace published assets or rewrite
published tags or changelog sections. Ship corrections as a new version.

Report the version, source commit, tag, workflow and release links, package names,
checks actually performed, and exact state: prepared locally, built draft, or
published. State any remaining manual checks. Never include Jira credentials or
create production worklogs during verification.
