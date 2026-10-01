import os
import sys
import json
import time
import uuid
import re
import ssl
import subprocess
import urllib.request
import urllib.parse
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed
from PIL import Image

def find_browser():
    candidates = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        "google-chrome",
        "chromium-browser",
        "chromium",
        "msedge"
    ]
    for c in candidates:
        if os.path.isabs(c):
            if os.path.exists(c):
                return c
        else:
            from shutil import which
            found = which(c)
            if found:
                return found
    return None

BROWSER_PATH = find_browser()
CONFIG_PATH = r"C:\Users\51948\.config\configstore\firebase-tools.json"
STORAGE_BUCKET = "alerta-desaparecidos-pnp.firebasestorage.app"
FIRESTORE_PROJECT = "alerta-desaparecidos-pnp"

INGESTED_FILE = os.path.abspath(r"tools\pnp_ingested_records.json")
PROGRESS_FILE = os.path.abspath(r"tools\notas_progress_v2.json")

ctx = ssl._create_unverified_context()
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

def get_valid_token():
    env_token = os.environ.get('FIREBASE_ACCESS_TOKEN') or os.environ.get('GOOGLE_ACCESS_TOKEN')
    if env_token:
        return env_token.strip()

    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            data = json.load(f)
        tokens = data['tokens']
        expires_at = tokens.get('expires_at', 0)
        current_ms = time.time() * 1000
        
        # If expired or expires within 5 minutes, refresh
        if expires_at - current_ms < 300000:
            print("[AUTH] Refreshing Google OAuth token...", flush=True)
            url = 'https://oauth2.googleapis.com/token'
            params = {
                'refresh_token': tokens['refresh_token'],
                'client_id': '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
                'client_secret': 'j9iVZfS8kkCEFUPaAeJV0sAi',
                'grant_type': 'refresh_token'
            }
            req = urllib.request.Request(
                url,
                data=urllib.parse.urlencode(params).encode('utf-8'),
                headers={'Content-Type': 'application/x-www-form-urlencoded'}
            )
            with urllib.request.urlopen(req, timeout=15) as res:
                res_data = json.loads(res.read().decode('utf-8'))
            tokens['access_token'] = res_data['access_token']
            tokens['expires_at'] = int((time.time() + res_data['expires_in']) * 1000)
            with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
            print("[AUTH] Token refreshed successfully.", flush=True)
                
        return tokens['access_token']

    sa_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
    if sa_path and os.path.exists(sa_path):
        from google.oauth2 import service_account
        import google.auth.transport.requests
        creds = service_account.Credentials.from_service_account_file(
            sa_path,
            scopes=['https://www.googleapis.com/auth/cloud-platform']
        )
        auth_req = google.auth.transport.requests.Request()
        creds.refresh(auth_req)
        return creds.token

    raise RuntimeError("No Firebase token available.")

def capture_and_process_nota(url, temp_png, output_jpg, worker_id=0):
    if not BROWSER_PATH:
        raise RuntimeError("No compatible web browser found for headless screenshots")
        
    abs_temp_png = os.path.abspath(temp_png)
    abs_output_jpg = os.path.abspath(output_jpg)
    temp_profile_dir = os.path.abspath(f"tools/profile_worker_{worker_id}")
    os.makedirs(temp_profile_dir, exist_ok=True)
    
    if os.path.exists(abs_temp_png):
        try: os.remove(abs_temp_png)
        except: pass
        
    cmd = [
        BROWSER_PATH,
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-background-networking",
        "--disable-sync",
        "--disable-extensions",
        f"--user-data-dir={temp_profile_dir}",
        "--ignore-certificate-errors",
        "--window-size=1200,2000",
        "--hide-scrollbars",
        f"--screenshot={abs_temp_png}",
        url
    ]
    res = subprocess.run(cmd, capture_output=True, timeout=40)
    if not os.path.exists(abs_temp_png) or os.path.getsize(abs_temp_png) == 0:
        raise RuntimeError(f"Failed to capture screenshot (exit code {res.returncode})")
        
    with Image.open(abs_temp_png) as img:
        w, h = img.size
        # Recorte 100% íntegro de la Nota de Alerta oficial PNP (1150 x 1720 px)
        # Salta el menú/navbar superior (y=260) e incluye el escudo completo a la izquierda (x=25),
        # datos, fotografía, señas particulares y pie de página oficial con teléfonos de emergencia (y=1980)
        left = 25
        top = 260
        right = min(1175, w)
        bottom = min(1980, h)
        cropped = img.crop((left, top, right, bottom))
        cropped.convert("RGB").save(abs_output_jpg, "JPEG", quality=92, optimize=True)
        
    if os.path.exists(abs_temp_png):
        try: os.remove(abs_temp_png)
        except: pass

