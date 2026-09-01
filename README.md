# 🎮 Laboratorio Enterprise: Servidor Minecraft & Suite Cloud Native en AWS

**Institución:** Duoc UC  
**Asignatura:** Cloud Native  
**Autor:** Jonathan Guerra  
**Región AWS:** `us-east-1` (N. Virginia)  
**Presupuesto Lab:** $50 USD (AWS Academy Learner Lab)

Este repositorio contiene una solución empresarial completa **Cloud Native de 3 capas + Serverless** en Amazon Web Services (AWS) estructurada de forma modular, limpia y profesional.

---

## 📁 Estructura del Repositorio

```text
├── README.md                          # 📖 Manual general del proyecto
├── DOCUMENTACION_PROYECTO_AWS_MINECRAFT.md # 📑 Bitácora técnica y resolución de bugs
│
├── scripts/                           # 🛠️ Scripts Operativos y de Automatización
│   ├── set-credentials.ps1            # 🔑 Actualizador de credenciales AWS Academy sin BOM
│   ├── set-credentials.py             # 🔑 Actualizador multiplataforma en Python
│   ├── audit-aws.ps1                  # 🔍 Auditoría en vivo de recursos activos en AWS
│   ├── clean-all-aws.ps1              # 🧹 Destrucción total y limpieza de la cuenta
│   └── sync-frontend-s3.ps1           # 🌐 Publicador del frontend a Amazon S3
│
├── backend/                           # 🐍 Backend Flask API (Containerizado con Docker)
│   ├── app.py                         # API REST con SQLite / DynamoDB y protocolo RCON
│   ├── requirements.txt               # Dependencias de Python
│   ├── Dockerfile                     # Imagen Docker de producción con Gunicorn
│   ├── docker-compose.yml             # Orquestador Docker Compose para la EC2
│   └── .dockerignore                  # Exclusiones de construcción
│
├── frontend/                          # 🌐 Frontend Web Dashboard & Consola RCON
│   ├── index.html                     # Panel interactivo con terminal RCON y modal de login
│   ├── app.js                         # Lógica cliente, JWT storage y auto-whitelist
│   └── styles.css                     # Estilos modernos Dark Mode Glassmorphism
│
├── cloudformation/                    # 📄 Infraestructura como Código (AWS CloudFormation)
│   └── cd-cloud-native-duoc.yaml      # Template All-in-One Enterprise
│
├── terraform/                         # 🛠️ Infraestructura como Código (HashiCorp Terraform)
│   ├── main.tf                        # Orquestador raíz
│   ├── variables.tf                   # Variables con validaciones estrictas
│   ├── outputs.tf                     # Salidas consolidadas
│   ├── providers.tf                   # AWS Provider ~> 5.0 con tags globales
│   ├── terraform.tfvars.example       # Ejemplo de configuración
│   └── modules/                       # 🧩 4 Submódulos desacoplados
│       ├── networking/                # VPC, IGW, 3 Subredes, Tablas de Rutas
│       ├── storage/                   # Tabla DynamoDB y 2 Buckets S3 (Website + Backups)
│       ├── security/                  # SSM Parameter Store y Security Groups
│       └── compute/                   # EC2 NAT/Minecraft, EC2 Backend, Docker, CloudWatch
│
├── diagrams/                          # 🎨 Galería de Diagramas Editoriales (diagram-design)
│   ├── index.html                     # Galería interactiva con 5 diagramas
│   ├── 01_arquitectura_red_aws.html   # Arquitectura 3 Capas + Serverless
│   ├── 02_pila_tecnologica_minecraft.html # Pila Enterprise de 6 Capas
│   ├── 03_resolucion_bugs_firewall.html   # Diagnóstico de Firewall y Multiversión
│   ├── 04_flujo_iac_despliegue.html   # Pipeline IaC Dual Enterprise
│   └── 05_arquitectura_cicd_servicios_aws.html # Pipeline CI/CD y Ecosistema AWS
│
├── .github/                           # 🚀 Automatización DevOps y CI/CD
│   └── workflows/
│       ├── ci-cd-pipeline.yml         # Validación de código, pruebas y despliegue continuo
│       └── destroy-infra.yml          # Destrucción y limpieza bajo demanda
│
└── .agents/                           # 🧠 Skills de Pair Programming
    └── skills/
        ├── aws-cloud-native-lab/
        └── diagram-design/
```

---

## ⚡ Comandos Rápidos de Operación

### 1. Actualizar Credenciales de AWS Academy:
```powershell
.\scripts\set-credentials.ps1
```

### 2. Auditar Recursos Activos en tu Cuenta:
```powershell
.\scripts\audit-aws.ps1
```

### 3. Limpiar / Destruir Todo para no Gastar Créditos:
```powershell
.\scripts\clean-all-aws.ps1
```

---

## 🚀 Despliegue de Infraestructura (IaC)

### Con CloudFormation:
```powershell
aws cloudformation create-stack `
  --stack-name cf-duoc-cloud-native `
  --template-body file://cloudformation/cd-cloud-native-duoc.yaml `
  --parameters ParameterKey=OwnerName,ParameterValue="Jonathan"
```

### Con Terraform Modular:
```powershell
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply -auto-approve
```

---

## 🌐 Publicar el Frontend en Amazon S3
```powershell
.\scripts\sync-frontend-s3.ps1
```
