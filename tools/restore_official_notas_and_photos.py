#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
RESTAURADOR MAESTRO Y DEFINITIVO DE FOTOS Y NOTAS DE ALERTA OFICIALES PNP
Restaura el 100% de las Notas de Alerta oficiales autnticas (1150 x 1720 px,
con escudo PNP, membrete institucional, seas y lnea 114) y fotografas
desde Firebase Storage tras la regularizacin de facturacin.
Adicionalmente captura y sube va Headless Browser cualquier caso faltante.
================================================================================
"""

import os
import sys
import json
import uuid
import time
import urllib.parse
import urllib.request
import ssl
import re
import subprocess
import shutil
from typing import Dict, Any, Optional, List
from concurrent.futures import ThreadPoolExecutor, as_completed
from PIL import Image

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

import firebase_admin
from firebase_admin import credentials, firestore, storage

STORAGE_BUCKET = "alerta-desaparecidos-pnp.firebasestorage.app"
CASOS_COLLECTION = "desaparecidos"

PROGRESS_OFFICIAL = os.path.join(ROOT_DIR, "tools", "notas_progress_official.json")
PROGRESS_V2 = os.path.join(ROOT_DIR, "tools", "notas_progress_v2.json")

def find_system_browser() -> Optional[str]:
    candidates = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        "google-chrome",
        "chromium-browser",
        "chromium",
        "msedge",
    ]
    for c in candidates:
        if os.path.isabs(c):
            if os.path.exists(c):
                return c
        else:
            found = shutil.which(c)
            if found:
                return found
    return None

BROWSER_PATH = find_system_browser()

def init_firebase():
    sa_path = os.path.join(ROOT_DIR, "serviceAccountKey.json")
    if not os.path.exists(sa_path):
        raise FileNotFoundError("No se encontr serviceAccountKey.json")
    cred = credentials.Certificate(sa_path)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred, {"storageBucket": STORAGE_BUCKET})
    return firestore.client(), storage.bucket()

def capture_official_nota_pnp(url: str, doc_id: str, worker_id: int, bucket: Any) -> Optional[str]:
    if not BROWSER_PATH:
        return None
    temp_png = os.path.abspath(f"tools/tmp_restore_w{worker_id}_{doc_id}.png")
    temp_jpg = os.path.abspath(f"tools/tmp_restore_w{worker_id}_{doc_id}.jpg")
    profile_dir = os.path.abspath(f"tools/prof_restore_w{worker_id}_{doc_id}")
    os.makedirs(profile_dir, exist_ok=True)

    try:
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
            "--window-size=1200,2000",
            "--hide-scrollbars",
            f"--screenshot={temp_png}",
            url,
        ]
        subprocess.run(cmd, capture_output=True, timeout=35)
        if not os.path.exists(temp_png) or os.path.getsize(temp_png) < 2000:
            return None

        with Image.open(temp_png) as img:
            w, h = img.size
            # Recorte exacto de la Nota de Alerta oficial PNP
            left = 25
            top = 260
            right = min(1175, w)
            bottom = min(1980, h)
            cropped = img.crop((left, top, right, bottom))
            cropped.convert("RGB").save(temp_jpg, "JPEG", quality=92, optimize=True)

        blob_path = f"desaparecidos/fichas/{doc_id}_nota.jpg"
        blob = bucket.blob(blob_path)
        token = str(uuid.uuid4())
        blob.metadata = {"firebaseStorageDownloadTokens": token}
        with open(temp_jpg, "rb") as f:
            blob.upload_from_file(f, content_type="image/jpeg")

        encoded = urllib.parse.quote(blob_path, safe="")
        return f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded}?alt=media&token={token}"
    except Exception as e:
        print(f"   [AVISO] Error capturando nota para {doc_id}: {e}")
        return None
    finally:
        for f in (temp_png, temp_jpg):
            if os.path.exists(f):
                try:
                    os.remove(f)
                except Exception:
                    pass
        shutil.rmtree(profile_dir, ignore_errors=True)

def resolve_case_url(doc_id: str, case_data: Dict[str, Any]) -> str:
    raw_id = doc_id.replace("pnp_", "")
    b64_param = raw_id.replace("_", "=")
    b64_param = b64_param + "=" * (-len(b64_param) % 4)
    encoded_param = urllib.parse.quote(b64_param)

    edad_str = str(case_data.get("edad") or "").strip()
    sexo = (case_data.get("sexo") or "").lower()

    edad = None
    m = re.search(r"\d+", edad_str)
    if m:
        edad = int(m.group(0))

    if edad is not None and edad < 18:
        ep = "nota_alerta_menor"
    elif "m" in sexo and "f" not in sexo:
        ep = "nota_alerta_hombre"
    else:
        ep = "nota_alerta_mujer"

    return f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/{ep}?id={encoded_param}"

def main():
    print("=" * 80)
    print("? RESTAURADOR MAESTRO DE FOTOS Y NOTAS DE ALERTA OFICIALES PNP")
    print("=" * 80)

    db, bucket = init_firebase()

    # 1. Cargar progreso previo en JSON
    fichas_cache: Dict[str, str] = {}
    for p in (PROGRESS_V2, PROGRESS_OFFICIAL):
        if os.path.exists(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    fichas_cache.update(data)
            except Exception:
                pass
    print(f"?? [1/5] Progreso hist?rico de fichas cargado: {len(fichas_cache)} registros")

    # 2. Indexar todos los blobs de fichas en Storage
    print("?? [2/5] Indexando blobs de fichas en Firebase Storage...")
    ficha_blobs = list(bucket.list_blobs(prefix="desaparecidos/fichas/"))
    storage_fichas: Dict[str, str] = {}
    patch_count = 0

    for b in ficha_blobs:
        token = None
        if b.metadata and "firebaseStorageDownloadTokens" in b.metadata:
            token = b.metadata["firebaseStorageDownloadTokens"].split(",")[0].strip()
        if not token:
            token = str(uuid.uuid4())
            b.metadata = {"firebaseStorageDownloadTokens": token}
            b.patch()
            patch_count += 1

        encoded = urllib.parse.quote(b.name, safe="")
        url = f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded}?alt=media&token={token}"
        fname = b.name.split("/")[-1].rsplit(".", 1)[0]
        base_id = fname.replace("_nota", "")

        # Preferir _nota.jpg sobre .jpg simple
        if fname.endswith("_nota") or base_id not in storage_fichas:
            storage_fichas[base_id] = url
            if not base_id.startswith("pnp_"):
                storage_fichas[f"pnp_{base_id}"] = url

    # Incorporar fichas_cache si no estaban ya
    for k, v in fichas_cache.items():
        if k not in storage_fichas:
            storage_fichas[k] = v
            clean_k = k.replace("pnp_", "")
            storage_fichas[clean_k] = v

    print(f"   ? Fichas en Storage indexadas: {len(storage_fichas)} (tokens regenerados: {patch_count})")

    # 3. Indexar todos los blobs de fotos en Storage
    print("?? [3/5] Indexando blobs de fotos en Firebase Storage...")
    foto_blobs = list(bucket.list_blobs(prefix="desaparecidos/fotos/"))
    storage_fotos: Dict[str, str] = {}
    patch_count_foto = 0

    for b in foto_blobs:
        token = None
        if b.metadata and "firebaseStorageDownloadTokens" in b.metadata:
            token = b.metadata["firebaseStorageDownloadTokens"].split(",")[0].strip()
        if not token:
            token = str(uuid.uuid4())
            b.metadata = {"firebaseStorageDownloadTokens": token}
            b.patch()
            patch_count_foto += 1

        encoded = urllib.parse.quote(b.name, safe="")
        url = f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded}?alt=media&token={token}"
        fname = b.name.split("/")[-1].rsplit(".", 1)[0]
        storage_fotos[fname] = url
        if not fname.startswith("pnp_"):
            storage_fotos[f"pnp_{fname}"] = url

    print(f"   ? Fotos en Storage indexadas: {len(storage_fotos)} (tokens regenerados: {patch_count_foto})")

    # 4. Cruzar y aplicar actualizaciones masivas a Firestore
    print("?? [4/5] Cruzando con la colecci?n 'desaparecidos' en Firestore...")
    docs = list(db.collection(CASOS_COLLECTION).stream())
    print(f"   Total documentos en Firestore: {len(docs)}")

    batch = db.batch()
    batch_count = 0
    updated_fichas = 0
    updated_fotos = 0
    missing_fichas: List[Dict[str, Any]] = []

    for d in docs:
        doc_id = d.id
        clean_id = doc_id.replace("pnp_", "")
        data = d.to_dict()

        updates = {}

        # Validar y restaurar Ficha (Nota de Alerta oficial PNP)
        target_ficha = storage_fichas.get(doc_id) or storage_fichas.get(clean_id)
        if target_ficha:
            current_ficha = data.get("imagen_ficha_url") or ""
            if current_ficha != target_ficha:
                updates["imagen_ficha_url"] = target_ficha
                updates["imagenFichaUrl"] = target_ficha
                updates["tiene_ficha"] = True
                updated_fichas += 1
        else:
            if doc_id.startswith("pnp_"):
                missing_fichas.append({"id": doc_id, "data": data})

        # Validar y restaurar Foto
        target_foto = storage_fotos.get(doc_id) or storage_fotos.get(clean_id)
        if target_foto:
            current_foto = data.get("foto_url") or ""
            if current_foto != target_foto:
                updates["foto_url"] = target_foto
                updates["tiene_foto"] = True
                updated_fotos += 1

        if updates:
            doc_ref = db.collection(CASOS_COLLECTION).document(doc_id)
            batch.update(doc_ref, updates)
            batch_count += 1

            if batch_count >= 400:
                batch.commit()
                print(f"   [Batch] 400 actualizaciones confirmadas en Firestore...")
                batch = db.batch()
                batch_count = 0

    if batch_count > 0:
        batch.commit()
        print(f"   [Batch final] {batch_count} actualizaciones confirmadas en Firestore.")

    print(f"\n? Restauraci?n completada:")
    print(f"   - Fichas oficiales PNP restauradas a Storage: {updated_fichas}")
    print(f"   - Fotos oficiales restauradas a Storage: {updated_fotos}")
    print(f"   - Casos pendientes de captura de Nota de Alerta: {len(missing_fichas)}")

    # 5. Capturar v?a Headless Browser cualquier caso que a?n no tenga su Nota de Alerta
    if missing_fichas and BROWSER_PATH:
        print(f"\n?? [5/5] Capturando {len(missing_fichas)} Notas de Alerta oficiales faltantes desde el portal PNP...")
        num_workers = min(5, len(missing_fichas))
        captured_count = 0

        with ThreadPoolExecutor(max_workers=num_workers) as executor:
            futures = {}
            for idx, item in enumerate(missing_fichas):
                worker_id = (idx % num_workers) + 1
                case_url = resolve_case_url(item["id"], item["data"])
                f = executor.submit(capture_official_nota_pnp, case_url, item["id"], worker_id, bucket)
                futures[f] = item

            for f in as_completed(futures):
                item = futures[f]
                doc_id = item["id"]
                try:
                    uploaded_url = f.result()
                    if uploaded_url:
                        db.collection(CASOS_COLLECTION).document(doc_id).update({
                            "imagen_ficha_url": uploaded_url,
                            "imagenFichaUrl": uploaded_url,
                            "tiene_ficha": True,
                        })
                        # Guardar en JSON
                        fichas_cache[doc_id] = uploaded_url
                        captured_count += 1
                        nombre = item["data"].get("nombre", "")
                        print(f"   [OK PNP] {doc_id} ({nombre[:24]}): Nota de Alerta capturada y subida.")
                except Exception as e:
                    print(f"   [ERROR] Error procesando {doc_id}: {e}")

        # Guardar cache actualizado
        try:
            with open(PROGRESS_OFFICIAL, "w", encoding="utf-8") as f:
                json.dump(fichas_cache, f, indent=2)
            print(f"?? Cach? de progreso actualizado con {len(fichas_cache)} fichas.")
        except Exception as e:
            print(f"   [AVISO] No se pudo guardar JSON de progreso: {e}")

        print(f"? Nuevas Notas de Alerta oficiales capturadas y vinculadas: {captured_count}")

    print("\n" + "=" * 80)
    print("?? SANEAMIENTO MAESTRO DE FOTOS Y NOTAS DE ALERTA FINALIZADO")
    print("=" * 80)

if __name__ == "__main__":
    main()