def upload_ficha_to_storage(token, jpg_path, doc_id):
    with open(jpg_path, 'rb') as f:
        img_bytes = f.read()
        
    file_path = f"desaparecidos/fichas/{doc_id}.jpg"
    encoded_path = urllib.parse.quote(file_path, safe='')
    download_token = str(uuid.uuid4())
    
    # 1. Upload media
    upload_url = f"https://storage.googleapis.com/upload/storage/v1/b/{STORAGE_BUCKET}/o?uploadType=media&name={encoded_path}"
    upload_req = urllib.request.Request(
        upload_url,
        data=img_bytes,
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'image/jpeg'}
    )
    with urllib.request.urlopen(upload_req, timeout=25):
        pass
        
    # 2. Patch metadata with download token
    meta_url = f"https://storage.googleapis.com/storage/v1/b/{STORAGE_BUCKET}/o/{encoded_path}"
    meta_body = json.dumps({'metadata': {'firebaseStorageDownloadTokens': download_token}}).encode('utf-8')
    meta_req = urllib.request.Request(
        meta_url,
        data=meta_body,
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
        method='PATCH'
    )
    with urllib.request.urlopen(meta_req, timeout=25):
        pass
        
    public_url = f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded_path}?alt=media&token={download_token}"
    return public_url

def patch_firestore_doc(token, doc_id, ficha_url):
    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    firestore_url = (
        f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/desaparecidos/{doc_id}"
        f"?updateMask.fieldPaths=imagen_ficha_url&updateMask.fieldPaths=fecha_actualizacion"
    )
    payload = {
        'fields': {
            'imagen_ficha_url': {'stringValue': ficha_url},
            'fecha_actualizacion': {'timestampValue': now_iso}
        }
    }
    body = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        firestore_url,
        data=body,
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
        method='PATCH'
    )
    with urllib.request.urlopen(req, timeout=20) as res:
        return json.loads(res.read().decode('utf-8'))

