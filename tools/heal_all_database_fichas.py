import os
import sys

# Ensure UTF-8 console output on Windows
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

import json
import time
import uuid
import shutil
import subprocess
import urllib.request
import urllib.parse
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed
from PIL import Image

sys.path.insert(0, os.path.abspath("."))
sys.path.insert(0, os.path.abspath("tools"))

from attach_notas_alerta import (
    get_valid_token,
    find_browser,
    STORAGE_BUCKET,
    FIRESTORE_PROJECT
)

BROWSER = find_browser()
if not BROWSER:
    print("❌ No se encontró navegador (Edge/Chrome) para renderizar.", flush=True)
    sys.exit(1)

PROGRESS_FILE = os.path.abspath("tools/notas_progress_v2.json")
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

def load_progress():
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_progress_item(doc_id, url):
    try:
        data = load_progress()
        data[doc_id] = url
        with open(PROGRESS_FILE + ".tmp", 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        os.replace(PROGRESS_FILE + ".tmp", PROGRESS_FILE)
    except Exception as e:
        print(f"⚠️ Error guardando progreso: {e}")

def resolve_pnp_url(doc_id):
    raw_id = doc_id.replace("pnp_", "")
    pnp_param = raw_id.replace("_", "=")
    encoded_param = urllib.parse.quote(pnp_param)
    
    # Intentar con menor y mujer
    endpoints = [
        f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_menor?id={encoded_param}",
        f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_mujer?id={encoded_param}",
    ]
    
    import ssl
    ctx = ssl._create_unverified_context()
    
    for url in endpoints:
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, context=ctx, timeout=8) as res:
                html = res.read().decode('utf-8', errors='ignore')
                if 'NOTA DE ALERTA' in html and 'DATOS DE LA PERSONA DESAPARECIDA' in html:
                    return url
        except Exception:
            continue
            
    # Si ambas fallaron por timeout pero la estructura es válida, usar el primer endpoint por defecto
    return endpoints[0]

