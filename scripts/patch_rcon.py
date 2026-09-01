import boto3
import time
import requests

ssm = boto3.client("ssm", region_name="us-east-1")
backend_id = "i-0dfed23a838b96dcc"

rcon_code = '''
import socket
import struct

def execute_rcon(command):
    host = MINECRAFT_HOST
    port = RCON_PORT
    password = RCON_PASSWORD
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(4.0)
            s.connect((host, port))
            auth_payload = password.encode("utf-8")
            auth_packet = struct.pack("<iii", len(auth_payload) + 10, 1, 3) + auth_payload + b"\\x00\\x00"
            s.sendall(auth_packet)
            res = s.recv(4096)
            if len(res) < 12: return "Error RCON: Respuesta login invalida"
            _, req_id, _ = struct.unpack("<iii", res[:12])
            if req_id == -1: return "Error RCON: Password incorrecta"
            
            cmd_payload = command.encode("utf-8")
            cmd_packet = struct.pack("<iii", len(cmd_payload) + 10, 2, 2) + cmd_payload + b"\\x00\\x00"
            s.sendall(cmd_packet)
            data = s.recv(4096)
            if len(data) >= 12:
                return data[12:-2].decode("utf-8", errors="replace")
            return "OK"
    except Exception as e:
        return f"Error RCON ({host}:{port}): {str(e)}"
'''

# Actualizar en la EC2
script = f'''
cat << 'EOF_RCON' > /tmp/rcon_patch.py
{rcon_code}
EOF_RCON

python3 -c "
with open('/opt/backend/app.py', 'r') as f: code = f.read()
import re
# Reemplazar definicion de execute_rcon
pattern = r'def execute_rcon\(command\):.*?(?=@app\.route)'
with open('/tmp/rcon_patch.py', 'r') as f: new_func = f.read()
code = re.sub(pattern, new_func + '\\n\\n', code, flags=re.DOTALL)
with open('/opt/backend/app.py', 'w') as f: f.write(code)
"
systemctl restart flask-backend
'''

print("Enviando parche RCON Socket puro a backend...")
resp = ssm.send_command(
    InstanceIds=[backend_id],
    DocumentName="AWS-RunShellScript",
    Parameters={"commands": [script]}
)
cmd_id = resp["Command"]["CommandId"]

time.sleep(5)
inv = ssm.get_command_invocation(CommandId=cmd_id, InstanceId=backend_id)
print("Estado SSM:", inv.get("Status"))

time.sleep(2)
# Probar nuevo registro
r = requests.post("http://18.215.185.57:8081/api/usuarios", json={
    "nombre": "Creeper Friendly",
    "email": "creeper@minecraft.net",
    "gamertag": "CreeperKing"
})
print("Respuesta API:", r.status_code, r.json())
