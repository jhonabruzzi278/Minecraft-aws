# Limpieza total de infraestructura AWS (CloudFormation / Terraform / S3)

Clear-Host
Write-Host "============================================================" -ForegroundColor Red
Write-Host " [CLEAN] LIMPIEZA TOTAL DE INFRAESTRUCTURA AWS (Duoc UC)" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Red

Write-Host "`nEste script eliminara:" -ForegroundColor Yellow
Write-Host " - Stacks de CloudFormation ('cf-duoc-cloud-native')" -ForegroundColor Gray
Write-Host " - Recursos de Terraform (VPC, EC2, NAT, DynamoDB)" -ForegroundColor Gray
Write-Host " - Archivos en Buckets S3 de Frontend y Backups" -ForegroundColor Gray

$confirm = Read-Host "`nEstas seguro de que deseas destruir todo y limpiar la cuenta? (S/n)"
if ($confirm -ne "" -and $confirm -ne "s" -and $confirm -ne "S") {
    Write-Host "`nOperacion cancelada por el usuario." -ForegroundColor Yellow
    exit 0
}

# 1. Vaciar Buckets S3 para que no bloqueen la eliminacion
Write-Host "`n[1/3] Vaciando Buckets S3 del proyecto..." -ForegroundColor Cyan
$buckets = aws s3api list-buckets --query "Buckets[?contains(Name, 'cloud-native-duoc') || contains(Name, 'mc-backups') || contains(Name, 'frontend')].Name" --output text 2>$null
if ($buckets) {
    foreach ($b in $buckets -split "\s+") {
        if ($b -and $b -notmatch "None") {
            Write-Host "  -> Vaciando s3://$b ..." -ForegroundColor DarkGray
            aws s3 rm "s3://$b" --recursive 2>$null
        }
    }
}

# 2. Destruir Stack de CloudFormation
Write-Host "`n[2/3] Verificando y eliminando Stack de CloudFormation..." -ForegroundColor Cyan
$stackStatus = aws cloudformation describe-stacks --stack-name cf-duoc-cloud-native --query "Stacks[0].StackStatus" --output text 2>$null
if ($stackStatus -and $stackStatus -notmatch "None" -and $stackStatus -notmatch "DOES_NOT_EXIST") {
    Write-Host "  -> Eliminando stack 'cf-duoc-cloud-native' (Estado: $stackStatus)..." -ForegroundColor Yellow
    aws cloudformation delete-stack --stack-name cf-duoc-cloud-native
    Write-Host "  -> Esperando confirmacion de eliminacion de AWS..." -ForegroundColor DarkGray
    aws cloudformation wait stack-delete-complete --stack-name cf-duoc-cloud-native
    Write-Host "  [OK] Stack de CloudFormation eliminado con exito." -ForegroundColor Green
} else {
    Write-Host "  (No se encontro stack activo de CloudFormation)." -ForegroundColor DarkGray
}

# 3. Destruir con Terraform (si hay estado local)
Write-Host "`n[3/3] Ejecutando Terraform Destroy (si aplica)..." -ForegroundColor Cyan
$tfDir = Join-Path (Split-Path $PSScriptRoot -Parent) "terraform"
if (!(Test-Path $tfDir)) { $tfDir = Join-Path $PSScriptRoot "terraform" }

if (Test-Path (Join-Path $tfDir ".terraform")) {
    terraform -chdir=$tfDir destroy -auto-approve 2>$null
    Write-Host "  [OK] Limpieza de Terraform completada." -ForegroundColor Green
} else {
    Write-Host "  (Terraform no tiene estado activo local)." -ForegroundColor DarkGray
}

# 4. Auditoria Final de Verificacion
Write-Host "`n[?] Ejecutando auditoria final de confirmacion..." -ForegroundColor Cyan
$auditScript = Join-Path $PSScriptRoot "audit-aws.ps1"
if (Test-Path $auditScript) {
    & $auditScript
}