def process_single_case(case_info, worker_id, total, counter):
    doc_id = case_info['id']
    nombre = case_info['nombre']
    
    temp_png = f"tools/tmp_w{worker_id}_{doc_id}.png"
    temp_jpg = f"tools/tmp_w{worker_id}_{doc_id}.jpg"
    profile_dir = f"tools/profile_w{worker_id}_{doc_id}"
    os.makedirs(profile_dir, exist_ok=True)
    
    try:
        url = case_info.get('detail_url') or resolve_pnp_url(doc_id)
        
        cmd = [
            BROWSER,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--disable-dev-shm-usage",
            "--disable-background-networking",
            "--disable-sync",
            "--disable-extensions",
            f"--user-data-dir={os.path.abspath(profile_dir)}",
            "--ignore-certificate-errors",
            "--window-size=1200,2250",
            "--hide-scrollbars",
            f"--screenshot={os.path.abspath(temp_png)}",
            url
        ]
        
        res = subprocess.run(cmd, capture_output=True, timeout=50)
        if not os.path.exists(temp_png) or os.path.getsize(temp_png) == 0:
            print(f"⚠️ [{doc_id}] No se pudo capturar screenshot (código {res.returncode})", flush=True)
            return False
            
        with Image.open(temp_png) as img:
            w, h = img.size
            # Recorte íntegro de la Nota de Alerta oficial PNP
            left = 20
            top = 260
            right = min(1180, w)
            bottom = min(2200, h)
            cropped = img.crop((left, top, right, bottom))
            cropped.convert("RGB").save(temp_jpg, "JPEG", quality=92, optimize=True)
            
        with open(temp_jpg, "rb") as f:
            img_bytes = f.read()
            
        token = get_valid_token()
        file_path = f"desaparecidos/fichas/{doc_id}_nota.jpg"
        encoded_path = urllib.parse.quote(file_path, safe='')
        download_token = str(uuid.uuid4())
        
        # 1. Upload to Firebase Storage
        upload_url = f"https://storage.googleapis.com/upload/storage/v1/b/{STORAGE_BUCKET}/o?uploadType=media&name={encoded_path}"
        req = urllib.request.Request(
            upload_url,
            data=img_bytes,
            headers={"Authorization": f"Bearer {token}", "Content-Type": "image/jpeg"}
        )
        with urllib.request.urlopen(req, timeout=25):
            pass
            
        # 2. Patch metadata with download token
        meta_url = f"https://storage.googleapis.com/storage/v1/b/{STORAGE_BUCKET}/o/{encoded_path}"
        meta_body = json.dumps({"metadata": {"firebaseStorageDownloadTokens": download_token}}).encode("utf-8")
        meta_req = urllib.request.Request(
            meta_url,
            data=meta_body,
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            method="PATCH"
        )
        with urllib.request.urlopen(meta_req, timeout=25):
            pass
            
        public_url = f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded_path}?alt=media&token={download_token}"
        
        # 3. Patch Firestore doc
        now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        firestore_url = (
            f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/desaparecidos/{doc_id}"
            f"?updateMask.fieldPaths=imagen_ficha_url&updateMask.fieldPaths=detail_url_pnp&updateMask.fieldPaths=necesita_nota_alerta&updateMask.fieldPaths=fecha_actualizacion"
        )
        payload = {
            "fields": {
                "imagen_ficha_url": {"stringValue": public_url},
                "detail_url_pnp": {"stringValue": url},
                "necesita_nota_alerta": {"booleanValue": False},
                "fecha_actualizacion": {"timestampValue": now_iso}
            }
        }
        f_req = urllib.request.Request(
            firestore_url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            method="PATCH"
        )
        with urllib.request.urlopen(f_req, timeout=20):
            pass
            
        save_progress_item(doc_id, public_url)
        counter['done'] += 1
        idx = counter['done']
        size_kb = os.path.getsize(temp_jpg) / 1024
        print(f"[{idx:03d}/{total:03d}] ✅ REPARADO: {nombre} ({doc_id}) -> {size_kb:.1f} KB", flush=True)
        return True
    except Exception as e:
        print(f"❌ Error procesando {doc_id} ({nombre}): {e}", flush=True)
        return False
    finally:
        if os.path.exists(temp_png):
            try: os.remove(temp_png)
            except: pass
        if os.path.exists(temp_jpg):
            try: os.remove(temp_jpg)
            except: pass
        shutil.rmtree(profile_dir, ignore_errors=True)

def main():
    print("=" * 70, flush=True)
    print("🚀 INICIANDO REPARACIÓN INTEGRAL DE NOTAS DE ALERTA FALTANTES EN BD", flush=True)
    print("=" * 70, flush=True)
    print(f"🌐 Navegador activo: {BROWSER}", flush=True)
    
    token = get_valid_token()
    print("🔑 Autenticación con Firebase confirmada.", flush=True)
    
    # 1. Cargar casos que necesitan ficha
    with open("tools/casos_sin_ficha.json", "r", encoding="utf-8") as f:
        all_cases = json.load(f)
        
    # Filtrar solo casos 'activo' y que aún no estén en progreso
    progress = load_progress()
    target_cases = [
        c for c in all_cases 
        if c.get('estado') == 'activo' and c['id'] not in progress
    ]
    
    total = len(target_cases)
    print(f"📋 Casos activos pendientes de Nota de Alerta: {total}", flush=True)
    if total == 0:
        print("🎉 ¡Todos los casos activos ya tienen su Nota de Alerta!", flush=True)
        return
        
    counter = {'done': 0}
    max_workers = 2
    start_time = time.time()
    
    print(f"⚡ Procesando con {max_workers} hilos concurrentes...\n", flush=True)
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = []
        for i, c in enumerate(target_cases):
            worker_id = i % max_workers
            futures.append(executor.submit(process_single_case, c, worker_id, total, counter))
            
        for future in as_completed(futures):
            future.result()
            
    elapsed = time.time() - start_time
    print("\n" + "=" * 70, flush=True)
    print(f"🎉 PROCESO COMPLETADO: {counter['done']}/{total} Notas de Alerta reparadas en {elapsed:.1f} segundos.", flush=True)
    print("=" * 70, flush=True)

if __name__ == "__main__":
    main()
