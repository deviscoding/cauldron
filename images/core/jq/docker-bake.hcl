# ./jq/docker-bake.hcl

variable "PLATFORMS" {
  default = "linux/arm64,linux/amd64"
}

variable "JQ_VERSION" {
  default = "1.7.1"
}

target jq {
  # Context is relative to where you execute the bake command (the root)
  context    = "./core/jq"
  name       = "jq-${os}"
  dockerfile = "Dockerfile"
  matrix     = { os = ["jessie", "stretch", "bookworm", "bullseye", "trixie"] }
  platforms = split(",", PLATFORMS)

  args = {
    UPSTREAM_VERSION = JQ_VERSION
  }

  # Feeds the correct matrixed target (stage-base-bookworm, etc.) into the Dockerfile context
  contexts = {
    stage-base = "target:stage-base-${os}"
  }
}
