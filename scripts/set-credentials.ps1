# Actualizador automatizado de credenciales de AWS Academy (Learner Lab)
param(
    [string]$CredentialsText
)

Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [KEY] Actualizador de Credenciales AWS Academy - Duoc UC" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Asegurar carpeta .aws
$awsDir = Join-Path $HOME ".aws"
if (!(Test-Path $awsDir)) {
    New-Item -ItemType Directory -Path $awsDir -Force | Out-Null
}

# 2. Obtener credenciales
if ([string]::IsNullOrWhiteSpace($CredentialsText)) {
    $clipboard = Get-Clipboard -ErrorAction SilentlyContinue
    if ($clipboard -and $clipboard -match "aws_access_key_id") {
        Write-Host "`n[+] Se detectaron credenciales en el portapapeles:" -ForegroundColor Green
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host $clipboard -ForegroundColor Gray
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        $confirm = Read-Host "Deseas usar estas credenciales? (S/n)"
        if ($confirm -eq "" -or $confirm -eq "s" -or $confirm -eq "S") {
            $CredentialsText = $clipboard
        }
    }
}

if ([string]::IsNullOrWhiteSpace($CredentialsText)) {
    Write-Host "`n[*] Pega a continuacion el bloque de credenciales de AWS Academy" -ForegroundColor Yellow
    Write-Host "    (Presiona ENTER, luego escribe 'FIN' y presiona ENTER para terminar):`n" -ForegroundColor DarkYellow
    
    $lines = @()
    while ($true) {
        $line = Read-Host
        if ($line -eq "FIN" -or $line -eq "fin") { break }
        $lines += $line
    }
    $CredentialsText = $lines -join "`n"
}

if ([string]::IsNullOrWhiteSpace($CredentialsText) -or $CredentialsText -notmatch "aws_access_key_id") {
    Write-Host "`n[ERROR] No se proporcionaron credenciales validas." -ForegroundColor Red
    exit 1
}

# 3. Guardar ~/.aws/credentials en UTF-8 SIN BOM
$credPath = Join-Path $awsDir "credentials"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$cleanContent = $CredentialsText.Trim().Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($credPath, $cleanContent, $utf8NoBom)

# 4. Asegurar ~/.aws/config con us-east-1
$configPath = Join-Path $awsDir "config"
$configContent = "[default]`nregion = us-east-1`noutput = json"
[System.IO.File]::WriteAllText($configPath, $configContent, $utf8NoBom)

Write-Host "`n[OK] Archivo ~/.aws/credentials actualizado con exito." -ForegroundColor Green

# 5. Validar con AWS STS
Write-Host "`n[?] Validando identidad con AWS STS..." -ForegroundColor Cyan
try {
    $identity = aws sts get-caller-identity 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[OK] AUTENTICACION EXITOSA!" -ForegroundColor Green
        Write-Host $identity -ForegroundColor White
    } else {
        Write-Host "`n[WARN] Error de autenticacion AWS CLI:" -ForegroundColor Red
        Write-Host $identity -ForegroundColor Red
    }
} catch {
    Write-Host "`n[ERROR] No se pudo ejecutar aws cli" -ForegroundColor Red
}

Write-Host "`n============================================================" -ForegroundColor Cyan
