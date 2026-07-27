# ./s6-overlay/docker-bake.hcl

variable "PLATFORMS" {
  default = "linux/arm64,linux/amd64"
}

variable "S6_OVERLAY_VERSION" {
  default = "3.2.0.2"
}

target s6-overlay {
  # Context is relative to where you execute the bake command (the root)
  context    = "./core/s6-overlay"
  name       = "s6-overlay-${os}"
  dockerfile = "Dockerfile"
  matrix     = { os = ["jessie", "stretch", "bookworm", "bullseye", "trixie"] }
  platforms = split(",", PLATFORMS)

  args = {
    UPSTREAM_VERSION = S6_OVERLAY_VERSION
  }

  # Feeds the correct matrixed target (stage-base-bookworm, etc.) into the Dockerfile context
  contexts = {
    stage-base = "target:stage-base-${os}"
  }
}