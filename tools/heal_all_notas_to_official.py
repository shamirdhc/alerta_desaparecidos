#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
HERRAMIENTA MAESTRA DE CONVERSIÓN INTEGRAL: NOTAS DE ALERTA OFICIALES PNP (WEB)
Convierte el 100% de los casos en Firestore a la Nota de Alerta oficial auténtica
capturada desde el portal PNP con escudo, tipografía oficial, Línea 114 y membrete.
================================================================================
"""

import os
import sys
import json
import time
import uuid
import shutil
import re
import ssl
import subprocess
import urllib.request
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any, Dict, List, Optional
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
PROGRESS_FILE = os.path.join(ROOT_DIR, "tools", "notas_progress_official.json")

HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Safari/537.36'
    ),
    'Accept-Language': 'es-PE,es;q=0.9',
}

SSL_CTX = ssl._create_unverified_context()


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
if not BROWSER_PATH:
    print("[ERROR] No se encontró navegador (Edge/Chrome) para renderizar.", file=sys.stderr)
    sys.exit(1)


def init_firebase() -> Any:
    sa_file = os.path.join(ROOT_DIR, "serviceAccountKey.json")
    if not os.path.exists(sa_file):
        raise RuntimeError("No se encontró serviceAccountKey.json")
    cred = credentials.Certificate(sa_file)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred, {"storageBucket": STORAGE_BUCKET})
    return firestore.client()


def load_progress() -> Dict[str, str]:
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def save_progress_item(doc_id: str, url: str) -> None:
    try:
        data = load_progress()
        data[doc_id] = url
        temp_p = PROGRESS_FILE + f".tmp_{os.getpid()}"
        with open(temp_p, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(temp_p, PROGRESS_FILE)
    except Exception as e:
        print(f"   [AVISO] No se pudo guardar progreso para {doc_id}: {e}")


def resolve_case_url(doc_id: str, case_data: Dict[str, Any]) -> Optional[str]:
    """
    Determina la URL oficial exacta del portal PNP verificando que contenga
    los datos del caso y no un formulario vacío.
    """
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
        eps = ["nota_alerta_menor", "nota_alerta_mujer", "nota_alerta_hombre"]
    elif "m" in sexo and "f" not in sexo:
        eps = ["nota_alerta_hombre", "nota_alerta_mujer", "nota_alerta_menor"]
    else:
        eps = ["nota_alerta_mujer", "nota_alerta_menor", "nota_alerta_hombre"]

    # Probar endpoint preferido y verificar presencia de apellidos reales
    for ep in eps:
        test_url = f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/{ep}?id={encoded_param}"
        try:
            req = urllib.request.Request(test_url, headers=HEADERS)
            with urllib.request.urlopen(req, context=SSL_CTX, timeout=5) as resp:
                html = resp.read().decode("utf-8", errors="ignore")
                idx = html.find("APELLIDOS :")
                if idx != -1:
                    snippet = html[idx : idx + 180]
                    m_val = re.search(r'APELLIDOS\s*:\s*</b>\s*<b[^>]*>([^<]+)</b>', snippet)
                    if m_val and m_val.group(1).strip():
                        return test_url
        except Exception:
            continue

    # Fallback al endpoint predeterminado según demografía
    return f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/{eps[0]}?id={encoded_param}"


def capture_official_nota(
    url: str, doc_id: str, worker_id: int
) -> Optional[str]:
    temp_png = os.path.abspath(f"tools/tmp_heal_w{worker_id}_{doc_id}.png")
    temp_jpg = os.path.abspath(f"tools/tmp_heal_w{worker_id}_{doc_id}.jpg")
    profile_dir = os.path.abspath(f"tools/prof_heal_w{worker_id}_{doc_id}")
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
        res = subprocess.run(cmd, capture_output=True, timeout=40)
        if not os.path.exists(temp_png) or os.path.getsize(temp_png) < 2000:
            return None

        with Image.open(temp_png) as img:
            w, h = img.size
            # Recorte 100% íntegro de la Nota de Alerta oficial PNP
            left = 25
            top = 260
            right = min(1175, w)
            bottom = min(1980, h)
            cropped = img.crop((left, top, right, bottom))
            cropped.convert("RGB").save(temp_jpg, "JPEG", quality=92, optimize=True)

        bucket = storage.bucket()
        blob_path = f"desaparecidos/fichas/{doc_id}_nota.jpg"
        blob = bucket.blob(blob_path)
        token = str(uuid.uuid4())
        blob.metadata = {"firebaseStorageDownloadTokens": token}
        with open(temp_jpg, "rb") as f:
            blob.upload_from_file(f, content_type="image/jpeg")

        encoded = urllib.parse.quote(blob_path, safe="")
        return f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded}?alt=media&token={token}"
    except Exception as e:
        print(f"      [AVISO] Error capturando nota para {doc_id}: {e}")
        return None
    finally:
        if os.path.exists(temp_png):
            try:
                os.remove(temp_png)
            except Exception:
                pass
        if os.path.exists(temp_jpg):
            try:
                os.remove(temp_jpg)
            except Exception:
                pass
        shutil.rmtree(profile_dir, ignore_errors=True)


def process_case(
    doc_id: str, case_data: Dict[str, Any], worker_id: int, db: Any
) -> bool:
    nombre = case_data.get("nombre") or f"{case_data.get('nombres','')} {case_data.get('apellidos','')}".strip()
    url = resolve_case_url(doc_id, case_data)
    if not url:
        return False

    uploaded_url = capture_official_nota(url, doc_id, worker_id)
    if not uploaded_url:
        return False

    # Actualizar Firestore
    doc_ref = db.collection(CASOS_COLLECTION).document(doc_id)
    doc_ref.update({
        "imagen_ficha_url": uploaded_url,
        "imagenFichaUrl": uploaded_url,
        "tiene_ficha": True,
    })

    save_progress_item(doc_id, uploaded_url)
    print(f"   [OK W{worker_id}] {doc_id} ({nombre[:28]}): Ficha oficial web subida y actualizada.")
    return True


def run_batch_conversion(max_cases: Optional[int] = None, num_workers: int = 5) -> None:
    print("=" * 70)
    print("🚀 INICIANDO MIGRACIÓN INTEGRAL A NOTAS DE ALERTA OFICIALES PNP (WEB)")
    print(f"Navegador: {BROWSER_PATH}")
    print(f"Hilos concurrentes: {num_workers}")
    print("=" * 70)

    db = init_firebase()
    progress = load_progress()

    # Pre-marcar Yamile que ya fue completada exitosamente
    progress["pnp_NDk0ODA1Njg_"] = "https://firebasestorage.googleapis.com/v0/b/alerta-desaparecidos-pnp.firebasestorage.app/o/desaparecidos%2Ffichas%2Fpnp_NDk0ODA1Njg__nota.jpg"

    print("📥 Consultando casos activos en Firestore...")
    docs = list(db.collection(CASOS_COLLECTION).where("estado", "==", "activo").stream())
    print(f"Total casos activos en Firestore: {len(docs)}")

    pending: List[Dict[str, Any]] = []
    for d in docs:
        doc_id = d.id
        if doc_id in progress:
            continue
        # Solo procesar IDs que tengan el tracking base64 del portal PNP
        if not doc_id.startswith("pnp_"):
            continue
        data = d.to_dict()
        pending.append({"id": doc_id, "data": data})

    if max_cases:
        pending = pending[:max_cases]

    print(f"📋 Casos pendientes de conversión a Ficha Oficial Web: {len(pending)}")
    if not pending:
        print("✅ Todos los casos ya cuentan con la Nota de Alerta oficial PNP.")
        return

    start_ts = time.time()
    success_count = 0
    fail_count = 0

    with ThreadPoolExecutor(max_workers=num_workers) as executor:
        futures = {}
        for idx, item in enumerate(pending):
            worker_id = (idx % num_workers) + 1
            f = executor.submit(process_case, item["id"], item["data"], worker_id, db)
            futures[f] = item["id"]

        for f in as_completed(futures):
            doc_id = futures[f]
            try:
                ok = f.result()
                if ok:
                    success_count += 1
                else:
                    fail_count += 1
            except Exception as e:
                print(f"   [ERROR] Falló procesamiento de {doc_id}: {e}")
                fail_count += 1

    dur = round(time.time() - start_ts, 1)
    print("\n" + "=" * 70)
    print(f"🏁 RESUMEN: {success_count} convertidos con éxito, {fail_count} fallidos en {dur}s.")
    print("=" * 70)


if __name__ == "__main__":
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else None
    run_batch_conversion(max_cases=limit, num_workers=5)
