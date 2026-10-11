locals {
  name = "shopfast-ha"

  instances = {
    instance_1 = {
      label = "Instance 1"
      az    = "us-east-2a"
      cidr  = "10.0.1.0/24"
    }
    instance_2 = {
      label = "Instance 2"
      az    = "us-east-2b"
      cidr  = "10.0.2.0/24"
    }
  }
}
