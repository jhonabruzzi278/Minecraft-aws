import boto3
import time

ssm = boto3.client("ssm", region_name="us-east-1")
nat_id = "i-01e7c51954df80fc3"

# Configurar online-mode=false y white-list=false (o permisivo)
script = """
if [ -f /opt/minecraft/server.properties ]; then
    sed -i 's/online-mode=true/online-mode=false/g' /opt/minecraft/server.properties
    if ! grep -q "online-mode=false" /opt/minecraft/server.properties; then
        echo "online-mode=false" >> /opt/minecraft/server.properties
    fi
    echo "✓ online-mode=false configurado en server.properties"
    systemctl restart purpur
    echo "✓ Servicio Purpur reiniciado con éxito."
fi
"""

print("Configurando online-mode=false en la instancia de Minecraft...")
try:
    resp = ssm.send_command(
        InstanceIds=[nat_id],
        DocumentName="AWS-RunShellScript",
        Parameters={"commands": [script]}
    )
    cmd_id = resp["Command"]["CommandId"]
    time.sleep(6)
    inv = ssm.get_command_invocation(CommandId=cmd_id, InstanceId=nat_id)
    print("Estado SSM:", inv.get("Status"))
    print("Salida:", inv.get("StandardOutputContent"))
except Exception as e:
    print("Error SSM:", e)
