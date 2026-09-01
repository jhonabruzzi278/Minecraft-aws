#!/usr/bin/env python3
"""
Script interactivo para actualizar credenciales de AWS Academy (Learner Lab).
Guarda ~/.aws/credentials en formato UTF-8 limpio sin BOM.
"""
import os
import sys
import subprocess
from pathlib import Path


def main():
    print("=" * 60)
    print(" 🔑 Actualizador de Credenciales AWS Academy - Duoc UC")
    print("=" * 60)

    aws_dir = Path.home() / ".aws"
    aws_dir.mkdir(exist_ok=True)

    print("\nPega el bloque completo de credenciales entregado por AWS Academy.")
    print("(Presiona ENTER, escribe 'FIN' en una línea nueva y presiona ENTER):\n")

    lines = []
    while True:
        try:
            line = input()
            if line.strip().upper() == "FIN":
                break
            lines.append(line)
        except EOFError:
            break

    raw_text = "\n".join(lines).strip()
    if not raw_text or "aws_access_key_id" not in raw_text:
        print("\n❌ Error: No se ingresaron credenciales válidas.")
        sys.exit(1)

    # Escribir ~/.aws/credentials
    cred_file = aws_dir / "credentials"
    with open(cred_file, "w", encoding="utf-8", newline="\n") as f:
        f.write(raw_text + "\n")

    # Escribir ~/.aws/config
    config_file = aws_dir / "config"
    with open(config_file, "w", encoding="utf-8", newline="\n") as f:
        f.write("[default]\nregion = us-east-1\noutput = json\n")

    print(f"\n💾 Guardado exitosamente en: {cred_file}")

    # Validar con AWS STS
    print("\n🔍 Validando con AWS STS...")
    try:
        res = subprocess.run(["aws", "sts", "get-caller-identity"], capture_output=True, text=True)
        if res.returncode == 0:
            print("\n✅ ¡AUTENTICACIÓN EXITOSA!")
            print(res.stdout)
        else:
            print("\n⚠️ Error al autenticar con AWS CLI:")
            print(res.stderr)
    except Exception as e:
        print(f"\n⚠️ No se pudo ejecutar aws cli: {e}")

    print("=" * 60)


if __name__ == "__main__":
    main()
