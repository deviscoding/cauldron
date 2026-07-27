# ./node/docker-bake.hcl

variable "OS_MATRIX" {
  type = list(string)
}

variable "PLATFORMS" {}

variable "NODE_VERSION" {
  default = "24"
}

variable "VAT_DIR" {
  default = "."
}

target node {
  # Context is relative to where you execute the bake command (the root)
  context    = "${VAT_DIR}/core/node"
  name       = "node-${os}"
  dockerfile = "Dockerfile"
  matrix     = { os = OS_MATRIX }
  platforms  = split(",", PLATFORMS)

  args = {
    UPSTREAM_VERSION = NODE_VERSION
  }

  # Feeds the correct matrixed target (stage-base-bookworm, etc.) into the Dockerfile context
  contexts = {
    stage-base = "target:stage-base-${os}"
    builder-node = "docker-image://node:${NODE_VERSION}"
  }
}