# Auditoria de recursos activos en AWS (Duoc UC Cloud Native)

Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [?] AUDITORIA DE RECURSOS ACTIVOS EN AWS" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Identidad
Write-Host "`n[1] Sesion e Identidad AWS:" -ForegroundColor White
aws sts get-caller-identity --output table

# 2. CloudFormation
Write-Host "`n[2] Stacks de CloudFormation Activos:" -ForegroundColor White
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE --query "StackSummaries[*].[StackName,StackStatus,CreationTime]" --output table

# 3. Instancias EC2
Write-Host "`n[3] Instancias EC2:" -ForegroundColor White
aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,PrivateIpAddress]" --output table

# 4. Volumenes EBS
Write-Host "`n[4] Discos y Volumenes EBS:" -ForegroundColor White
aws ec2 describe-volumes --query "Volumes[*].[VolumeId,State,Size,VolumeType,Attachments[0].InstanceId]" --output table

# 5. VPCs
Write-Host "`n[5] VPCs Activas:" -ForegroundColor White
aws ec2 describe-vpcs --query "Vpcs[*].[VpcId,CidrBlock,IsDefault]" --output table

# 6. Buckets S3
Write-Host "`n[6] Buckets S3:" -ForegroundColor White
aws s3 ls

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " [OK] Auditoria finalizada exitosamente." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
