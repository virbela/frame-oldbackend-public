########################
# Get the connection string:
locals {
  private_endpoints = flatten([for cs in mongodbatlas_cluster.cluster_auth.connection_strings : cs.private_endpoint])

  connection_strings = [
    for pe in local.private_endpoints : pe.srv_connection_string
    if contains([for e in pe.endpoints : e.endpoint_id], aws_vpc_endpoint.vpce_auth.id)
  ]

  csbase = local.connection_strings[0]
}

data "mongodbatlas_roles_org_id" "org_id" {
}
output "orginfo" {
  value = data.mongodbatlas_roles_org_id.org_id
}

resource "mongodbatlas_project" "project_id" {
  name   = "FrameVR ${var.deployment_group}"
  org_id = data.mongodbatlas_roles_org_id.org_id.id

  lifecycle {
    prevent_destroy = true
  }
}
output "projinfo" {
  value = mongodbatlas_project.project_id
}

# authentication database for scram is "admin"
# https://www.mongodb.com/docs/atlas/security-add-mongodb-users/
resource "mongodbatlas_database_user" "dbuser" {
  username           = random_string.dbuser.id
  password           = random_password.dbuser_pass.result
  project_id         = mongodbatlas_project.project_id.id
  auth_database_name = "admin"

  roles {
    role_name     = "readWriteAnyDatabase"
    database_name = "admin"
  }

}

resource "random_string" "dbuser" {
  # example: 99fjmipc
  length  = 8
  special = false
  upper   = false
}

# Create a Database Password
resource "random_password" "dbuser_pass" {
  length  = 16
  special = false
}

########################
# MongoDB cluster
########################
resource "mongodbatlas_cluster" "cluster_auth" {
  project_id   = mongodbatlas_project.project_id.id
  name         = "frame-immer-${var.deployment_group}"
  cluster_type = "REPLICASET"
  # monbgoDB requires region to be the format: US_EAST_1
  provider_region_name = upper(replace(data.aws_region.current_region.name, "-", "_"))
  #provider_region_name = "AP_NORTHEAST_2"

  # replication_specs {
  #   num_shards = 1
  #   regions_config {
  #     #region_name     = "US_EAST_1"
  #     region_name     = "AP_NORTHEAST_2"
  #     electable_nodes = 3
  #     priority        = 7
  #     read_only_nodes = 0
  #   }
  # }
  cloud_backup                 = true
  auto_scaling_disk_gb_enabled = true
  mongo_db_major_version       = "5.0"

  provider_name               = "AWS"
  disk_size_gb                = 10
  provider_instance_size_name = "M10"

  depends_on = [mongodbatlas_privatelink_endpoint_service.pe_auth_service]

  lifecycle {
    prevent_destroy = true
  }
}

resource "mongodbatlas_privatelink_endpoint" "pe_auth" {
  project_id    = mongodbatlas_project.project_id.id
  provider_name = "AWS"
  region        = data.aws_region.current_region.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_vpc_endpoint" "vpce_auth" {
  vpc_id             = var.vpc.id
  service_name       = mongodbatlas_privatelink_endpoint.pe_auth.endpoint_service_name
  vpc_endpoint_type  = "Interface"
  subnet_ids         = ["${var.sn_public.id}", "${var.sn_private.id}"]
  security_group_ids = [aws_security_group.sg_mongo_auth.id]

  tags = {
    Name = var.deployment_group
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "mongodbatlas_privatelink_endpoint_service" "pe_auth_service" {
  project_id          = mongodbatlas_privatelink_endpoint.pe_auth.project_id
  private_link_id     = mongodbatlas_privatelink_endpoint.pe_auth.id
  endpoint_service_id = aws_vpc_endpoint.vpce_auth.id
  provider_name       = "AWS"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "sg_mongo_auth" {
  name   = "${var.deployment_group}-mongo-sg-auth"
  vpc_id = var.vpc.id

  # inbound all
  ingress {
    protocol         = "-1" # any
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # outbound all
  egress {
    protocol         = "-1" # any
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = var.deployment_group
  }

  lifecycle {
    prevent_destroy = true
  }
}