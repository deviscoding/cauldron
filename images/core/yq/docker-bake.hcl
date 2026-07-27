# ./yq/docker-bake.hcl

variable "OS_MATRIX" {
  type = list(string)
}

variable "PLATFORMS" {}

variable "YQ_VERSION" {
  default = "latest"
}

variable "VAT_DIR" {
  default = "."
}

# reset line
target "yq" {
  # Context is relative to where you execute the bake command (the root)
  context    = "${VAT_DIR}/core/yq"
  name       = "yq-${os}"
  dockerfile = "Dockerfile"
  matrix     = { os = OS_MATRIX }
  platforms  = split(",", PLATFORMS)

  args = {
    UPSTREAM_VERSION = YQ_VERSION
  }

  contexts = {
    stage-base = "target:stage-base-${os}"
    # Add this line to pass the image as a structural context dependency
  }
}
