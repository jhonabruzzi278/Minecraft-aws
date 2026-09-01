# Sincroniza el frontend web estatico con el Bucket S3 configurado para Website Hosting
param(
    [string]$BucketName
)

Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [SYNC] Publicador de Frontend a Amazon S3 (Website Hosting)" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($BucketName)) {
    $cfnBucket = aws cloudformation describe-stacks --stack-name cf-duoc-cloud-native --query "Stacks[0].Outputs[?OutputKey=='FrontendWebsiteBucket'].OutputValue" --output text 2>$null
    if ($cfnBucket -and $cfnBucket -notmatch "None") {
        $BucketName = $cfnBucket
        Write-Host "[+] Bucket detectado desde CloudFormation: $BucketName" -ForegroundColor Green
    } else {
        $BucketName = Read-Host "Ingresa el nombre del Bucket S3 de Frontend"
    }
}

if ([string]::IsNullOrWhiteSpace($BucketName)) {
    Write-Host "[ERROR] Nombre de bucket invalido." -ForegroundColor Red
    exit 1
}

$frontendDir = Join-Path (Split-Path $PSScriptRoot -Parent) "frontend"
if (!(Test-Path $frontendDir)) {
    $frontendDir = Join-Path $PSScriptRoot "frontend"
}

if (!(Test-Path $frontendDir)) {
    Write-Host "[ERROR] No se encontro la carpeta de frontend en $frontendDir" -ForegroundColor Red
    exit 1
}

Write-Host "`n[*] Sincronizando archivos desde $frontendDir hacia s3://$BucketName/ ..." -ForegroundColor Cyan
aws s3 sync $frontendDir "s3://$BucketName/" --delete

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] Frontend publicado exitosamente en Amazon S3!" -ForegroundColor Green
    Write-Host "URL del Sitio Web: http://$BucketName.s3-website-us-east-1.amazonaws.com" -ForegroundColor White
} else {
    Write-Host "`n[WARN] Error al sincronizar con S3." -ForegroundColor Red
}

Write-Host "============================================================" -ForegroundColor Cyan
