target "_vat" {
  context = "."
  labels = {
    "org.vat.plugin.s6-overlay" = "vat://s6-overlay"
  }
}

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
  type = string
  default= "linux/arm64,linux/amd64"
}

# VAT Registry Variables
variable "REGISTRY" {
  type    = string
  default = "docker.io"
}

variable "USERNAME" {
  type    = string
  default = "deviscoding"
}

variable "TAG" {
  type    = string
  default = "latest"
}

variable "IMAGE" {
  type    = string
  default = "${USERNAME}/php${PHP_MAJOR}.${PHP_MINOR}-fpm-apache"
}

# VAT Build Variables
variable "VAT_DIR" {
  type = string
  default = "."
}

variable "VAT_EXECUTABLES" {
  type = list(string)
  default = ["git", "curl", "zip"]
}

variable "VAT_PACKAGES" {
  type = list(string)
  default = ["libfcgi-bin", "apache2", "locales", "procps", "curl", "netcat-openbsd", "git", "zip", "openssh-client", "nano", "vim"]
}

variable "APP_EXECUTABLES" {
  type = list(string)
  default = []
}

variable "APP_PACKAGES" {
  type = list(string)
  default = []
}

variable "APP_PLUGINS" {
  type = list(string)
  default = []
}

variable "PHP_EXTENSIONS" {
  type = list(string)
  default = ["mysqli", "opcache", "pcntl", "pdo_mysql", "zip", "bcmath", "intl", "ldap", "soap", "mcrypt", "apcu", "calendar", "exif", "gd", "imagick", "sodium"]
}

variable "PHP_EXT_INSTALLER_VERSION" {
  default = "2.9.27"
}

# Add this to your main root docker-bake.hcl
target "common" {
  context = "${VAT_DIR}/common"
}

target "apache" {
  context = "${VAT_DIR}/apache"
}

// target "stage-slim" {
//   matrix = {
//     os = ["jessie", "stretch", "bookworm", "bullseye", "trixie"]
//   }

//   name       = "stage-slim-${os}"
//   context    = "./base/${os}"
//   dockerfile = "slim.Dockerfile"
//   platforms = split(",", PLATFORMS)

//   args = {
//     OS_VERSION                = "${os}"
//     CORE_PACKAGES             = join(" ", PACKAGES)
//     CORE_EXTENSIONS           = join(" ", CORE_EXTENSIONS)
//     APP_EXTENSIONS            = join(" ", APP_EXTENSIONS)
//     APP_PACKAGES              = join(" ", APP_PACKAGES)
//   }

//   contexts = {
//     "common" = "./common"
//   }
// }

# Base OS Image
target "stage-base" {
  matrix     = { os = OS_MATRIX }
  name       = "stage-base-${os}"
  context    = "${VAT_DIR}/base"
  dockerfile = "Dockerfile"
  platforms = split(",", PLATFORMS)

  args = {
    OS_VERSION      = "${os}"
    PHP_VERSION     = "${PHP_MAJOR}.${PHP_MINOR}"
  }

  contexts = {
    "common" = "${VAT_DIR}/common"
  }
}

group "default" {
  targets = (PHP_MAJOR != "" && OS_VERSION != "") ? ["php-target"] : (
  (PHP_MAJOR == "" && OS_VERSION == "") ? ["php"] : ["os-target"]
  )
}

function "resolve_image" {
  params = [input_image]
  result = input_image == "" ? "${USERNAME}/php${PHP_MAJOR}.${PHP_MINOR}-fpm-apache" : "${input_image}"
}

target "php" {
  matrix = {
    version = ["56", "70", "71", "74", "80", "81", "83", "84", "85"]
    os      = OS_MATRIX
  }

  name       = "vat-php${version}-${os}"
  context    = "${VAT_DIR}/php-fpm-apache"
  dockerfile = "Dockerfile"
  platforms  = split(",", PLATFORMS)

  tags = [
    "${resolve_image(IMAGE)}:${TAG}"
  ]

  contexts = {
    common           = "${VAT_DIR}/common"
    apache           = "${VAT_DIR}/apache"
    php              = "${VAT_DIR}/php"
    stage-base       = "target:stage-base-${os}"
    stage-composer   = "docker-image://composer:${int(version) <= 71 ? "2.2" : "latest"}"
  }

  args = {
    HEALTHCHECK_SILENCE       = parseint(version, 10) >= 82 ? "modern" : "legacy"
    OS_VERSION                = "${os}"
    PHP_VERSION               = "${substr(version, 0, 1)}.${substr(version, 1,-1)}"
    APP_PACKAGES              = join(" ", APP_PACKAGES)
    PACKAGES                  = join(" ", distinct(concat(VAT_PACKAGES, APP_PACKAGES)))
    EXECUTABLES               = join(" ", distinct(concat(VAT_EXECUTABLES, APP_EXECUTABLES)))
    PHP_EXTENSIONS            = join(" ", PHP_EXTENSIONS)
    PHP_EXT_INSTALLER_VERSION = PHP_EXT_INSTALLER_VERSION
  }
}

target "php-target" {
  inherits = ["vat-php${PHP_MAJOR}${PHP_MINOR}-${OS_VERSION}"]
}