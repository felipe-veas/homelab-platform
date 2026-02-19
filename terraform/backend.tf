terraform {
  cloud {
    organization = "idenx-platform"

    workspaces {
      name = "homelab-platform"
    }
  }
}
