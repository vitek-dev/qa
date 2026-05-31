# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`vitek-dev/qa` is **not an application** — it is the build definition for a reusable PHP quality-assurance Docker image, published to `ghcr.io/vitek-dev/qa`. There is no PHP source to run here; the repo produces an image that consumers mount their own project into (at `/app`) and run QA tools against.

The bundled tools (installed globally via Composer in the `Dockerfile`) are exposed on `PATH` as:

- `phpstan` / `stan` — PHPStan static analysis
- `phpcs` / `cs` — PHP_CodeSniffer
- `phpcbf` / `cbf` — PHP Code Beautifier (auto-fix)
- `deptrac` — Deptrac architectural dependency checks
- `init` — scaffolds default config files into the mounted project (see `scripts/init.sh`)

Two coding standards are pre-registered with PHP_CodeSniffer's `installed_paths`: the `VitekDevCodingStandard` ruleset, which lives **in this repo** at `config/phpcs/standards/VitekDevCodingStandard/ruleset.xml` and is copied into the image at `/config/phpcs/standards`, and `slevomat/coding-standard` (a Composer dependency the ruleset's sniffs are built on).

`VitekDevCodingStandard` is structured as a **`PSR12` base plus a curated set of Slevomat sniffs** that add *semantic* strictness (strict types, modern syntax, dead-code/unused checks, import policy) on top of PSR-12's formatting. Slevomat sniffs that PSR-12 already covers or conflicts with have been deliberately removed; each removal is left as an inline `<!-- Removed ... -->` comment naming the PSR-12 sniff that replaces it. When editing the ruleset, do not re-introduce formatting sniffs PSR-12 owns, and keep those removal notes intact.

## Common commands

Build the image locally (single platform). The `FROM php:%%PHP_VERSION%%-alpine` placeholder must be substituted with a concrete PHP version first (a bare `docker build` fails until it is):

```bash
PHP_VERSION=8.4
sed "s/%%PHP_VERSION%%/${PHP_VERSION}/" Dockerfile \
  | docker build -t vitek-dev/qa:v${PHP_VERSION} -f - .
```

Run the tools against a project by mounting it at `/app`:

```bash
docker run --rm -v "$PWD":/app vitek-dev/qa:v8.4 phpcs       # lint
docker run --rm -v "$PWD":/app vitek-dev/qa:v8.4 phpcbf      # auto-fix style
docker run --rm -v "$PWD":/app vitek-dev/qa:v8.4 phpstan analyse
docker run --rm -v "$PWD":/app vitek-dev/qa:v8.4 init        # generate default configs
docker run --rm -it -v "$PWD":/app vitek-dev/qa:v8.4         # interactive shell (sh; default CMD)
```

Multi-platform build (matches CI — requires buildx/QEMU; same `%%PHP_VERSION%%` substitution applies):

```bash
PHP_VERSION=8.4
sed "s/%%PHP_VERSION%%/${PHP_VERSION}/" Dockerfile \
  | docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/vitek-dev/qa:v${PHP_VERSION} -f - .
```

Publish the current `main` to every `php/*` release branch at once (each push triggers one CI image build — prompts before pushing):

```bash
./bin/publish-php-branches.sh        # -n dry run, -y skip prompt, -f overwrite diverged branches
```

## Architecture and how things fit together

