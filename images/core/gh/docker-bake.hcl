# ./gh/docker-bake.hcl

variable "OS_MATRIX" {
  type = list(string)
}

variable "PLATFORMS" {}

variable "GH_VERSION" {
  default = "2.49.2"
}

variable "GH_PACKAGES" {
  type    = list(string)
  default = ["apt-utils"]
}

target gh {
  # Context is relative to where you execute the bake command (the root)
  context    = "./core/gh"
  name       = "gh-${os}"
  dockerfile = "Dockerfile"
  matrix     = { os = OS_MATRIX }
  platforms  = split(",", PLATFORMS)

  args = {
    UPSTREAM_VERSION = GH_VERSION
    GH_PACKAGES      = join(" ", GH_PACKAGES)
  }

  # Feeds the correct matrixed target (stage-base-bookworm, etc.) into the Dockerfile context
  contexts = {
    stage-base = "target:stage-base-${os}"
  }
}
