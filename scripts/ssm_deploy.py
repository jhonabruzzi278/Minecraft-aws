import boto3
import time

ssm = boto3.client("ssm", region_name="us-east-1")

def run_commands(instance_id, commands, description="SSM Command"):
    print(f"\n[*] Enviando comandos a {instance_id} ({description})...")
    response = ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName="AWS-RunShellScript",
        Parameters={"commands": commands}
    )
    cmd_id = response["Command"]["CommandId"]
    print(f"    Command ID: {cmd_id}")
    
    time.sleep(3)
    for _ in range(30):
        try:
            inv = ssm.get_command_invocation(CommandId=cmd_id, InstanceId=instance_id)
            status = inv.get("Status")
            if status in ["Success", "Failed", "Cancelled", "TimedOut"]:
                print(f"[+] Estado final: {status}")
                stdout = inv.get("StandardOutputContent", "")
                stderr = inv.get("StandardErrorContent", "")
                if stdout:
                    print(f"--- STDOUT ---\n{stdout}")
                if stderr:
                    print(f"--- STDERR ---\n{stderr}")
                return status == "Success"
        except Exception:
            pass
        time.sleep(3)
    return False

if __name__ == "__main__":
    nat_id = "i-01e7c51954df80fc3"
    backend_id = "i-0dfed23a838b96dcc"
    
    # 1. Verificar Minecraft
    run_commands(nat_id, [
        "systemctl status minecraft --no-pager",
        "ss -tulpn | grep 25565 || true"
    ], "Verificando Minecraft en puerto 25565")
    
    # 2. Configurar Backend sin pip upgrade
    run_commands(backend_id, [
        "set -e",
        "pip3 install flask flask-cors mcrcon requests boto3 PyJWT gunicorn",
        "systemctl daemon-reload",
        "systemctl restart flask-backend || true",
        "systemctl status flask-backend --no-pager",
        "ss -tulpn | grep 8081 || true"
    ], "Instalando dependencias y levantando Flask Backend")
