variable "PLATFORMS" {
  # Define multiple target architectures here
  default = ["linux/amd64", "linux/arm64"]
}

variable "DOCKERHUB_USER" {
  default = ""
}

variable "TAG" {
  default = "latest"
}

variable "BASE_OS_VERSION" {
  default = "stretch"
}

variable "GH_VERSION" {
  default = "2.49.2"
}

variable "SASS_VERSION" {
  default = "1.77.1"
}

variable "PHP_VERSION" {
  default = "7.0.33"
}


variable "PHP_EXT_INSTALLER_VERSION" {
  default = "2.7.0"
}

variable "S6_OVERLAY_VERSION" {
  default = "3.2.0.2"
}

variable "S6_DIR" {
  default = "/opt/s6"
}

variable "IMAGE_NAME" {
  default = "php${PHP_VERSION}-fpm-apache"
}

variable "REGISTRY_NAME" {
  default = notequal(DOCKERHUB_USER, "") ? "${DOCKERHUB_USER}/${IMAGE_NAME}" : IMAGE_NAME
}

target "stage-base" {
  context    = "../${BASE_OS_VERSION}"
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS
  args = {
    BASE_OS_VERSION = BASE_OS_VERSION
    PHP_VERSION     = PHP_VERSION
  }
  contexts = {
    common = "../common"
  }
}

target "stage-jq" {
  context    = "../jq"
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS
  contexts = {
    stage-base = "target:stage-base"
  }
}

target "stage-gh" {
  context    = "../gh"
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS
  args = {
    UPSTREAM_VERSION = GH_VERSION
  }
  contexts = {
    stage-base = "target:stage-base"
  }
}

target "stage-dart-sass" {
  context    = "../dart-sass"
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS
  args = {
    UPSTREAM_VERSION = "1.77.1"
  }
  contexts = {
    stage-base = "target:stage-base"
  }
}

target "stage-s6-overlay" {
  context   = "../s6-overlay"
  platforms = PLATFORMS
  args = {
    S6_OVERLAY_VERSION = S6_OVERLAY_VERSION
    S6_DIR             = S6_DIR
  }
  contexts = {
    common = "../common"
    stage-base = "target:stage-base"
  }
}

target "php70-fpm-apache" {
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS
  tags = ["${REGISTRY_NAME}:${TAG}"]
  contexts = {
    common = "../common"
    apache = "../apache"
    stage-base       = "target:stage-base"
    stage-gh         = "target:stage-gh"
    stage-jq         = "target:stage-jq"
    stage-dart-sass  = "target:stage-dart-sass"
    stage-s6-overlay = "target:stage-s6-overlay"
  }
  args = {
    S6_DIR                    = S6_DIR
    PACKAGES_APACHE           = "libfcgi-bin apache2 locales procps git zip openssh-client"
    PHP_EXTENSIONS            = "mysqli opcache pcntl pdo_mysql zip bcmath intl ldap soap mcrypt apcu calendar exif gd imagick sodium"
    REPOSITORY_BUILD_VERSION  = "dev"
    PHP_EXT_INSTALLER_VERSION = PHP_EXT_INSTALLER_VERSION
  }
}