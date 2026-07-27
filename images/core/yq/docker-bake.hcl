# ./yq/docker-bake.hcl

variable "PLATFORMS" {
  default = "linux/arm64,linux/amd64"
}

variable "YQ_VERSION" {
  default = "latest"
}

# reset line
target "yq" {
  # Context is relative to where you execute the bake command (the root)
  context    = "./core/yq"
  name       = "yq-${os}"
  dockerfile = "Dockerfile"
  matrix     = { os = ["jessie", "stretch", "bookworm", "bullseye", "trixie"] }
  platforms  = split(",", PLATFORMS)

  args = {
    UPSTREAM_VERSION = YQ_VERSION
  }

  contexts = {
    stage-base = "target:stage-base-${os}"
    # Add this line to pass the image as a structural context dependency
  }
}
