# ./s6-overlay/docker-bake.hcl

variable "OS_MATRIX" {
  type = list(string)
}

variable "PLATFORMS" {}

variable "S6_OVERLAY_VERSION" {
  default = "3.2.0.2"
}

variable "VAT_DIR" {
  default = "."
}

target s6-overlay {
  # Context is relative to where you execute the bake command (the root)
  context    = "${VAT_DIR}/core/s6-overlay"
  name       = "s6-overlay-${os}"
  dockerfile = "Dockerfile"
  matrix     = { os = OS_MATRIX }
  platforms  = split(",", PLATFORMS)

  args = {
    UPSTREAM_VERSION = S6_OVERLAY_VERSION
  }

  # Feeds the correct matrixed target (stage-base-bookworm, etc.) into the Dockerfile context
  contexts = {
    stage-base = "target:stage-base-${os}"
  }
}