- **`Dockerfile`** is the heart of the project. It is `FROM php:%%PHP_VERSION%%-alpine`, where `%%PHP_VERSION%%` is a **placeholder for the PHP version that must be substituted at build time** (a bare `docker build` fails until it is) — the version comes from the branch (see release pipeline below). It installs the `zip` extension (compiled via a throwaway `--virtual .build-deps` apk group that is `apk del`'d in the same layer, so the toolchain stays out of the final image) and Composer, sets `minimum-stability dev`, then `composer global require`s the QA tools and symlinks their binaries from `$HOME/.composer/vendor/bin` into `/usr/local/bin` (including the short aliases `cs`/`cbf`/`stan`). The `phpcs --config-set installed_paths ...` step is what makes the custom and slevomat standards discoverable. `--ignore-platform-reqs` is required on the global require (see commit history) because tools declare constraints the base image doesn't satisfy. The Alpine base keeps the image ~195 MB (vs ~690 MB on the previous Debian/bookworm base); the default shell is `sh`, not bash.
- **`scripts/`** is copied to `/scripts` in the image and made executable. `scripts/init.sh` is symlinked as `/usr/local/bin/init`. It is idempotent: it refuses to run if `/app` is empty, then for each default config (`phpstan.neon`, `phpstan-baseline.neon`, `phpcs.xml`, `deptrac.yaml`) `cp`s the template from `/config/<tool>/` into `/app` only when that file doesn't already exist. The script itself holds no config content — it's a thin loop over `install_config <source-path> <destination-filename>`; the actual defaults live as real files under `config/` (see below).
- **`config/`** is organised per tool: `config/phpstan/phpstan.neon` (level 5, paths `src`, `includes` the baseline) plus an empty `config/phpstan/phpstan-baseline.neon` (consumers regenerate it with `phpstan analyse --generate-baseline`), `config/phpcs/phpcs.xml` (references `VitekDevCodingStandard`, scans `src`, excludes `*/vendor/*`), `config/deptrac/deptrac.yaml` (DDD layering — `Domain`/`Application`/`Infrastructure` matched by `src/<Context>/<Layer>/.*` directory globs), and `config/phpcs/standards/VitekDevCodingStandard/ruleset.xml` (the phpcs standard itself, registered via `installed_paths`). To add or change a consumer default, edit/add the file under `config/<tool>/` and reference it from an `install_config` call in `init.sh`.
- **`.github/workflows/build.yaml`** is the release pipeline. It triggers on pushes to `php/*` branches, derives the version by stripping the `php/` prefix from the branch name (`${GITHUB_REF_NAME#php/}`), then a **`sed -i "s/%%PHP_VERSION%%/<version>/" Dockerfile`** step substitutes the placeholder so the base image matches, and finally builds/pushes the multi-platform image to `ghcr.io/${{ github.repository }}:v<version>` (note the `v` prefix). So **pushing branch `php/8.4` substitutes `FROM php:8.4-alpine` and publishes `ghcr.io/vitek-dev/qa:v8.4`** — tag and base PHP version stay in lock-step automatically. There is no test suite or staging tag, and no `:latest` is published — the branch *is* the release. Action versions are pinned to floating major tags.
- **`bin/`** holds maintainer-only helper scripts that are deliberately **not** part of the image — only `scripts/` and `config/` are `COPY`'d in, so anything that should stay out of the published image goes here, not in `scripts/`. `bin/publish-php-branches.sh` is the release helper: because every `php/*` branch is byte-identical to `main` (the branch name alone selects the PHP version), it fast-forwards each `php/*` branch on the remote up to `main` and pushes them, firing one CI build per branch — i.e. it rolls a single `main` commit out to all published PHP versions at once. It is plain bash targeting macOS's bash 3.2 (no `mapfile`), prompts before pushing, skips branches that have diverged from `main` unless given `-f`, and supports `-n` (dry run) / `-y` (no prompt).

## When changing things

- The PHP version flows from the branch name: branch `php/X.Y` → image tag `:X.Y` (workflow) and base image `php:X.Y-alpine` (the `%%PHP_VERSION%%` placeholder in the `Dockerfile`'s `FROM`). The placeholder must be substituted with the same `X.Y` value the tag uses, so the `:X.Y` image actually ships PHP X.Y. Keep tag and base version in lock-step.
- The `scripts/init.sh` shebang is `#!/bin/sh` and the image's `CMD` is `sh` (Alpine has no bash by default). Keep `init.sh` POSIX-clean — no bashisms — or add `bash` back to the `apk add` line. This POSIX constraint applies to `scripts/` (which runs *inside* the image); maintainer scripts in `bin/` run on the developer's host instead, so they may use bash but should stay compatible with macOS's bash 3.2.
- Adding or upgrading a QA tool means editing the `composer global require` list in the `Dockerfile`, and adding a `/usr/local/bin` symlink for its binary if it should be callable directly.
- Adding a coding standard requires appending its path to the `phpcs --config-set installed_paths` list. For Composer-installed standards that's a vendor path; the in-repo `VitekDevCodingStandard` is shipped under `config/phpcs/standards/` (copied to `/config/phpcs/standards`) instead — edit `config/phpcs/standards/VitekDevCodingStandard/ruleset.xml` to change the rules.
- The default config templates are real files under per-tool folders `config/phpstan/`, `config/phpcs/`, `config/deptrac/` (copied to `/config/<tool>/`, scaffolded by `init`). Keep `phpstan.neon` / `phpcs.xml` / `deptrac.yaml` in sync with the standards the image ships — e.g. `phpcs.xml` must keep referencing `VitekDevCodingStandard`. Adding a new default = drop a file under `config/<tool>/` and add an `install_config <source-path> <destination-filename>` line to `scripts/init.sh`.
