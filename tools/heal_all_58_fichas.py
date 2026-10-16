#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Motor de Sanación Masiva de Fichas de Nota de Alerta PNP
Genera, recorta y sube a Firebase Storage las Notas de Alerta oficiales faltantes
para que se vean al 100% en la app (Ciudadano y Policía).
"""

import os
import sys
import uuid
import time
import json
import ssl
import subprocess
import urllib.request
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, Any, Optional, List
from PIL import Image

import firebase_admin
from firebase_admin import credentials, firestore, storage

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

STORAGE_BUCKET = "alerta-desaparecidos-pnp.firebasestorage.app"
CASOS_COLLECTION = "desaparecidos"
HISTORIAL_COLLECTION = "historial_encontrados"

if not firebase_admin._apps:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred, {"storageBucket": STORAGE_BUCKET})

db = firestore.client()
bucket = storage.bucket()
ctx = ssl._create_unverified_context()

BROWSER_CANDIDATES = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
]

BROWSER_PATH = None
for b in BROWSER_CANDIDATES:
    if os.path.exists(b):
        BROWSER_PATH = b
        break

if not BROWSER_PATH:
    raise RuntimeError("No se encontró Microsoft Edge o Chrome en el sistema.")

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/129.0.0.0 Safari/537.36"
    )
}

def resolve_target_url(doc_id: str, data: Dict[str, Any]) -> str:
    raw_id = doc_id.replace("pnp_", "")
    pnp_param = raw_id.replace("_", "=")
    encoded = urllib.parse.quote(pnp_param)

    # Determinar si es menor por fecha de nacimiento o edad
    edad = data.get("edadCalculada")
    if edad is None:
        detalles = data.get("detalles_adicionales") or ""
        import re
        m = re.search(r"Edad:\s*(\d+)", detalles, re.IGNORECASE)
        if m:
            edad = int(m.group(1))

    # Si sabemos que es menor de 18 años
    if edad is not None and edad < 18:
        preferred = f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_menor?id={encoded}"
        alternate = f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_mujer?id={encoded}"
    else:
        preferred = f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_mujer?id={encoded}"
        alternate = f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_menor?id={encoded}"

    # Verificación rápida con HEAD/GET (timeout ultra-corto)
    for u in [preferred, alternate]:
        try:
            req = urllib.request.Request(u, headers=HEADERS)
            with urllib.request.urlopen(req, context=ctx, timeout=5) as resp:
                content = resp.read().decode("utf-8", errors="ignore")
                if "NOTA DE ALERTA" in content and "DATOS DE LA PERSONA DESAPARECIDA" in content:
                    return u
        except Exception:
            continue

    return preferred


def process_case(case_info: Dict[str, Any], worker_id: int) -> bool:
    doc_id = case_info["id"]
    nombre = case_info.get("nombre", doc_id)
    data = case_info["data"]

    temp_png = os.path.abspath(f"tools/tmp_w{worker_id}_{doc_id}.png")
    temp_jpg = os.path.abspath(f"tools/tmp_w{worker_id}_{doc_id}.jpg")
    profile_dir = os.path.abspath(f"tools/prof_w{worker_id}_{doc_id}")
    os.makedirs(profile_dir, exist_ok=True)

    try:
        # Caso especial: Si ya tenía una ficha en sistemas.policia.gob.pe/archivos/sistema_denuncias/imagenes
        # podemos intentar descargarla primero
        raw_ficha = data.get("imagen_ficha_url") or data.get("imagenFichaUrl") or ""
        uploaded_url = None

        if "sistema_denuncias/imagenes" in raw_ficha:
            try:
                req = urllib.request.Request(raw_ficha, headers=HEADERS)
                with urllib.request.urlopen(req, context=ctx, timeout=8) as resp:
                    raw_data = resp.read()
                    if len(raw_data) > 5000:
                        blob_path = f"desaparecidos/fichas/{doc_id}_nota.jpg"
                        blob = bucket.blob(blob_path)
                        token = str(uuid.uuid4())
                        blob.metadata = {"firebaseStorageDownloadTokens": token}
                        blob.upload_from_string(raw_data, content_type="image/jpeg")
                        encoded = urllib.parse.quote(blob_path, safe="")
                        uploaded_url = f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded}?alt=media&token={token}"
            except Exception:
                pass

        if not uploaded_url:
            url = resolve_target_url(doc_id, data)
            cmd = [
                BROWSER_PATH,
                "--headless=new",
                "--disable-gpu",
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--disable-background-networking",
                "--disable-sync",
                "--disable-extensions",
                f"--user-data-dir={profile_dir}",
                "--ignore-certificate-errors",
                "--window-size=1200,2250",
                "--hide-scrollbars",
                f"--screenshot={temp_png}",
                url,
            ]
            res = subprocess.run(cmd, capture_output=True, timeout=35)
            if not os.path.exists(temp_png) or os.path.getsize(temp_png) < 2000:
                print(f"   [AVISO] No se pudo capturar nota para {doc_id} ({nombre})", flush=True)
                return False

            with Image.open(temp_png) as img:
                w, h = img.size
                cropped = img.crop((20, 260, min(1180, w), min(2200, h)))
                cropped.convert("RGB").save(temp_jpg, "JPEG", quality=92, optimize=True)

            blob_path = f"desaparecidos/fichas/{doc_id}_nota.jpg"
            blob = bucket.blob(blob_path)
            token = str(uuid.uuid4())
            blob.metadata = {"firebaseStorageDownloadTokens": token}
            with open(temp_jpg, "rb") as f:
                blob.upload_from_file(f, content_type="image/jpeg")

            encoded = urllib.parse.quote(blob_path, safe="")
            uploaded_url = f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded}?alt=media&token={token}"

        # Actualizar Firestore
        doc_ref = db.collection(CASOS_COLLECTION).document(doc_id)
        doc_ref.update({
            "imagen_ficha_url": uploaded_url,
            "imagenFichaUrl": uploaded_url,
        })

        if (data.get("estado") or "").lower() == "encontrado":
            hist_ref = db.collection(HISTORIAL_COLLECTION).document(f"hist_{doc_id}")
            hist_ref.set({"fichaDesaparecidoUrl": uploaded_url}, merge=True)

        print(f"   [OK] Nota de Alerta acoplada para {doc_id} - {nombre}", flush=True)
        return True

    except Exception as e:
        print(f"   [ERROR] Error en {doc_id}: {e}", flush=True)
        return False
    finally:
        if os.path.exists(temp_png):
            try: os.remove(temp_png)
            except: pass
        if os.path.exists(temp_jpg):
            try: os.remove(temp_jpg)
            except: pass
        import shutil
        shutil.rmtree(profile_dir, ignore_errors=True)


def main():
    print("=" * 70, flush=True)
    print("🚀 INICIANDO SANACIÓN MASIVA DE NOTAS DE ALERTA PNP FALTANTES", flush=True)
    print("=" * 70, flush=True)

    docs = list(db.collection(CASOS_COLLECTION).stream())
    cases_to_heal = []

    for d in docs:
        data = d.to_dict()
        doc_id = d.id
        foto = data.get("foto_url") or data.get("fotoUrl") or ""
        ficha = data.get("imagen_ficha_url") or data.get("imagenFichaUrl") or ""

        base_foto = foto.split("?")[0].strip().lower()
        base_ficha = ficha.split("?")[0].strip().lower()

        needs_heal = False
        if not ficha:
            needs_heal = True
        elif "policia.gob.pe" in ficha:
            needs_heal = True
        elif base_foto == base_ficha:
            needs_heal = True

        if needs_heal:
            nom = (data.get("nombre") or (str(data.get("nombres", "")) + " " + str(data.get("apellidos", "")))).strip()
            cases_to_heal.append({"id": doc_id, "nombre": nom, "data": data})

    total = len(cases_to_heal)
    print(f"📋 Casos identificados que requieren Nota de Alerta oficial: {total}", flush=True)

    if total == 0:
        print("🎉 ¡Todos los casos ya cuentan con su Nota de Alerta oficial!", flush=True)
        return

    max_workers = 3
    print(f"⚡ Procesando con {max_workers} trabajadores paralelos...\n", flush=True)

    start_ts = time.time()
    success_count = 0

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(process_case, case_info, i % max_workers): case_info
            for i, case_info in enumerate(cases_to_heal)
        }
        for fut in as_completed(futures):
            res = fut.result()
            if res:
                success_count += 1

    elapsed = time.time() - start_ts
    print("\n" + "=" * 70, flush=True)
    print(f"🎉 SANACIÓN FINALIZADA: {success_count}/{total} Notas de Alerta generadas en {elapsed:.1f}s", flush=True)
    print("=" * 70, flush=True)


if __name__ == "__main__":
    main()
