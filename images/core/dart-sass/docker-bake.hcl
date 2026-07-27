# ./dart-sass/docker-bake.hcl

variable "PLATFORMS" {
  default = "linux/arm64,linux/amd64"
}

variable "SASS_VERSION" {
  default = "1.77.1"
}

target "dart-sass" {
  # Context is relative to where you execute the bake command (the root)
  name       = "dart-sass-${os}"
  context    = "./core/dart-sass"
  dockerfile = "Dockerfile"
  matrix     = { os = ["jessie", "stretch", "bookworm", "bullseye", "trixie"] }
  platforms = split(",", PLATFORMS)

  args = {
    UPSTREAM_VERSION = SASS_VERSION
  }

  contexts = {
    stage-base = "target:stage-base-${os}"
  }
}