import boto3
import time
import requests

ssm = boto3.client("ssm", region_name="us-east-1")
backend_id = "i-0dfed23a838b96dcc"

# Código actualizado con endpoint DELETE /api/usuarios/<email>
backend_app_code = """from flask import Flask, jsonify, request
from flask_cors import CORS
from functools import wraps
import sqlite3
import datetime
import os
import socket
import struct
import boto3

app = Flask(__name__)
CORS(app)

JWT_SECRET = "DuocCloudNativeSecretKey2026!"
ADMIN_USER = "admin"
ADMIN_PASS = "DuocAdmin2026!"
AWS_REGION = "us-east-1"
DYNAMODB_TABLE = "UsuariosMinecraft"
MINECRAFT_HOST = "10.0.1.56"
RCON_PORT = 25575
RCON_PASSWORD = "DuocCloudNative2026!"

USE_DYNAMODB = False
dynamo_table = None

try:
    dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
    dynamo_table = dynamodb.Table(DYNAMODB_TABLE)
    dynamo_table.load()
    USE_DYNAMODB = True
    print(f"✓ Conectado a DynamoDB: {DYNAMODB_TABLE}")
except Exception as e:
    print(f"DynamoDB no disponible ({e}), usando SQLite.")
    USE_DYNAMODB = False

def execute_rcon(command):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(4.0)
            s.connect((MINECRAFT_HOST, RCON_PORT))
            auth_payload = RCON_PASSWORD.encode("utf-8")
            auth_packet = struct.pack("<iii", len(auth_payload) + 10, 1, 3) + auth_payload + b"\\x00\\x00"
            s.sendall(auth_packet)
            res = s.recv(4096)
            if len(res) < 12: return "Error RCON: Respuesta de autenticacion invalida"
            _, req_id, _ = struct.unpack("<iii", res[:12])
            if req_id == -1: return "Error RCON: Password de RCON incorrecta"
            
            cmd_payload = command.encode("utf-8")
            cmd_packet = struct.pack("<iii", len(cmd_payload) + 10, 2, 2) + cmd_payload + b"\\x00\\x00"
            s.sendall(cmd_packet)
            data = s.recv(4096)
            if len(data) >= 12:
                resp = data[12:-2].decode("utf-8", errors="replace")
                return resp if resp else "Comando ejecutado con exito."
            return "OK"
    except Exception as e:
        return f"Error RCON ({MINECRAFT_HOST}:{RCON_PORT}): {str(e)}"

@app.route("/api/saludo", methods=["GET"])
def saludo():
    return jsonify({
        "mensaje": "¡Backend Enterprise Cloud Native con DynamoDB y Consola RCON!",
        "persistencia": "Amazon DynamoDB" if USE_DYNAMODB else "SQLite",
        "minecraft_host": MINECRAFT_HOST,
        "region": AWS_REGION
    })

@app.route("/api/auth/login", methods=["POST"])
def login():
    data = request.get_json() or {}
    if data.get("username") == ADMIN_USER and data.get("password") == ADMIN_PASS:
        return jsonify({"mensaje": "OK", "token": "token-admin-valido", "user": ADMIN_USER, "role": "admin"})
    return jsonify({"error": "Credenciales invalidas"}), 401

@app.route("/api/usuarios", methods=["GET"])
def get_usuarios():
    if USE_DYNAMODB and dynamo_table:
        try:
            items = dynamo_table.scan().get("Items", [])
            for it in items:
                if "id" in it: it["id"] = int(it["id"])
            return jsonify(items)
        except Exception as e:
            print("Error scan DynamoDB:", e)
    return jsonify([])

@app.route("/api/usuarios", methods=["POST"])
def create_usuario():
    data = request.get_json() or {}
    nombre = data.get("nombre", "").strip()
    email = data.get("email", "").strip()
    gamertag = data.get("gamertag", "").strip() or nombre

    if not nombre or not email:
        return jsonify({"error": "Nombre y email requeridos"}), 400

    item = {
        "email": email,
        "id": int(datetime.datetime.now().timestamp()),
        "nombre": nombre,
        "gamertag": gamertag,
        "fecha_registro": datetime.datetime.now(datetime.timezone.utc).isoformat()
    }
    
    if USE_DYNAMODB and dynamo_table:
        dynamo_table.put_item(Item=item)
        
    rcon_resp = execute_rcon(f"whitelist add {gamertag}")
    return jsonify({"usuario": item, "minecraft_whitelist": rcon_resp, "storage": "DynamoDB"}), 201

@app.route("/api/usuarios/<path:email>", methods=["DELETE"])
def delete_usuario(email):
    gamertag = None
    if USE_DYNAMODB and dynamo_table:
        try:
            resp = dynamo_table.get_item(Key={"email": email})
            item = resp.get("Item")
            if item:
                gamertag = item.get("gamertag")
                dynamo_table.delete_item(Key={"email": email})
        except Exception as e:
            print("Error delete DynamoDB:", e)
            
    if not gamertag:
        return jsonify({"error": f"Usuario con email '{email}' no encontrado"}), 404
        
    # Remover de la lista blanca de Minecraft
    rcon_resp = execute_rcon(f"whitelist remove {gamertag}")
    return jsonify({
        "mensaje": f"Usuario con email {email} eliminado exitosamente de DynamoDB",
        "gamertag": gamertag,
        "minecraft_whitelist": rcon_resp
    }), 200

@app.route("/api/minecraft/status", methods=["GET"])
def mc_status():
    jugadores = execute_rcon("list")
    return jsonify({
        "minecraft_ip": "18.215.185.57:25565",
        "jugadores": jugadores,
        "status": "Online"
    })

@app.route("/api/minecraft/command", methods=["POST"])
def mc_cmd():
    cmd = (request.get_json() or {}).get("comando", "").strip()
    if cmd.startswith("/"): cmd = cmd[1:]
    salida = execute_rcon(cmd)
    return jsonify({"comando": f"/{cmd}", "salida": salida, "timestamp": datetime.datetime.now().strftime("%H:%M:%S")})

@app.route("/api/minecraft/quick-command/<accion>", methods=["POST"])
def mc_quick(accion):
    accs = {
        "day": "time set day",
        "night": "time set night",
        "sun": "weather clear",
        "rain": "weather rain",
        "creative": "gamemode creative @a",
        "survival": "gamemode survival @a",
        "tps": "tps",
        "whitelist-list": "whitelist list",
        "save": "save-all"
    }
    cmd = accs.get(accion.lower(), "list")
    salida = execute_rcon(cmd)
    return jsonify({"accion": accion, "comando": f"/{cmd}", "salida": salida, "timestamp": datetime.datetime.now().strftime("%H:%M:%S")})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)
"""

print("Actualizando backend con endpoint DELETE...")
resp = ssm.send_command(
    InstanceIds=[backend_id],
    DocumentName="AWS-RunShellScript",
    Parameters={"commands": [
        f"cat << 'EOF_APP' > /opt/backend/app.py\n{backend_app_code}\nEOF_APP",
        "systemctl restart flask-backend"
    ]}
)
cmd_id = resp["Command"]["CommandId"]

time.sleep(5)
inv = ssm.get_command_invocation(CommandId=cmd_id, InstanceId=backend_id)
print("Estado SSM:", inv.get("Status"))

# Probar eliminacion de un usuario de prueba
test_email = "creeper@minecraft.net"
r = requests.delete(f"http://18.215.185.57:8081/api/usuarios/{test_email}")
print(f"\n[DELETE TEST - {test_email}]:", r.status_code, r.json())
