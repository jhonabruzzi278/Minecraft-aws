---
name: aws-cloud-native-lab
description: >-
  Guía operativa, runbooks y automatización para laboratorios de AWS Cloud Native (Duoc UC / AWS Academy).
  Cubre despliegue de VPCs con CloudFormation, NAT Instances, ejecución remota sin SSH vía AWS SSM,
  optimización de instancias micro (Swap/Systemd), configuración de firewall (Security Groups e iptables)
  y despliegue de servicios (Minecraft/Flask).
---

# 🚀 Skill: AWS Cloud Native & Lab Deployer

Esta skill contiene los flujos de trabajo probados, procedimientos paso a paso y soluciones a problemas conocidos al trabajar con **AWS Academy / Learner Lab** y despliegues en **EC2/CloudFormation**.

---

## 1. Gestión de Credenciales y Restricciones de AWS Academy

### Reglas Clave:
1. **Restricción de IAM (`iam:CreateRole`):**
   * En AWS Academy no está permitido crear nuevos IAM Roles o Instance Profiles.
   * **Solución:** Siempre reutilizar el perfil existente `LabInstanceProfile` (asociado a `LabRole`).
2. **Escritura de Credenciales en Windows:**
   * Evitar `Set-Content -Encoding UTF8` en PowerShell clásico (añade BOM que corrompe el parser de AWS CLI).
   * **Solución:** Escribir sin BOM en UTF-8 o usar `aws configure set` / variables de entorno.
3. **Verificación rápida de identidad:**
   ```bash
   aws sts get-caller-identity
   ```

---

## 2. Despliegue de Red con CloudFormation (VPC + NAT Instance)

### Arquitectura Estándar Todo-en-Uno:
* **VPC:** `10.0.0.0/16` con DNS hostnames activado.
* **Subred Pública:** `10.0.1.0/24` (con IGW y tabla de rutas pública).
* **Subredes Privadas:** `10.0.2.0/24` y `10.0.3.0/24` (enrutadas a la NAT Instance).
* **NAT Instance:** EC2 `t3.micro` con Amazon Linux 2023, `SourceDestCheck: false` e IP pública dinámica.

### Validación y Despliegue:
```powershell
# 1. Validar sintaxis
aws cloudformation validate-template --template-body file://cd-cloud-native-duoc.yaml

# 2. Desplegar Stack
aws cloudformation create-stack `
  --stack-name cf-duoc-cloud-native `
  --template-body file://cd-cloud-native-duoc.yaml `
  --parameters ParameterKey=OwnerName,ParameterValue="Jonathan"
```

---

## 3. Administración Remota de EC2 mediante AWS Systems Manager (SSM)

No se requiere abrir el puerto 22 ni crear pares de claves SSH (`.pem`).

### Iniciar sesión interactiva en la terminal:
```powershell
aws ssm start-session --target <InstanceId>
```

### Ejecutar comandos en segundo plano desde scripts / CLI:
```powershell
aws ssm send-command `
  --instance-ids "<InstanceId>" `
  --document-name "AWS-RunShellScript" `
  --parameters '{"commands": ["systemctl status minecraft --no-pager"]}'
```

---

## 4. Optimización de Instancias `t3.micro` (1 GB RAM)

Para ejecutar aplicaciones exigentes (como Java, Minecraft o compilaciones) en `t3.micro`:

### A. Configurar Memoria Swap (2 GB):
```bash
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
```

### B. Crear un Servicio `systemd` para aplicaciones:
```ini
[Unit]
Description=Mi Aplicacion Cloud Native
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mi-app
ExecStart=/usr/bin/java -Xms512M -Xmx850M -XX:+UseG1GC -jar server.jar nogui
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

## 5. Troubleshooting y Resolución de Problemas Frecuentes

| Problema | Causa Raíz | Solución |
|---|---|---|
| **`Connection timed out: getsockopt`** | `iptables-services` tiene una regla `REJECT` por defecto en Linux. | Insertar `iptables -I INPUT 1 -p tcp --dport <PORT> -j ACCEPT` y guardar con `iptables-save`. |
| **`Outdated server! I'm still on...`** | Incompatibilidad de versión del cliente con el servidor. | Instalar el plugin `ViaVersion` en `/opt/minecraft/plugins/` para soportar todas las versiones. |
| **`HTTP Error 410: Gone` en descargas** | Endpoints de API deprecados o sin User-Agent. | Añadir cabecera `User-Agent: Mozilla/5.0` en `urllib.request` o usar endpoints estables. |
| **`RouteAlreadyExists` en CloudFormation** | La tabla de rutas ya contiene una regla para `0.0.0.0/0`. | Eliminar la ruta previa antes de asociar la NAT Instance. |
