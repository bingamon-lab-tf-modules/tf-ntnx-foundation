terraform {

  required_version = ">= 1.11.0"

  required_providers {
    nutanix = {
      source  = "nutanix/nutanix"
      version = "~> 2.5.1"
    }
  }

}
