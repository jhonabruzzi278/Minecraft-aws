# ============================================================
# 1. MÓDULO DE STORAGE (DynamoDB & S3 Buckets)
# ============================================================
module "storage" {
  source = "./modules/storage"

  environment  = var.environment
  project_name = var.project_name
}

# ============================================================
# 2. MÓDULO DE NETWORKING (VPC, Subredes, Tablas de Rutas)
# ============================================================
module "networking" {
  source = "./modules/networking"

  environment           = var.environment
  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
}

# ============================================================
# 3. MÓDULO DE SEGURIDAD (SSM Parameter & Security Groups)
# ============================================================
module "security" {
  source = "./modules/security"

  environment           = var.environment
  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  vpc_cidr              = var.vpc_cidr
  private_subnet_1_cidr = var.private_subnet_1_cidr
  rcon_password         = var.rcon_password
}

# ============================================================
# 4. MÓDULO DE CÓMPUTO (EC2 NAT/Minecraft, Backend, CloudWatch)
# ============================================================
module "compute" {
  source = "./modules/compute"

  environment            = var.environment
  project_name           = var.project_name
  instance_type          = var.instance_type
  instance_profile_name  = var.instance_profile_name
  public_subnet_id       = module.networking.public_subnet_id
  private_subnet_1_id    = module.networking.private_subnet_1_id
  nat_minecraft_sg_id    = module.security.nat_minecraft_sg_id
  backend_sg_id          = module.security.backend_sg_id
  private_route_table_id = module.networking.private_route_table_id
  rcon_password          = var.rcon_password
  backups_bucket_name    = module.storage.backups_bucket_name
}
