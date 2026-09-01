# 🎮 Documentación Técnica de Laboratorio: Tu Propio Servidor Minecraft & Panel Cloud Native

**Institución:** Duoc UC  
**Asignatura:** Cloud Native  
**Autor:** Jonathan Guerra  
**Región AWS:** `us-east-1` (N. Virginia)  
**Entorno:** AWS Academy Learner Lab  

---

## 📑 Tabla de Contenidos
1. [Resumen Ejecutivo del Proyecto](#1-resumen-ejecutivo-del-proyecto)
2. [Estructura Limpia y Modular del Proyecto](#2-estructura-limpia-y-modular-del-proyecto)
3. [Arquitectura de Red y Software (3 Capas + Serverless)](#3-arquitectura-de-red-y-software-3-capas--serverless)
4. [Infraestructura como Código (IaC Dual)](#4-infraestructura-como-código-iac-dual)
5. [Persistencia de Datos y Protocolo RCON](#5-persistencia-de-datos-y-protocolo-rcon)
6. [Bitácora de Bugs Encontrados y Soluciones Técnicas](#6-bitácora-de-bugs-encontrados-y-soluciones-técnicas)
7. [Galería de Diagramas Editoriales](#7-galería-de-diagramas-editoriales)
8. [Scripts de Automatización y Operaciones](#8-scripts-de-automatización-y-operaciones)
9. [Pipeline CI/CD y Limpieza Automatizada](#9-pipeline-cicd-y-limpieza-automatizada)

---

## 1. Resumen Ejecutivo del Proyecto

Este laboratorio implementa una arquitectura **Cloud Native empresarial de 3 capas** en Amazon Web Services (AWS) que combina:
- **Infraestructura como Código (IaC)** dual utilizando **AWS CloudFormation** y **HashiCorp Terraform (Modular)**.
- Un servidor de juegos multijugador de alto rendimiento **Minecraft Purpur 1.21.4** con soporte multiversión (**ViaVersion v5.11.0**) sobre **Amazon Linux 2023** y **Amazon Corretto Java 21 LTS**.
- Una **NAT Instance** personalizada configurada con `iptables MASQUERADE` y reenvío IPv4.
- Una **API REST en Python (Flask)** con **persistencia de datos en SQLite y DynamoDB** ubicada en una **subred privada aislada**, conectada al servidor de juegos mediante el protocolo **RCON** para gestión automatizada de *Whitelist* y consola en tiempo real.
- Un **Frontend Web** moderno con estética *Dark Mode Glassmorphism* y Consola RCON interactiva.
- Gestión y administración 100% remota sin puertos SSH abiertos vía **AWS Systems Manager (SSM)**.

---

## 2. Estructura Limpia y Modular del Proyecto

```text
├── README.md                          # Manual general
├── DOCUMENTACION_PROYECTO_AWS_MINECRAFT.md # Bitácora técnica
├── backend/                           # API Flask, Dockerfile, docker-compose.yml
├── frontend/                          # HTML5, CSS3, JS Glassmorphism
├── cloudformation/                    # Template All-in-One cd-cloud-native-duoc.yaml
├── terraform/                         # Terraform modular (4 módulos)
├── scripts/                           # set-credentials, audit-aws, clean-all-aws, sync-s3
├── diagrams/                          # 5 diagramas interactivos HTML/SVG
└── .github/workflows/                 # Pipelines CI/CD de despliegue y destrucción
```

---

## 3. Arquitectura de Red y Software (3 Capas + Serverless)

```text
┌──────────────────────────────────────────────────────────────┐
│  🌐 INTERNET (Jugadores & Administradores)                   │
└──────────────────────────────┬───────────────────────────────┘
                               │ (Puerto 25565 / HTTP)
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  🟢 1. CAPA PÚBLICA (10.0.1.0/24 - AZ us-east-1a)            │
│  • EC2 NAT Instance + Servidor Minecraft (54.81.175.12)      │
│  • PurpurMC 1.21.4 + Plugin ViaVersion (1.20 - 1.21.4+)      │
│  • iptables MASQUERADE (Enrutador de salida para la VPC)     │
│  • CloudWatch Agent (RAM/Swap/Disco) + Alarma Auto-Healing   │
│  • Cron de Respaldo Automatizado a S3 Versionado (6h)        │
└──────────────────────────────┬───────────────────────────────┘
                               │ (RCON Puerto 25575 / Tráfico Interno)
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  🔒 2. CAPA PRIVADA DE APLICACIÓN (10.0.2.0/24 - AZ a)       │
│  • EC2 Backend Flask API (:8081) con Docker & Gunicorn       │
│  • Autenticación de Administrador con JWT (Tokens firmados)  │
│  • Consola RCON interactiva con botones rápidos en la Web    │
│  • Salida a Internet a través de la NAT Instance             │
└──────────────────────────────┬───────────────────────────────┘
                               │ (Llamadas Boto3 / Tráfico Seguro)
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  ⚡ 3. CAPA SERVERLESS & STORAGE DE AWS                      │
│  • Amazon DynamoDB: Tabla UsuariosMinecraft (PAY_PER_REQUEST)│
│  • Amazon S3 Website: Hosting estático para el Dashboard     │
│  • Amazon S3 Backups: Almacenamiento versionado del mundo    │
│  • AWS SSM Parameter Store: /minecraft/rcon_password         │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Infraestructura como Código (IaC Dual)

### 4.1. AWS CloudFormation ([cloudformation/cd-cloud-native-duoc.yaml](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/cloudformation/cd-cloud-native-duoc.yaml))
* Despliegue en 1 solo comando:
  ```powershell
  aws cloudformation create-stack `
    --stack-name cf-duoc-cloud-native `
    --template-body file://cloudformation/cd-cloud-native-duoc.yaml `
    --parameters ParameterKey=OwnerName,ParameterValue="Jonathan"
  ```

### 4.2. HashiCorp Terraform Modular ([terraform/](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/terraform/))
* Despliegue:
  ```powershell
  cd terraform
  cp terraform.tfvars.example terraform.tfvars
  terraform init
  terraform apply -auto-approve
  ```

---

## 5. Persistencia de Datos y Protocolo RCON

El backend de Python ([backend/app.py](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/backend/app.py)) implementa:
1. **Base de Datos SQLite (`usuarios.db`) & DynamoDB:**
   - Tabla `usuarios` con integridad de datos y sembrado automático.
2. **Cliente MCRcon & Consola Web:**
   - Comunicación directa por socket TCP seguro al puerto `25575`.
   - Auto-whitelist en tiempo real al registrar usuarios.
   - Botones rápidos para control del clima, hora y modos de juego.

---

## 6. Bitácora de Bugs Encontrados y Soluciones Técnicas

| # | Error / Síntoma | Causa Raíz | Solución Implementada |
|---|---|---|---|
| 1 | **Fallo de lectura de credenciales AWS CLI** | PowerShell 5.1 guarda archivos UTF-8 con BOM `EF BB BF`, corrompiendo el parser INI. | Escritura limpia en UTF-8 sin BOM mediante .NET `System.Text.UTF8Encoding($false)`. |
| 2 | **Fallo de permisos IAM al crear roles** | Restricción de AWS Academy Learner Lab (`iam:CreateRole` denegado). | Se configuró el IAM Instance Profile preexistente `LabInstanceProfile`. |
| 3 | **OutOfMemoryError en EC2 `t3.micro`** | Instancia con 1GB de RAM física. | Se aprovisionó Swap de 2GB (`/swapfile`) y límites Java `-Xms512M -Xmx850M -XX:+UseG1GC`. |
| 4 | **Connection timed out: getsockopt** | Regla final `REJECT all` por defecto en `iptables-services`. | Se prepusieron reglas `ACCEPT` para puertos `25565`, `25575`, `8081` con `iptables -I INPUT 1`. |
| 5 | **Outdated server! I'm still on 1.21.1** | Desajuste de versión entre clientes y servidor. | Se instaló `ViaVersion v5.11.0` permitiendo clientes desde 1.20 hasta 1.21.4+. |
| 6 | **Pérdida de datos en reinicio** | Almacenamiento en memoria RAM volátil. | Se implementó persistencia con SQLite (`usuarios.db`) y DynamoDB. |

---

## 7. Galería de Diagramas Editoriales

Ubicados en la carpeta [`diagrams/`](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/diagrams/index.html):
- **[01_arquitectura_red_aws.html](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/diagrams/01_arquitectura_red_aws.html):** Arquitectura 3 Capas + Serverless.
- **[02_pila_tecnologica_minecraft.html](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/diagrams/02_pila_tecnologica_minecraft.html):** Pila Enterprise de 6 Capas.
- **[03_resolucion_bugs_firewall.html](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/diagrams/03_resolucion_bugs_firewall.html):** Diagnóstico de Firewall y Multiversión.
- **[04_flujo_iac_despliegue.html](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/diagrams/04_flujo_iac_despliegue.html):** Pipeline IaC Dual Enterprise.
- **[05_arquitectura_cicd_servicios_aws.html](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/diagrams/05_arquitectura_cicd_servicios_aws.html):** Pipeline CI/CD y Ecosistema AWS.

---

## 8. Scripts de Automatización y Operaciones

1. **[`scripts/set-credentials.ps1`](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/scripts/set-credentials.ps1):** Detección de portapapeles y actualización de credenciales.
2. **[`scripts/audit-aws.ps1`](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/scripts/audit-aws.ps1):** Auditoría en vivo de recursos activos.
3. **[`scripts/clean-all-aws.ps1`](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/scripts/clean-all-aws.ps1):** Limpieza total de la cuenta.
4. **[`scripts/sync-frontend-s3.ps1`](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/scripts/sync-frontend-s3.ps1):** Publicador del frontend a Amazon S3.

---

## 9. Pipeline CI/CD y Limpieza Automatizada

- **[`.github/workflows/ci-cd-pipeline.yml`](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/.github/workflows/ci-cd-pipeline.yml):** Pipeline automático de validación y despliegue a S3/EC2.
- **[`.github/workflows/destroy-infra.yml`](file:///c:/PC%20JONATHAN/DUOC/cloud%20native/AWS/.github/workflows/destroy-infra.yml):** Workflow manual de destrucción de infraestructura bajo demanda.
