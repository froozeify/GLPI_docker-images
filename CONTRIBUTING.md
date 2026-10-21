# Contributing to GLPI Docker Images

Thank you for your interest in contributing to the GLPI Docker images project!

This guide will help you set up your local development environment to test changes.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed, with [Buildx](https://docs.docker.com/build/concepts/overview/#buildx).

## Quick Start

The `glpi` image is built with `docker buildx bake` (see `docker-bake.hcl`). It downloads the sources automatically from
the `GLPI_VERSION` variable. By default, it will download the latest stable version.

### Build Options

**Build with latest stable version:**

```bash
docker buildx bake glpi --load --set glpi.tags=glpi:local
```

**Build with a specific version:**

```bash
GLPI_VERSION=10.0.18 docker buildx bake glpi --load --set glpi.tags=glpi:local
```

**Build with a branch:**

```bash
GLPI_VERSION=11.0/bugfixes docker buildx bake glpi --load --set glpi.tags=glpi:local
```

**Build with a specific commit:**

```bash
GLPI_VERSION=2186bc6bd410d8bcb048637b3c0fb86b7e320c0a docker buildx bake glpi --load --set glpi.tags=glpi:local
```

**Build with a direct URL:**

```bash
GLPI_VERSION=https://github.com/glpi-project/glpi/archive/2186bc6.tar.gz docker buildx bake glpi --load --set glpi.tags=glpi:local
```

`docker build glpi/` alone no longer works, because the Dockerfile gets the PHP extensions install script from the
`php-scripts` named build context. Use Bake, or pass the context yourself:
`docker build --build-context php-scripts=githubactions-base/scripts glpi/`.

The production image keeps `apc.enable_cli=0` (APCu is disabled for the CLI), unlike the CI and development images.

### Applying Patches

You can apply patches after the source download using the `GLPI_PATCH_URL` build argument.

**Apply patches (space-separated):**

```bash
GLPI_VERSION=11.0.4 \
GLPI_PATCH_URL="https://example.com/patch1.diff https://example.com/patch2.diff" \
  docker buildx bake glpi --load --set glpi.tags=glpi:local
```

**Using docker-compose with patches:**

```yaml
services:
  glpi:
    build:
      context: ./glpi
      additional_contexts:
        php-scripts: ./githubactions-base/scripts
      args:
        GLPI_VERSION: 11.0.4
        GLPI_PATCH_URL: https://patch-diff.githubusercontent.com/raw/glpi-project/glpi/pull/22381.diff
```

### Run the Test Environment

We provide a `docker-compose.dev.yml` file to build and test the `glpi` container locally:

```bash
docker compose --file docker-compose.dev.yml up --build
```

### Verify

Once the containers are up:

1. Check the logs to see the installation progress:
    ```bash
    docker compose --file docker-compose.dev.yml logs --follow glpi
    ```
2. Wait for the "GLPI installation completed successfully!" message.
3. Access GLPI at [http://localhost:8080](http://localhost:8080).
    - **User:** `glpi`
    - **Password:** `glpi`

### Cleanup

To stop and remove the test containers:

```bash
docker compose --file docker-compose.dev.yml down --volumes
```

## Building the other images

All the images are declared in `docker-bake.hcl`, there is no need to pass build arguments by hand:

```bash
docker buildx bake --list=targets                     # list the targets
docker buildx bake --print githubactions-php-8-5      # show what will be built, without building
docker buildx bake githubactions-php-apache-8-5 --load   # build one image and load it in the local Docker
docker buildx bake githubactions-php --load           # same image for all the PHP versions
```

| Target / group                                                                                                                         | Image(s)                                                                                                                            |
|:---------------------------------------------------------------------------------------------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------|
| `githubactions-php-<php>`, `githubactions-php-apache-<php>`, `githubactions-php-apache-playwright-<php>`, `glpi-development-env-<php>` | PHP images, all built from the shared `githubactions-base` image (never published). `<php>` is the PHP version with a dash (`8-5`). |
| `githubactions-db`                                                                                                                     | MariaDB and MySQL images (`githubactions-mariadb:<version>`, `githubactions-mysql:<version>`).                                      |
| `services`                                                                                                                             | `githubactions-redis`, `githubactions-memcached`, `githubactions-openldap`, `githubactions-dovecot` and `plugin-builder`.           |
| `githubactions-glpi-apache`                                                                                                            | GLPI plugins images (`php-<php>-glpi-<version>`), built on top of the PHP/Apache Playwright image.                                  |
| `glpi`                                                                                                                                 | The GLPI image, see [Quick Start](#quick-start).                                                                                    |

`docker-bake.glpi-10.hcl` holds the legacy GLPI 10.0 images of `githubactions-glpi-apache`. It is not loaded by default, use
`docker buildx bake --file docker-bake.hcl --file docker-bake.glpi-10.hcl githubactions-glpi-apache-legacy`. It will be deleted
with the GLPI 10.0 end of life.

The PHP extensions of the PHP images are installed by `githubactions-base/scripts/install-php-extensions.sh`. To add one for
all the images, add it to `githubactions-base/Dockerfile`, to add one to a single image, call the script from its Dockerfile.

### Bake variables

They can be set as environment variables, e.g. `GHCR_NAMESPACE=ghcr.io/my-user docker buildx bake githubactions-php-8-5`.

| Variable               | Default                 | Description                                                                                                     |
|:-----------------------|:------------------------|:----------------------------------------------------------------------------------------------------------------|
| `GHCR_NAMESPACE`       | `ghcr.io/glpi-project`  | Registry and namespace used in the image tags.                                                                  |
| `PHP_VERSIONS`         | `["8.2", ..., "8.6"]`   | PHP versions of the PHP images (the CI matrix is built from it). Unreleased versions are mapped by `php_tag()`. |
| `LATEST_PHP_VERSION`   | `8.5`                   | PHP version that gets the `latest` tag (development image, GLPI plugins image) and is used by the `glpi` image. |
| `GLPI_REPO`            | `glpi-project/glpi`     | `glpi` image: repository GLPI is downloaded from.                                                               |
| `GLPI_VERSION`         | `latest`                | `glpi` image: release, branch, commit or URL to build.                                                          |
| `GLPI_PATCH_URL`       | _empty_                 | `glpi` image: space-separated URLs of patches to apply.                                                         |
| `GLPI_CACHE_KEY`       | _empty_                 | `glpi` image: cache busting key, set by the workflow.                                                           |
| `GLPI_MARKETPLACE_DIR` | `/var/glpi/marketplace` | `glpi` image: marketplace directory (`/var/www/glpi/marketplace` for GLPI 10).                                  |
| `GLPI_PHP_VERSION`     | `LATEST_PHP_VERSION`    | `glpi` image: PHP version.                                                                                      |
| `GHA_CACHE`            | `false`                 | Use the GitHub Actions cache (only works in a workflow).                                                        |
| `CACHE_SUFFIX`         | _empty_                 | Suffix of the cache scopes, used to isolate the arm64 caches of the development image.                          |

## Publishing from a fork

The workflows run on pull requests, including the ones coming from forks, but they never push anything from there: the
images are only built, and the registry logins are skipped when the secrets are not available.

On the `main` branch of a fork, the images are not pushed either, unless you opt in. To publish them on your own registries,
define the secrets and variables below in your fork (`Settings > Secrets and variables > Actions`), and set `PUSH_IMAGES` to `true`.
The upstream repository (`glpi-project/docker-images`) always pushes.

### Secrets

| Secret                | Used by                                            | Description                                                                                                                                                                                        |
|:----------------------|:---------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `GHCR_USERNAME`       | all the image workflows                            | GitHub user name used to log in to `ghcr.io`. Required to push.                                                                                                                                    |
| `GHCR_ACCESS_TOKEN`   | all the image workflows                            | Token with the `write:packages` scope used to log in to `ghcr.io`. Required to push.                                                                                                               |
| `DOCKER_HUB_USERNAME` | all the image workflows, `update_dockerhub_readme` | Docker Hub user name. For the CI images the login only avoids pull rate limits and is skipped when the token is empty. Required to push the `glpi` image and to update the Docker Hub description. |
| `DOCKER_HUB_TOKEN`    | all the image workflows, `update_dockerhub_readme` | Docker Hub access token, see above.                                                                                                                                                                |

### Variables

| Variable             | Used by                               | Description                                                                                                                                                                                               | Default                      |
|:---------------------|:--------------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-----------------------------|
| `PUSH_IMAGES`        | all the image workflows except `glpi` | Set to `true` to push the images built from the `main` branch of your fork.                                                                                                                               | _not set (no push)_          |
| `GHCR_NAMESPACE`     | all the image workflows except `glpi` | Registry and namespace of the images, e.g. `ghcr.io/my-user`.                                                                                                                                             | `ghcr.io/glpi-project`       |
| `GHCR_IMAGE`         | `glpi`                                | GHCR name of the GLPI image.                                                                                                                                                                              | `ghcr.io/glpi-project/glpi`  |
| `DOCKERHUB_IMAGE`    | `glpi`, `update_dockerhub_readme`     | Docker Hub name of the GLPI image.                                                                                                                                                                        | `glpi/glpi`                  |
| `DOCKER_IMAGES_REPO` | `glpi`                                | Repository containing the Docker files to build (`owner/repo`). Set it to your fork to build its code from `push` or `workflow_dispatch` runs; it is also what lets another repository call the workflow. | `glpi-project/docker-images` |
| `GLPI_REPO`          | `glpi`                                | Repository GLPI is downloaded from (`owner/repo`). It takes precedence over the `glpi-repo` input.                                                                                                        | `glpi-project/glpi`          |

The `glpi` workflow does not use `PUSH_IMAGES`: it is a reusable workflow that only pushes when it is run with its `push`
input set to `true` (and the secrets above are available).
