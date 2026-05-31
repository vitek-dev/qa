# vitek-dev/qa

Ready-to-use PHP quality-assurance Docker image. Bundles PHPStan, PHP_CodeSniffer / Code Beautifier (with the `VitekDevCodingStandard` ruleset — PSR-12 plus stricter Slevomat sniffs) and Deptrac.

## Usage

Mount your project at `/app` and run a tool:

```bash
docker run --rm -v "$PWD":/app ghcr.io/vitek-dev/qa:v8.x init        # scaffold default config files
```

```bash
docker run --rm -v "$PWD":/app ghcr.io/vitek-dev/qa:v8.x phpcs       # lint (or just "cs")
docker run --rm -v "$PWD":/app ghcr.io/vitek-dev/qa:v8.x phpcbf      # auto-fix style (or just "cbf")
docker run --rm -v "$PWD":/app ghcr.io/vitek-dev/qa:v8.x phpstan analyse # static analysis (or just "stan")
docker run --rm -v "$PWD":/app ghcr.io/vitek-dev/qa:v8.x deptrac analyse # architecture / layer rules
```

Tags track the PHP version (e.g. `:v8.x`). `init` writes a default `phpstan.neon` (+ empty `phpstan-baseline.neon`), `phpcs.xml` and `deptrac.yaml` (DDD layering) if they don't already exist. Regenerate the baseline with `phpstan analyse --generate-baseline` to grandfather existing errors.
