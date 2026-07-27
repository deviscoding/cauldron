variable "OS_MATRIX" {
  type = list(string)
  default = ["jessie", "stretch", "bookworm", "bullseye", "trixie"]
}

# VAT Inherited Variables
variable "PHP_MAJOR" {
  type    = string
  default = "8"
}

variable "PHP_MINOR" {
  type    = string
  default = "5"
}

variable "OS_VERSION" {
  type = string
  default = "trixie"
}

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

variable "PHP_EXT_INSTALLER_VERSION" {
  default = "2.7.0"
}

variable "IMAGE_NAME" {
  default = "${USERNAME}/php${PHP_MAJOR}.${PHP_MINOR}-fpm-apache"
}
}

variable "REGISTRY_NAME" {
  default = notequal(DOCKERHUB_USER, "") ? "${DOCKERHUB_USER}/${IMAGE_NAME}" : IMAGE_NAME
}

target "stage-base" {
  matrix     = { os = OS_MATRIX }
  name       = "stage-base-${os}"
  context    = "./base"
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS
  args = {
    OS_VERSION      = "${os}"
    PHP_VERSION     = "${PHP_MAJOR}.${PHP_MINOR}"
  }
  contexts = {
    common = "./common"
  }
}

target "php70-fpm-apache" {
  matrix = {
    version = ["56", "70", "71", "74", "80", "81", "83", "84", "85"]
    os      = OS_MATRIX
  }
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS
  tags = ["${REGISTRY_NAME}:${TAG}"]
  contexts = {
    common = "./common"
    apache = "./apache"
    php    = "./php"
    stage-base       = "target:stage-base"
    stage-gh         = "target:stage-gh"
    stage-jq         = "target:stage-jq"
    stage-dart-sass  = "target:stage-dart-sass"
    stage-s6-overlay = "target:stage-s6-overlay"
  }
  args = {
    S6_DIR                    = S6_DIR
    OS_VERSION                = "${os}"
    PHP_VERSION               = "${substr(version, 0, 1)}.${substr(version, 1,-1)}"
    PACKAGES_APACHE           = "libfcgi-bin apache2 locales procps git zip openssh-client"
    PHP_EXTENSIONS            = "mysqli opcache pcntl pdo_mysql zip bcmath intl ldap soap mcrypt apcu calendar exif gd imagick sodium"
    REPOSITORY_BUILD_VERSION  = "dev"
    PHP_EXT_INSTALLER_VERSION = PHP_EXT_INSTALLER_VERSION
  }
}