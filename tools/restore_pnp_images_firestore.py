#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
RESTAURADOR MAESTRO DE FOTOGRAFÍAS Y FICHAS OFICIALES PNP EN FIRESTORE
Restaura las URLs directas de la Policía Nacional del Perú (sistemas.policia.gob.pe)
para eliminar cualquier dependencia de almacenamiento suspendido o fotos vacías.
================================================================================
"""

import sys
import os
import json
import base64
import unicodedata
import re
import urllib.request
import urllib.parse
import ssl
from concurrent.futures import ThreadPoolExecutor, as_completed
import firebase_admin
from firebase_admin import credentials, firestore

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

def norm(text):
    if not text:
        return ""
    text = unicodedata.normalize("NFD", text.upper())
    text = re.sub(r"[\u0300-\u036f]", "", text)
    return re.sub(r"[^A-Z0-9]", "", text)

print("=" * 80)
print("🚀 RESTAURADOR MAESTRO DE FOTOS Y FICHAS POLICIALES (ALERTA PNP)")
print("=" * 80)

master_pnp = {} # key -> {'foto': str, 'ficha': str}

# 1. Cargar base histórica descubierta (19,793 casos)
disc_path = os.path.join(ROOT_DIR, "tools", "all_pnp_cases_discovered.json")
if os.path.exists(disc_path):
    print("📁 [1/4] Cargando base histórica descubierta de la PNP...")
    try:
        with open(disc_path, "r", encoding="utf-8") as f:
            disc_cases = json.load(f)
        for c in disc_cases:
            foto = (c.get("RUTA_IMAGEN") or c.get("IMAGEN") or "").strip()
            ficha = (c.get("IMAGEN") or "").strip()
            val = {"foto": foto, "ficha": ficha}
            raw_b64 = (c.get("DNI") or "").strip()
            if raw_b64:
                master_pnp[f"b64_{raw_b64}"] = val
                try:
                    dec = base64.b64decode(raw_b64).decode("utf-8").strip()
                    master_pnp[f"dni_{dec}"] = val
                except Exception:
                    pass
            n = norm(c.get("NOMBRE_COMPLETO", ""))
            if n:
                master_pnp[f"name_{n}"] = val
        print(f"   ✓ {len(disc_cases)} casos históricos indexados exitosamente.")
    except Exception as e:
        print(f"   ⚠️ Error cargando casos históricos: {e}")

# 2. Consultar en vivo el portal PNP (3,872 casos de los últimos 8 meses)
print("🌐 [2/4] Consultando casos oficiales en vivo desde el portal de la PNP...")
ctx = ssl._create_unverified_context()
URL = "https://desaparecidosenperu.policia.gob.pe/Desaparecidos/Buscar"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    "X-Requested-With": "XMLHttpRequest"
}

def query(prefix, tipo, sexo):
    data = urllib.parse.urlencode({
        "Nombre": prefix,
        "Sexo": sexo,
        "Edad": "",
        "Nacionalidad": "",
        "Tipo": str(tipo)
    }).encode("utf-8")
    req = urllib.request.Request(URL, data=data, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=12) as res:
            return json.loads(res.read().decode("utf-8"))
    except Exception:
        return []

tasks = []
letters = [""] + list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
for tipo in ["1", "2", "3", "4"]:
    for sexo in (["F", "M"] if tipo in ["1", "2", "4"] else ["M"]):
        for l in letters:
            tasks.append((l, tipo, sexo))

live_count = 0
with ThreadPoolExecutor(max_workers=8) as ex:
    futures = {ex.submit(query, l, t, s): (l, t, s) for l, t, s in tasks}
    for f in as_completed(futures):
        for item in f.result():
            raw_b64 = (item.get("DNI") or "").strip()
            foto = (item.get("RUTA_IMAGEN") or item.get("IMAGEN") or "").strip()
            ficha = (item.get("IMAGEN") or "").strip()
            val = {"foto": foto, "ficha": ficha}
            if raw_b64:
                master_pnp[f"b64_{raw_b64}"] = val
                try:
                    dec = base64.b64decode(raw_b64).decode("utf-8").strip()
                    master_pnp[f"dni_{dec}"] = val
                except Exception:
                    pass
            n = norm(item.get("NOMBRE_COMPLETO", ""))
            if n:
                master_pnp[f"name_{n}"] = val
            live_count += 1

print(f"   ✓ {live_count} registros procesados en vivo. Catálogo unificado: {len(master_pnp)} llaves.")

# 3. Conexión a Firestore
print("🔥 [3/4] Conectando con Cloud Firestore...")
sa_path = os.path.join(ROOT_DIR, "serviceAccountKey.json")
cred = credentials.Certificate(sa_path)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

print("⚡ [4/4] Analizando y restaurando URLs oficiales en la colección 'desaparecidos'...")
docs = list(db.collection("desaparecidos").stream())
total_docs = len(docs)
print(f"   Total de expedientes en Firestore: {total_docs}")

updated_count = 0
batch = db.batch()
batch_size = 0

for d in docs:
    dat = d.to_dict()
    dni = (dat.get("dni") or "").strip()
    doc_id_clean = d.id.replace("pnp_", "").replace("_", "=").strip()
    name = norm(dat.get("nombre") or f"{dat.get('nombres','')} {dat.get('apellidos','')}")

    match = (
        master_pnp.get(f"b64_{doc_id_clean}")
        or master_pnp.get(f"dni_{doc_id_clean}")
        or (master_pnp.get(f"dni_{dni}") if dni else None)
        or (master_pnp.get(f"name_{name}") if name else None)
    )

    if not match:
        continue

    pnp_foto = match.get("foto", "").strip()
    pnp_ficha = match.get("ficha", "").strip()

    updates = {}

    current_foto = (dat.get("foto_url") or "").strip()
    current_ficha = (dat.get("imagen_ficha_url") or "").strip()

    # Si foto_url está vacía o apunta a Firebase Storage (delinquent/402), actualizar con foto oficial PNP
    if pnp_foto and (not current_foto or "firebasestorage.googleapis.com" in current_foto):
        updates["foto_url"] = pnp_foto
        updates["fotoUrl"] = pnp_foto
        updates["foto_pnp_url"] = pnp_foto
        updates["tiene_foto"] = True

    # Si imagen_ficha_url está vacía o apunta a Firebase Storage, actualizar con ficha oficial PNP
    if pnp_ficha and (not current_ficha or "firebasestorage.googleapis.com" in current_ficha):
        updates["imagen_ficha_url"] = pnp_ficha
        updates["imagenFichaUrl"] = pnp_ficha
        updates["ficha_pnp_url"] = pnp_ficha
        updates["tiene_ficha"] = True

    if updates:
        batch.update(d.reference, updates)
        batch_size += 1
        updated_count += 1

        if batch_size >= 400:
            batch.commit()
            print(f"   -> Lote de {batch_size} documentos guardado exitosamente en Firestore ({updated_count} actualizados hasta ahora)...")
            batch = db.batch()
            batch_size = 0

if batch_size > 0:
    batch.commit()
    print(f"   -> Último lote de {batch_size} documentos guardado exitosamente.")

print("=" * 80)
print(f"🎉 RESTAURACIÓN COMPLETADA:")
print(f"   • Total expedientes analizados: {total_docs}")
print(f"   • Expedientes restaurados con fotos/fichas oficiales PNP: {updated_count}")
print("=" * 80)