def build_case_url_mapping(ingested_records):
    print("Building URL mapping from live PNP pages...")
    urls = [
        ('https://desaparecidosenperu.policia.gob.pe/Desaparecidos/menor_desaparecido', 'MENORES'),
        ('https://desaparecidosenperu.policia.gob.pe/Desaparecidos/mujer_desaparecido', 'ADULTOS')
    ]
    
    cards = []
    for page_url, cat in urls:
        try:
            req = urllib.request.Request(page_url, headers=HEADERS)
            with urllib.request.urlopen(req, context=ctx, timeout=30) as res:
                html = res.read().decode('utf-8', errors='ignore')
            raw_cards = re.findall(r'<div\s+class=[\'"]col-md-3[\'"]>[\s\S]*?</div>\s*</div>\s*</div>', html)
            print(f"  Encontradas {len(raw_cards)} tarjetas en {cat}")
            for c in raw_cards:
                m_link = re.search(r'href=[\'"](/Desaparecidos/nota_alerta_[^\'"]+)[\'"]', c)
                m_name = re.search(r'<h5[^>]*class=[\'"]card-title[\'"][^>]*>[\s\S]*?<a[^>]*>([^<]+)</a>', c)
                m_hd = re.search(r'href=[\'"](https://sistemas\.policia\.gob\.pe/archivos/sistema_denuncias/imagenes/[^\'"]+)[\'"]', c)
                if m_link:
                    cards.append({
                        'link': f"https://desaparecidosenperu.policia.gob.pe{m_link.group(1)}",
                        'path': m_link.group(1),
                        'name': m_name.group(1).strip() if m_name else '',
                        'hd': m_hd.group(1) if m_hd else ''
                    })
        except Exception as e:
            print(f"  Error leyendo {page_url}: {e}")

    raw_id_to_card = {}
    name_to_card = {}
    hd_to_card = {}

    for c in cards:
        raw_id = c['path'].split('/')[-1].replace('?', '_').replace('&', '_').replace('=', '_').replace('%', '')
        raw_id_to_card[raw_id] = c
        norm_name = re.sub(r'\s+', ' ', c['name'].upper().strip())
        name_to_card[norm_name] = c
        if c['hd']:
            hd_to_card[c['hd']] = c

    mapping = {}
    for r in ingested_records:
        doc_id = r.get('doc_id') or r.get('id')
        if 'nombres' in r:
            full_name = f"{r.get('nombres', '')} {r.get('apellidos', '')}".upper().strip()
        else:
            full_name = r.get('nombre', '').upper().strip()
        full_name = re.sub(r'\s+', ' ', full_name)
        foto = r.get('foto_url', '')
        
        target_card = None
        m = re.search(r'pnp_([^.]+)\.jpg', foto)
        if m and m.group(1) in raw_id_to_card:
            target_card = raw_id_to_card[m.group(1)]
        elif full_name in name_to_card:
            target_card = name_to_card[full_name]
        elif foto in hd_to_card:
            target_card = hd_to_card[foto]
        else:
            for cname, c in name_to_card.items():
                if (len(full_name) > 6 and full_name in cname) or (len(cname) > 6 and cname in full_name):
                    target_card = c
                    break

        if target_card:
            mapping[doc_id] = {
                'doc_id': doc_id,
                'name': full_name,
                'detail_url': target_card['link']
            }
        elif m:
            raw = m.group(1)
            cand = raw[:-2] + '%3d' if raw.endswith('3d') else raw
            reconstructed_url = f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_menor/{cand}"
            mapping[doc_id] = {
                'doc_id': doc_id,
                'name': full_name,
                'detail_url': reconstructed_url
            }
        elif doc_id and doc_id.startswith('pnp_'):
            raw = doc_id.replace('pnp_', '')
            cand = raw[:-2] + '%3d' if raw.endswith('3d') else raw
            reconstructed_url = f"https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_menor/{cand}"
            mapping[doc_id] = {
                'doc_id': doc_id,
                'name': full_name,
                'detail_url': reconstructed_url
            }

    print(f"Mapeo completado: {len(mapping)} / {len(ingested_records)} casos listos para procesamiento.")
    return mapping

def check_pnp_url(url):
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=10) as res:
            if res.status != 200:
                return False
            html = res.read().decode('utf-8', errors='ignore')
            return 'NOTA DE ALERTA' in html and 'DATOS DE LA PERSONA DESAPARECIDA' in html
    except Exception:
        return False

