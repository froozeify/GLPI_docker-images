# LEGACY: GLPI 10.0 images of `githubactions-glpi-apache`.
#
# This file is loaded together with `docker-bake.hcl` (it uses its variables and functions) by the
# `githubactions-glpi-apache-legacy` workflow:
#   docker buildx bake --file docker-bake.hcl --file docker-bake.glpi-10.hcl githubactions-glpi-apache-legacy
#
# To be deleted with the GLPI 10.0 end of life: remove this file and `.github/workflows/githubactions-glpi-apache-legacy.yml`
# (and the PHP 7.4, 8.0 and 8.1 images, that are no longer built).

# The PHP 7.4, 8.0 and 8.1 images are no longer built (they have no `-playwright` variant), the already published ones
# are used.
variable "GLPI_10_PHP_VERSIONS" {
  default = ["7.4", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5"]
}

variable "GLPI_10_PUBLISHED_PHP_VERSIONS" {
  default = ["7.4", "8.0", "8.1"]
}

target "githubactions-glpi-apache-legacy" {
  name     = "githubactions-glpi-apache-glpi-10-0-x-php-${slug(php)}"
  matrix   = {
    php = GLPI_10_PHP_VERSIONS
  }
  context  = "githubactions-glpi-apache"
  contexts = {
    base = contains(GLPI_10_PUBLISHED_PHP_VERSIONS, php) ? "docker-image://${GHCR_NAMESPACE}/githubactions-php-apache:${php}" : "target:githubactions-php-apache-playwright-${slug(php)}"
  }
  args     = {
    GLPI_BRANCH = "10.0/bugfixes"
    CACHE_BUST  = timestamp()
  }
  tags     = glpi_apache_tags(php, "10.0.x")
  pull     = true
}
