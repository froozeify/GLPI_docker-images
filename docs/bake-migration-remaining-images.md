# Migrating the remaining images to `docker bake`

The PHP images (`githubactions-php`, `githubactions-php-apache`, `glpi-development-env`) and the `glpi` image are built
with `docker-bake.hcl`. The images below are still built with `docker/build-push-action` in one workflow each. This
document explains why migrating them is worthwhile and how to do it.

| Image | Workflow | Variants |
|:------|:---------|:---------|
| `githubactions-db` | `githubactions-db.yml` | 6 (MariaDB 10.11, 11.4, 11.8, 12.3, MySQL 8.4, 9.7) |
| `githubactions-glpi-apache` | `githubactions-glpi-apache.yml` | 17 (GLPI branch × PHP version) |
| `githubactions-dovecot` | `githubactions-dovecot.yml` | 1 |
| `githubactions-memcached` | `githubactions-memcached.yml` | 1 |
| `githubactions-openldap` | `githubactions-openldap.yml` | 1 |
| `githubactions-redis` | `githubactions-redis.yml` | 1 |
| `plugin-builder` | `plugin-builder.yml` | 1 |

## Why

- **One place for the build definition.** The base image, build arguments, tags and cache settings are today spread
  between the workflows (`build-args`, `tags`, `matrix`) and the Dockerfiles. With Bake they are in `docker-bake.hcl` and
  can be built identically on a developer machine (`docker buildx bake githubactions-db-mariadb-11-4`).
- **No more copy-pasted workflows.** The five single-image workflows are identical except for the context and the tag.
  A single workflow can build all of them.
- **`githubactions-glpi-apache` can reuse the PHP images in the same build graph.** It currently pulls
  `ghcr.io/glpi-project/githubactions-php-apache:<php>-playwright` from the registry, so it depends on the previous
  publication of that image (and on the order of the workflows). With Bake, `contexts` can reference the target
  directly (`target:githubactions-php-apache-playwright-8-5`), as already done for the `base` context.
- **Matrices come from the HCL.** The `.github/actions/bake-php-matrix` action already generates a CI matrix from a Bake
  target; the same can be done for the DB versions and the `glpi-apache` combinations.

## How

The snippets below are sketches. The DB matrix was checked with `docker buildx bake --print`; none of them has been built.

### Single-image workflows (dovecot, memcached, openldap, redis, plugin-builder)

```hcl
target "githubactions-redis" {
  context    = "githubactions-redis"
  args       = { BASE_IMAGE = "redis" }
  tags       = ["${REGISTRY}/githubactions-redis:latest"]
  pull       = true
  cache-from = gha_cache_from("githubactions-redis")
  cache-to   = gha_cache_to("githubactions-redis")
}
```

`BASE_IMAGE` is already the default of the Dockerfile for most of them, so the `args` block is only needed when the
workflow overrides it (memcached, openldap and redis pass the same value as the default today).

### `githubactions-db`

Replace the workflow matrix with a Bake matrix:

```hcl
target "githubactions-db" {
  name     = "githubactions-db-${db.image}-${replace(db.version, ".", "-")}"
  matrix   = {
    db = [
      { image = "mariadb", version = "10.11" },
      { image = "mariadb", version = "11.4" },
      # ...
      { image = "mysql", version = "8.4" },
    ]
  }
  context  = "githubactions-db"
  args     = {
    BASE_IMAGE = "${db.image}:${db.version}"
    CONFIG_DIR = "/etc/mysql/conf.d"
  }
  tags     = ["${REGISTRY}/githubactions-${db.image}:${db.version}"]
  # cache-from / cache-to with a scope per target, as for the other images
}
```

`CONFIG_DIR` is the same for all versions today, so it can be dropped from the matrix (the Dockerfile default is
already `/etc/mysql/conf.d`).

### `githubactions-glpi-apache`

Declare the supported `(glpi branch, PHP version)` combinations in the HCL, and build the base through `contexts`
instead of pulling it:

```hcl
target "githubactions-glpi-apache" {
  name     = "githubactions-glpi-apache-${replace(c.php, ".", "-")}-${c.slug}"
  matrix   = { c = [ { branch = "11.0/bugfixes", slug = "11-0", php = "8.5" }, /* ... */ ] }
  context  = "githubactions-glpi-apache"
  contexts = {
    # `ARG BASE_IMAGE` + `FROM $BASE_IMAGE` must become `FROM base` (as in the other images)
    base = "target:githubactions-php-apache-playwright-${replace(c.php, ".", "-")}"
  }
  args     = { GLPI_BRANCH = c.branch }
  no-cache = true
  tags     = ["${REGISTRY}/githubactions-glpi-apache:php-${c.php}-glpi-${c.slug}"]
}
```

Points to handle:

- PHP 7.4, 8.0 and 8.1 are still listed in the workflow matrix but are no longer built by the PHP images workflows. They
  have no `-playwright` tag, so they cannot use `contexts` and need to keep pulling the published image (or be dropped
  if nobody uses them anymore).
- The `latest` tag (GLPI 11.0 / PHP 8.5) is currently added by the "Generate tags" step. It can be a second entry in
  `tags` of the matching combination.
- The workflow runs nightly with `no-cache: true`; keep `no-cache = true` on the target.

### Workflows

Once the targets exist, each workflow reduces to: checkout, `setup-buildx-action`, logins (guarded by `PUSH` as in the
other workflows), then `docker/bake-action` with `GHA_CACHE: "true"`. The matrix is produced by a `prepare` job.
`.github/actions/bake-php-matrix` extracts the PHP version from the end of the target name; for the DB images a similar
step (or a generalisation of the action to any target suffix) is needed.

## Things to keep in mind

- Tags published today must stay identical (`githubactions-mariadb:11.4`, `githubactions-glpi-apache:php-8.5-glpi-11.0.x`,
  `:latest` for the single-image ones). Compare `docker buildx bake --print <target>` against the current workflow
  inputs before merging.
- Keep one cache scope per target (`gha_cache_from` / `gha_cache_to`), otherwise targets of the same job overwrite each
  other's cache.
- Do the migration one image family at a time: a regression only impacts one set of CI images.