def process_case(case_info, worker_id, total, counter_dict):
    doc_id = case_info['doc_id']
    name = case_info['name']
    url = case_info['detail_url']
    
    # Validar que la página de la PNP responda y contenga la Nota de Alerta real
    if not check_pnp_url(url):
        fixed_url = url
        if url.endswith('7d'):
            fixed_url = url[:-2] + '%3d'
        elif not url.endswith('%3d') and '=' in url:
            fixed_url = url.replace('=', '%3d')
            
        if fixed_url != url and check_pnp_url(fixed_url):
            url = fixed_url
        else:
            print(f"[OMITIDO] {name} ({doc_id}): Caso archivado o sin Nota de Alerta activa en portal PNP.", flush=True)
            return doc_id, None
    
    temp_png = f"tools/temp_{worker_id}_{doc_id}.png"
    temp_jpg = f"tools/temp_{worker_id}_{doc_id}.jpg"
    
    for attempt in range(1, 3):
        try:
            token = get_valid_token()
            capture_and_process_nota(url, temp_png, temp_jpg, worker_id)
            size_kb = os.path.getsize(temp_jpg) / 1024
            
            public_url = upload_ficha_to_storage(token, temp_jpg, doc_id)
            patch_firestore_doc(token, doc_id, public_url)
            
            # Clean up temp jpg
            if os.path.exists(temp_jpg):
                try: os.remove(temp_jpg)
                except: pass
                
            counter_dict['done'] += 1
            idx = counter_dict['done']
            print(f"[{idx:03d}/{total:03d}] OK: {name} (DocID: {doc_id}) -> {size_kb:.1f} KB", flush=True)
            return doc_id, public_url
            
        except Exception as e:
            if attempt == 1:
                time.sleep(2)
                continue
            print(f"[ERROR] Case {name} ({doc_id}) failed: {e}", flush=True)
            if os.path.exists(temp_png):
                try: os.remove(temp_png)
                except: pass
            if os.path.exists(temp_jpg):
                try: os.remove(temp_jpg)
                except: pass
            return doc_id, None

def main():
    print("=" * 70, flush=True)
    print("ACOPLANDO NOTAS DE ALERTA A LOS CASOS DE FIRESTORE (SIN MODIFICAR OTROS CAMPOS)", flush=True)
    print("=" * 70, flush=True)
    print(f"Navegador detectado: {BROWSER_PATH}", flush=True)
    
    # 1. Load ingested records
    with open(INGESTED_FILE, 'r', encoding='utf-8') as f:
        ingested_records = json.load(f)
    print(f"Total de casos en la base de datos: {len(ingested_records)}", flush=True)
    
    # 2. Load progress checkpoint
    progress = {}
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE, 'r', encoding='utf-8') as f:
                progress = json.load(f)
        except:
            progress = {}
    print(f"Casos ya procesados previamente (alta resolución): {len(progress)}", flush=True)
    
    # 3. Build URL mapping
    mapping = build_case_url_mapping(ingested_records)
    
    force_all = '--force' in sys.argv
    limit_val = None
    for arg in sys.argv:
        if arg.startswith('--limit='):
            try: limit_val = int(arg.split('=')[1])
            except: pass

    # 4. Filter remaining cases
    pending = []
    for r in ingested_records:
        did = r.get('doc_id') or r.get('id')
        if (force_all or did not in progress) and did in mapping:
            pending.append(mapping[did])
            
    if limit_val:
        pending = pending[:limit_val]
            
    total_pending = len(pending)
    print(f"Casos a procesar para este lote (force={force_all}): {total_pending}", flush=True)
    
    if total_pending == 0:
        print("¡Todos los casos ya tienen su Nota de Alerta asociada!", flush=True)
        return
        
    counter_dict = {'done': len(progress) if not force_all else 0}
    total_all = len(ingested_records)
    
    # Process with 3 concurrent workers for optimal stability without lock conflicts
    max_workers = 3
    print(f"Iniciando procesamiento concurrente con {max_workers} trabajadores...", flush=True)
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(process_case, case, i % max_workers, total_all, counter_dict): case
            for i, case in enumerate(pending)
        }
        
        for future in as_completed(futures):
            doc_id, ficha_url = future.result()
            if ficha_url:
                progress[doc_id] = ficha_url
                # Save checkpoint atomically
                try:
                    with open(PROGRESS_FILE + ".tmp", 'w', encoding='utf-8') as f:
                        json.dump(progress, f, indent=2)
                    os.replace(PROGRESS_FILE + ".tmp", PROGRESS_FILE)
                except Exception as e:
                    print(f"Checkpoint save warning: {e}", flush=True)
                    
    print("\n" + "=" * 70, flush=True)
    print(f"PROCESO COMPLETADO: {len(progress)} / {len(ingested_records)} casos actualizados con éxito.", flush=True)
    print("=" * 70, flush=True)

if __name__ == '__main__':
    main()
