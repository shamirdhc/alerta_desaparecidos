import urllib.request
import urllib.parse
import ssl
import re
import json
import uuid
import os
import sys
import time
import subprocess
from datetime import datetime, timezone
from html.parser import HTMLParser
from concurrent.futures import ThreadPoolExecutor, as_completed
from PIL import Image
import shutil

try:
    from tools.comisaria_matcher import find_comisaria_phone
except ImportError:
    from comisaria_matcher import find_comisaria_phone


if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

# Configuración SSL y Headers
ctx = ssl._create_unverified_context()
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
}

CONFIG_PATH = r'C:\Users\51948\.config\configstore\firebase-tools.json'
STORAGE_BUCKET = 'alerta-desaparecidos-pnp.firebasestorage.app'
FIRESTORE_PROJECT = 'alerta-desaparecidos-pnp'
CACHE_PATH = os.path.join(os.path.dirname(__file__), 'pnp_ingested_records.json')
PROGRESS_PATH = os.path.join(os.path.dirname(__file__), 'notas_progress.json')
PROGRESS_V2_PATH = os.path.join(os.path.dirname(__file__), 'notas_progress_v2.json')

def find_browser():
    """Detecta de forma multiplataforma el binario del navegador (Edge/Chrome en Windows, Chrome/Chromium en Linux/Ubuntu)."""
    candidates = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        "/usr/bin/google-chrome",
        "/usr/bin/chromium-browser",
        "/usr/bin/chromium",
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

DEPARTAMENTOS_MAP = {
    'AMAZONAS': 'AMAZONAS',
    'ANCASH': 'ÁNCASH',
    'ÁNCASH': 'ÁNCASH',
    'NCASH': 'ÁNCASH',
    'APURIMAC': 'APURÍMAC',
    'APURÍMAC': 'APURÍMAC',
    'APURMAC': 'APURÍMAC',
    'AREQUIPA': 'AREQUIPA',
    'AYACUCHO': 'AYACUCHO',
    'CAJAMARCA': 'CAJAMARCA',
    'CALLAO': 'CALLAO',
    'CUSCO': 'CUSCO',
    'CUZCO': 'CUSCO',
    'HUANCAVELICA': 'HUANCAVELICA',
    'HUANUCO': 'HUÁNUCO',
    'HUÁNUCO': 'HUÁNUCO',
    'HUNUCO': 'HUÁNUCO',
    'ICA': 'ICA',
    'JUNIN': 'JUNÍN',
    'JUNÍN': 'JUNÍN',
    'JUNN': 'JUNÍN',
    'LA LIBERTAD': 'LA LIBERTAD',
    'LAMBAYEQUE': 'LAMBAYEQUE',
    'LIMA': 'LIMA',
    'LORETO': 'LORETO',
    'MADRE DE DIOS': 'MADRE DE DIOS',
    'MOQUEGUA': 'MOQUEGUA',
    'PASCO': 'PASCO',
    'PIURA': 'PIURA',
    'PUNO': 'PUNO',
    'SAN MARTIN': 'SAN MARTÍN',
    'SAN MARTÍN': 'SAN MARTÍN',
    'SAN MARTN': 'SAN MARTÍN',
    'TACNA': 'TACNA',
    'TUMBES': 'TUMBES',
    'UCAYALI': 'UCAYALI'
}

def get_access_token():
    """Obtiene el token de autenticación de Firebase desde variables de entorno o archivo de configuración con auto-refresh."""
    env_token = os.environ.get('FIREBASE_ACCESS_TOKEN') or os.environ.get('GOOGLE_ACCESS_TOKEN')
    if env_token:
        return env_token.strip()

    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
                d = json.load(f)
            tokens = d.get('tokens', {})
            expires_at = tokens.get('expires_at', 0)
            current_ms = time.time() * 1000
            
            # Si expira en menos de 5 minutos, refrescar automáticamente vía OAuth2
            if expires_at - current_ms < 300000 and 'refresh_token' in tokens:
                print("🔄 [AUTH] Refrescando token de acceso de Google OAuth...")
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
                    json.dump(d, f, indent=2)
                print("✅ [AUTH] Token refrescado exitosamente.")
                
            return tokens['access_token']
        except Exception as e:
            print(f"⚠️ No se pudo leer o refrescar token de {CONFIG_PATH}: {e}")

    # Fallback para runners de GitHub con GOOGLE_APPLICATION_CREDENTIALS
    sa_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
    if sa_path and os.path.exists(sa_path):
        try:
            from google.oauth2 import service_account
            import google.auth.transport.requests
            creds = service_account.Credentials.from_service_account_file(
                sa_path,
                scopes=['https://www.googleapis.com/auth/cloud-platform']
            )
            auth_req = google.auth.transport.requests.Request()
            creds.refresh(auth_req)
            return creds.token
        except Exception as e:
            print(f"⚠️ Error generando token de Service Account: {e}")

    raise RuntimeError("No se encontró ningún token de acceso de Firebase válido.")

def normalize_department(raw_dep):
    if not raw_dep:
        return 'LIMA'
    clean = raw_dep.strip().upper()
    if clean.startswith('LIMA'):
        return 'LIMA'
    for k, v in DEPARTAMENTOS_MAP.items():
        if k == clean or k in clean:
            return v
    return clean

def parse_date_to_iso(date_str):
    if not date_str:
        return None
    date_str = date_str.strip().lower()
    is_pm = 'p.m.' in date_str or 'pm' in date_str
    is_am = 'a.m.' in date_str or 'am' in date_str
    clean = re.sub(r'[a-z\.\s]', ' ', date_str).strip()
    parts = re.split(r'[\s/:]+', clean)
    if len(parts) >= 3:
        try:
            day = int(parts[0])
            month = int(parts[1])
            year = int(parts[2])
            hour = int(parts[3]) if len(parts) > 3 else 0
            minute = int(parts[4]) if len(parts) > 4 else 0
            second = int(parts[5]) if len(parts) > 5 else 0
            if is_pm and hour < 12:
                hour += 12
            elif is_am and hour == 12:
                hour = 0
            return f"{year:04d}-{month:02d}-{day:02d}T{hour:02d}:{minute:02d}:{second:02d}Z"
        except Exception:
            return None
    return None

class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.texts = []
        self.in_script = False

    def handle_starttag(self, tag, attrs):
        if tag in ['script', 'style']:
            self.in_script = True

    def handle_endtag(self, tag):
        if tag in ['script', 'style']:
            self.in_script = False

    def handle_data(self, data):
        if not self.in_script:
            clean = data.strip()
            if clean:
                self.texts.append(clean)

def infer_sexo(nombres, category):
    if not nombres:
        return 'MASCULINO' if category == 'MAYORES' else 'NO ESPECIFICADO'
    first_name = nombres.strip().split()[0].upper()
    female_endings = ('A', 'ITH', 'ETH', 'IA', 'NA', 'RA', 'SA', 'LA', 'MA', 'TA', 'DA')
    male_endings = ('O', 'OR', 'EL', 'ER', 'IO', 'ON', 'AN', 'OS', 'IS', 'EN', 'IN', 'EZ')
    
    male_special = {'JOSE', 'JOSÉ', 'JUAN', 'LUIS', 'CARLOS', 'JORGE', 'MANUEL', 'DAVID', 'MIGUEL', 'ANGEL', 'ÁNGEL', 'CESAR', 'CÉSAR', 'VICTOR', 'VÍCTOR', 'HECTOR', 'HÉCTOR', 'RAUL', 'RAÚL', 'JESUS', 'JESÚS', 'EDGAR', 'OSCAR', 'ÓSCAR', 'ALEX', 'FELIX', 'FÉLIX'}
    female_special = {'CARMEN', 'PILAR', 'MERCEDES', 'ISABEL', 'LUZ', 'ROCIO', 'ROCIÓ', 'BEATRIZ', 'ESTHER', 'RUTH', 'MIRIAM', 'JUDITH', 'BELEN', 'BELÉN', 'INES', 'INÉS', 'CONSUELO', 'MARIBEL'}
    
    if first_name in male_special:
        return 'MASCULINO'
    if first_name in female_special:
        return 'FEMENINO'
    if first_name.endswith(female_endings):
        return 'FEMENINO'
    if first_name.endswith(male_endings):
        return 'MASCULINO'
    return 'FEMENINO' if category == 'MUJERES' else 'MASCULINO'

def parse_card(card_html, base_category):
    m_img = re.search(r'<img[^>]+class=[\x22\x27][^"\']*foto-desa[^"\']*[\x22\x27][^>]+src=[\x22\x27]([^\x22\x27]+)[\x22\x27]', card_html)
    card_photo = m_img.group(1) if m_img else ''
    
    m_name = re.search(r'<h5[^>]*class=[\x22\x27]card-title[\x22\x27][^>]*>[\s\S]*?<a[^>]*>([^<]+)</a>', card_html)
    card_name = m_name.group(1).strip() if m_name else ''
    
    m_date = re.search(r'Hecho ocurrido el:\s*<br>\s*([^<]+)', card_html, re.IGNORECASE)
    card_date = m_date.group(1).strip() if m_date else ''
    
    m_link = re.search(r'href=[\x22\x27](/Desaparecidos/nota_alerta_[^"\']+)[\x22\x27]', card_html)
    detail_path = m_link.group(1) if m_link else ''
    
    m_hd = re.search(r'href=[\x22\x27](https://sistemas\.policia\.gob\.pe/archivos/sistema_denuncias/imagenes/[^"\']+)[\x22\x27]', card_html)
    hd_photo = m_hd.group(1) if m_hd else ''
    
    if not detail_path:
        return None
        
    detail_url = f"https://desaparecidosenperu.policia.gob.pe{detail_path}"
    raw_id = detail_path.split('/')[-1].replace('?', '_').replace('&', '_').replace('=', '_').replace('%', '')
    safe_id = f"pnp_{raw_id}"
    
    return {
        'id': safe_id,
        'category': base_category,
        'detail_url': detail_url,
        'card_name': card_name,
        'card_date': card_date,
        'card_photo': card_photo,
        'hd_photo': hd_photo
    }

def parse_api_item(item, tipo):
    dni = item.get('DNI', '')
    if not dni:
        return None
    url_prefix = "/Desaparecidos/nota_alerta_menor?id=" if str(tipo) == '1' else "/Desaparecidos/nota_alerta_mujer?id="
    detail_url = f"https://desaparecidosenperu.policia.gob.pe{url_prefix}{dni}"
    raw_id = dni.replace('?', '_').replace('&', '_').replace('=', '_').replace('%', '')
    safe_id = f"pnp_{raw_id}"
    if str(tipo) == '4':
        category = 'UBICADOS'
    elif str(tipo) == '1':
        category = 'MENORES'
    else:
        category = 'ADULTOS_Y_MUJERES'
    return {
        'id': safe_id,
        'category': category,
        'detail_url': detail_url,
        'card_name': item.get('NOMBRE_COMPLETO', '').strip(),
        'card_date': item.get('FECHA_DESAPARICION', '').strip(),
        'card_photo': item.get('RUTA_IMAGEN', '').strip(),
        'hd_photo': item.get('IMAGEN', '').strip()
    }

def generate_keywords(nombres, apellidos, dni, lugar, dept):
    words = set()
    raw = f"{nombres} {apellidos} {dni or ''} {lugar or ''} {dept or ''}".lower()
    clean = (raw.replace('á', 'a')
                .replace('é', 'e')
                .replace('í', 'i')
                .replace('ó', 'o')
                .replace('ú', 'u')
                .replace('ñ', 'n'))
    tokens = re.split(r'[\s\-,./;:]+', raw) + re.split(r'[\s\-,./;:]+', clean)
    for t in tokens:
        t = t.strip()
        if len(t) >= 2:
            words.add(t)
            for l in range(2, min(len(t), 8)):
                words.add(t[:l])
    return sorted(list(words))[:80]

def load_known_cases_cache():
    """Carga los casos ya conocidos y sus fotos desde pnp_ingested_records.json para verificación instantánea O(1)."""
    known_ids = set()
    known_names = set()
    known_photos = {}
    if os.path.exists(CACHE_PATH):
        try:
            with open(CACHE_PATH, 'r', encoding='utf-8') as f:
                data = json.load(f)
            for item in data:
                foto = item.get('foto_url', '')
                doc_id = item.get('doc_id') or item.get('id')
                if doc_id:
                    known_ids.add(doc_id)
                    if foto and 'firebasestorage' in foto:
                        known_photos[doc_id] = foto
                m = re.search(r'(pnp_[a-zA-Z0-9_\-]+)', foto)
                if m:
                    known_ids.add(m.group(1))
                    if 'firebasestorage' in foto:
                        known_photos[m.group(1)] = foto
                full_name = f"{item.get('nombres', '')} {item.get('apellidos', '')}".strip().upper()
                if not full_name:
                    full_name = item.get('nombre', '').strip().upper()
                if full_name:
                    known_names.add(full_name)
            print(f"📦 Caché cargada: {len(known_ids)} IDs, {len(known_names)} nombres y {len(known_photos)} fotos en Storage.")
        except Exception as e:
            print(f"⚠️ Error leyendo caché local de casos conocidos: {e}")
    return known_ids, known_names, known_photos

def load_known_fichas_cache():
    """Carga el registro de notas de alerta ya vinculadas desde v2 y v1."""
    combined = {}
    for p in [PROGRESS_PATH, PROGRESS_V2_PATH]:
        if os.path.exists(p):
            try:
                with open(p, 'r', encoding='utf-8') as f:
                    combined.update(json.load(f))
            except Exception:
                pass
    return combined

def record_ficha_in_cache(case_id, ficha_url):
    """Guarda atómicamente el registro de una ficha completada en los archivos de caché."""
    for p in [PROGRESS_PATH, PROGRESS_V2_PATH]:
        try:
            data = {}
            if os.path.exists(p):
                with open(p, 'r', encoding='utf-8') as f:
                    data = json.load(f)
            data[case_id] = ficha_url
            with open(p + ".tmp", 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
            os.replace(p + ".tmp", p)
        except Exception as e:
            print(f"⚠️ Error actualizando {p}: {e}")

def check_case_exists_in_firestore(token, case_id):
    """Verifica si el caso ya existe directamente en Firestore en milisegundos."""
    url = f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/desaparecidos/{case_id}"
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    try:
        with urllib.request.urlopen(req, timeout=4) as res:
            return res.status == 200
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        return False
    except Exception:
        return False

def check_ubicado_status_in_firestore(token, case_info):
    """Verifica si la persona ubicada ya está registrada con estado 'encontrado' en Firestore.
    Si ya existe pero con estado 'activo' u otro, actualiza el caso a 'encontrado' inmediatamente."""
    case_id = case_info['id']
    url = f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/desaparecidos/{case_id}"
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    try:
        with urllib.request.urlopen(req, timeout=5) as res:
            doc = json.loads(res.read().decode('utf-8'))
            fields = doc.get('fields', {})
            estado = fields.get('estado', {}).get('stringValue', '')
            if estado == 'encontrado':
                return True
            
            # ¡EXISTE PERO ESTABA ACTIVO! Actualizar a encontrado ahora mismo
            now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            encontrado_detalles = "Persona ubicada con vida y protegida por la División de Investigación y Búsqueda de Personas Desaparecidas de la Policía Nacional del Perú (PNP)."
            patch_payload = {
                'fields': {
                    'estado': {'stringValue': 'encontrado'},
                    'fecha_encontrado': {'timestampValue': now_iso},
                    'encontradoDetalles': {'stringValue': encontrado_detalles},
                    'fecha_actualizacion': {'timestampValue': now_iso}
                }
            }
            patch_url = f"{url}?updateMask.fieldPaths=estado&updateMask.fieldPaths=fecha_encontrado&updateMask.fieldPaths=encontradoDetalles&updateMask.fieldPaths=fecha_actualizacion"
            p_req = urllib.request.Request(patch_url, data=json.dumps(patch_payload).encode('utf-8'), headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, method='PATCH')
            with urllib.request.urlopen(p_req, timeout=8):
                pass
                
            try:
                hist_id = f"hist_{case_id}"
                hist_url = f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/historial_encontrados/{hist_id}"
                nombre = fields.get('nombre', {}).get('stringValue') or case_info.get('card_name', '')
                foto = fields.get('foto_url', {}).get('stringValue') or ''
                comisaria = fields.get('unidad_a_cargo', {}).get('stringValue') or 'PNP Central'
                tel = fields.get('telefono_contacto', {}).get('stringValue') or '01 418-4030'
                hist_fields = {
                    'desaparecidoId': {'stringValue': case_id},
                    'nombreDesaparecido': {'stringValue': nombre.upper()},
                    'fotoDesaparecidoUrl': {'stringValue': foto},
                    'policiaId': {'stringValue': 'PNP_SISTEMA_CENTRAL'},
                    'nombrePolicia': {'stringValue': 'Policía Nacional del Perú'},
                    'placaPolicia': {'stringValue': 'PNP-OFICIAL'},
                    'comisaria': {'stringValue': comisaria},
                    'telefonoContacto': {'stringValue': tel},
                    'fechaEncontrado': {'timestampValue': now_iso},
                    'detalles': {'stringValue': encontrado_detalles},
                    'estado': {'stringValue': 'verificado'},
                    'origen': {'stringValue': 'PNP_TRANSICION_UBICADOS'}
                }
                h_req = urllib.request.Request(hist_url, data=json.dumps({'fields': hist_fields}).encode('utf-8'), headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, method='PATCH')
                with urllib.request.urlopen(h_req, timeout=8):
                    pass
            except Exception as e:
                print(f"⚠️ Error registrando en historial_encontrados: {e}")
                
            print(f"🎉 [CASO RESUELTO Y ACTUALIZADO] Persona encontrada en PNP: {case_info.get('card_name')} ({case_id})")
            return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        return False
    except Exception:
        return False

def check_case_exists(token, case_info, known_ids, known_names):
    """Verifica en memoria O(1) y luego en Firestore."""
    if case_info.get('category') == 'UBICADOS':
        return check_ubicado_status_in_firestore(token, case_info)

    if case_info['id'] in known_ids:
        return True
    
    clean_card_name = re.sub(r'&#[0-9]+;', '', case_info['card_name']).strip().upper()
    if clean_card_name in known_names:
        return True
        
    return check_case_exists_in_firestore(token, case_info['id'])

def upload_photo_to_storage(token, photo_url, case_id):
    if not photo_url:
        return '', 'NO_PHOTO'
    try:
        req = urllib.request.Request(photo_url, headers=HEADERS)
        with urllib.request.urlopen(req, context=ctx, timeout=12) as res:
            img_bytes = res.read()
            content_type = res.headers.get('Content-Type') or 'image/jpeg'
            
        if len(img_bytes) < 100:
            return photo_url, "DIRECT_FALLBACK"
            
        file_path = f"desaparecidos/fotos/{case_id}.jpg"
        encoded_path = urllib.parse.quote(file_path, safe='')
        download_token = str(uuid.uuid4())
        
        upload_url = f"https://storage.googleapis.com/upload/storage/v1/b/{STORAGE_BUCKET}/o?uploadType=media&name={encoded_path}"
        upload_req = urllib.request.Request(upload_url, data=img_bytes, headers={'Authorization': f'Bearer {token}', 'Content-Type': content_type})
        with urllib.request.urlopen(upload_req, timeout=15):
            pass
            
        meta_url = f"https://storage.googleapis.com/storage/v1/b/{STORAGE_BUCKET}/o/{encoded_path}"
        meta_body = json.dumps({'metadata': {'firebaseStorageDownloadTokens': download_token}}).encode('utf-8')
        meta_req = urllib.request.Request(meta_url, data=meta_body, headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, method='PATCH')
        with urllib.request.urlopen(meta_req, timeout=15):
            pass
            
        public_url = f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded_path}?alt=media&token={download_token}"
        return public_url, "STORAGE"
    except Exception as e:
        print(f"⚠️ Error al subir foto para {case_id}: {e}")
        return photo_url, "ERR"

def capture_and_upload_nota_alerta(token, detail_url, case_id):
    """Captura la Nota de Alerta oficial (#idContenedor) vía headless browser, la recorta y la sube a Firebase Storage."""
    if not BROWSER_PATH or not detail_url:
        return None
        
    temp_png = os.path.abspath(f"tools/temp_nota_{case_id}_{uuid.uuid4().hex[:6]}.png")
    temp_jpg = os.path.abspath(f"tools/temp_nota_{case_id}_{uuid.uuid4().hex[:6]}.jpg")
    temp_profile_dir = os.path.abspath(f"tools/profile_sync_{uuid.uuid4().hex[:6]}")
    os.makedirs(temp_profile_dir, exist_ok=True)
    
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
            f"--user-data-dir={temp_profile_dir}",
            "--ignore-certificate-errors",
            "--window-size=1200,2250",
            "--hide-scrollbars",
            f"--screenshot={temp_png}",
            detail_url
        ]
        res = subprocess.run(cmd, capture_output=True, timeout=40)
        if not os.path.exists(temp_png) or os.path.getsize(temp_png) == 0:
            print(f"⚠️ No se pudo capturar screenshot de Nota de Alerta para {case_id} (exit code: {res.returncode})")
            return None
            
        with Image.open(temp_png) as img:
            w, h = img.size
            # Recorte 100% íntegro de la Nota de Alerta oficial PNP (1160 x 2050 px)
            # Salta el menú/navbar superior (y=260) e incluye el escudo completo a la izquierda (x=20),
            # datos, fotografía, señas particulares y pie de página oficial con teléfonos de emergencia (y=2200)
            left = 20
            top = 260
            right = min(1180, w)
            bottom = min(2200, h)
            cropped = img.crop((left, top, right, bottom))
            cropped.convert("RGB").save(temp_jpg, "JPEG", quality=92, optimize=True)
            
        with open(temp_jpg, 'rb') as f:
            img_bytes = f.read()
            
        file_path = f"desaparecidos/fichas/{case_id}_nota.jpg"
        encoded_path = urllib.parse.quote(file_path, safe='')
        download_token = str(uuid.uuid4())
        
        # 1. Subir archivo a Storage
        upload_url = f"https://storage.googleapis.com/upload/storage/v1/b/{STORAGE_BUCKET}/o?uploadType=media&name={encoded_path}"
        upload_req = urllib.request.Request(
            upload_url,
            data=img_bytes,
            headers={'Authorization': f'Bearer {token}', 'Content-Type': 'image/jpeg'}
        )
        with urllib.request.urlopen(upload_req, timeout=25):
            pass
            
        # 2. Patch metadata con token de descarga pública
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
    except Exception as e:
        print(f"⚠️ Error generando Nota de Alerta para {case_id}: {e}")
        return None
    finally:
        if os.path.exists(temp_png):
            try: os.remove(temp_png)
            except: pass
        if os.path.exists(temp_jpg):
            try: os.remove(temp_jpg)
            except: pass
        shutil.rmtree(temp_profile_dir, ignore_errors=True)

def patch_ficha_firestore_doc(token, doc_id, ficha_url):
    """Actualiza el campo imagen_ficha_url en Firestore para un documento existente."""
    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    firestore_url = (
        f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/desaparecidos/{doc_id}"
        f"?updateMask.fieldPaths=imagen_ficha_url&updateMask.fieldPaths=necesita_nota_alerta&updateMask.fieldPaths=fecha_actualizacion"
    )
    payload = {
        'fields': {
            'imagen_ficha_url': {'stringValue': ficha_url},
            'necesita_nota_alerta': {'booleanValue': False},
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

def patch_photo_firestore_doc(token, doc_id, photo_url):
    """Actualiza el campo foto_url en Firestore cuando PNP autoriza una nueva fotografía."""
    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    firestore_url = (
        f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/desaparecidos/{doc_id}"
        f"?updateMask.fieldPaths=foto_url&updateMask.fieldPaths=fecha_actualizacion"
    )
    payload = {
        'fields': {
            'foto_url': {'stringValue': photo_url},
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

def record_photo_in_cache(case_id, photo_url):
    """Actualiza la foto en la caché local pnp_ingested_records.json."""
    try:
        if os.path.exists(CACHE_PATH):
            with open(CACHE_PATH, 'r', encoding='utf-8') as f:
                data = json.load(f)
            updated = False
            for item in data:
                if (item.get('doc_id') == case_id or item.get('id') == case_id):
                    item['foto_url'] = photo_url
                    updated = True
                    break
            if updated:
                with open(CACHE_PATH, 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"⚠️ Error actualizando foto en caché local: {e}")

def process_and_save_case(token, case_info):
    """Procesa los detalles completos de un caso nuevo, extrae ficha oficial y lo guarda en Firestore."""
    try:
        detail_url = case_info['detail_url']
        req = urllib.request.Request(detail_url, headers=HEADERS)
        with urllib.request.urlopen(req, context=ctx, timeout=15) as res:
            raw = res.read()
        html = raw.decode('utf-8', errors='ignore')
        
        parser = TextExtractor()
        parser.feed(html)
        tokens = parser.texts
        
        def get_val(labels):
            for idx, t in enumerate(tokens):
                t_norm = t.upper().replace(':', '').strip()
                for l in labels:
                    if t_norm == l.upper():
                        if idx + 1 < len(tokens):
                            val = tokens[idx + 1].strip()
                            if not val.endswith(':') and val not in ['CARACTERISTICAS', 'DATOS DE LA PERSONA DESAPARECIDA', 'SEÑAS PARTICULARES', 'CARACTERÍSTICAS']:
                                return val
            return ''
            
        apellidos = get_val(['APELLIDOS'])
        nombres = get_val(['NOMBRES'])
        edad = get_val(['EDAD'])
        f_nac = get_val(['F./ NACIMIENTO', 'F. NACIMIENTO', 'FECHA DE NACIMIENTO'])
        f_hecho = get_val(['FECHA DEL HECHO', 'FECHA DE DESAPARICION', 'FECHA DE DESAPARICIÓN']) or case_info['card_date']
        lugar_hecho = get_val(['LUGAR DEL HECHO', 'LUGAR DE DESAPARICION', 'LUGAR DE DESAPARICIÓN'])
        denuncia = get_val(['N° DE LA DENUNCIA', 'DENUNCIA N°', 'Nº DE LA DENUNCIA', 'DENUNCIA Nº'])
        dependencia = get_val(['DEPENDENCIA POLICIAL'])
        
        tez = get_val(['TEZ', 'PIEL'])
        ojos = get_val(['OJOS'])
        cabello = get_val(['CABELLO', 'CABELLOS'])
        estatura = get_val(['ESTATURA'])
        contextura = get_val(['CONTEXTURA'])
        vestimenta = get_val(['VESTIMENTA'])
        circunstancias = get_val(['CIRCUNSTANCIAS'])
        
        if not nombres and case_info['card_name']:
            parts = case_info['card_name'].split()
            if len(parts) >= 2:
                nombres = parts[0]
                apellidos = ' '.join(parts[1:])
            else:
                nombres = case_info['card_name']
                apellidos = ''
                
        departamento = 'LIMA'
        provincia = 'LIMA'
        distrito = 'LIMA'
        direccion = ''
        if lugar_hecho:
            parts = [p.strip() for p in lugar_hecho.split('-') if p.strip()]
            if len(parts) >= 1:
                departamento = normalize_department(parts[0])
            if len(parts) >= 2:
                provincia = parts[1].upper()
            if len(parts) >= 3:
                distrito = parts[2].upper()
            if len(parts) >= 4:
                direccion = ' - '.join(parts[3:])
                
        sexo = infer_sexo(nombres, case_info['category'])
        
        # Resolver Comisaría y Teléfono directo de la dependencia oficial
        comisaria_info = find_comisaria_phone(dependencia, departamento, provincia, distrito)
        telefono_comisaria = comisaria_info.get('telefono') or '01 418-4030'
        nombre_comisaria = comisaria_info.get('nombre') or (dependencia if dependencia else "Comisaría PNP")
        
        caract_parts = []
        if edad: caract_parts.append(f"Edad: {edad}")
        if estatura: caract_parts.append(f"Estatura: {estatura}")
        if contextura: caract_parts.append(f"Contextura: {contextura}")
        if tez: caract_parts.append(f"Tez: {tez}")
        if ojos: caract_parts.append(f"Ojos: {ojos}")
        if cabello: caract_parts.append(f"Cabello: {cabello}")
        if vestimenta: caract_parts.append(f"Vestimenta: {vestimenta}")
        if circunstancias: caract_parts.append(f"Circunstancias: {circunstancias}")
        if direccion: caract_parts.append(f"Dirección: {direccion}")
        if denuncia: caract_parts.append(f"Denuncia PNP N°: {denuncia}")
        if nombre_comisaria: caract_parts.append(f"Comisaría: {nombre_comisaria} (Tel: {telefono_comisaria})")
        
        detalles_adicionales = ". ".join(caract_parts) if caract_parts else "Caso registrado en el portal oficial de la PNP."
        
        # 1. Subir foto de rostro
        photo_to_upload = case_info['hd_photo'] or case_info['card_photo']
        uploaded_photo_url, _ = upload_photo_to_storage(token, photo_to_upload, case_info['id'])
        
        # 2. Capturar y subir Nota de Alerta oficial
        uploaded_ficha_url = capture_and_upload_nota_alerta(token, detail_url, case_info['id'])
        if uploaded_ficha_url:
            record_ficha_in_cache(case_info['id'], uploaded_ficha_url)
            print(f"   📄 Nota de Alerta generada con éxito para {case_info['id']}")
        else:
            print(f"   ⚠️ Nota de Alerta no disponible para {case_info['id']}, continuará con foto de rostro.")
        
        now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        fecha_desaparicion_iso = parse_date_to_iso(f_hecho) or now_iso
        fecha_nacimiento_iso = parse_date_to_iso(f_nac)
        
        is_ubicado = case_info.get('category') == 'UBICADOS'
        estado_val = 'encontrado' if is_ubicado else 'activo'
        encontrado_detalles = "Persona ubicada con vida y protegida por la División de Investigación y Búsqueda de Personas Desaparecidas de la Policía Nacional del Perú (PNP)."
        
        doc_fields = {
            'nombres': {'stringValue': nombres.upper()},
            'apellidos': {'stringValue': apellidos.upper()},
            'nombre': {'stringValue': f"{nombres} {apellidos}".upper()},
            'sexo': {'stringValue': sexo},
            'telefono_contacto': {'stringValue': telefono_comisaria},
            'departamento': {'stringValue': departamento},
            'provincia': {'stringValue': provincia},
            'distrito': {'stringValue': distrito},
            'detalles_adicionales': {'stringValue': detalles_adicionales},
            'estado': {'stringValue': estado_val},
            'foto_url': {'stringValue': uploaded_photo_url},
            'fecha_desaparicion': {'timestampValue': fecha_desaparicion_iso},
            'fecha_creacion': {'timestampValue': now_iso},
            'fecha_actualizacion': {'timestampValue': now_iso},
            'origen_datos': {'stringValue': 'PNP_OFICIAL_UBICADOS' if is_ubicado else 'PNP_OFICIAL_AUTO_SYNC'},
            'safe_id': {'stringValue': case_info['id']},
            'keywords': {'arrayValue': {'values': [{'stringValue': kw} for kw in generate_keywords(nombres, apellidos, denuncia or case_info['id'], lugar_hecho, departamento)]}}
        }
        
        if is_ubicado:
            doc_fields['fecha_encontrado'] = {'timestampValue': now_iso}
            doc_fields['encontradoDetalles'] = {'stringValue': encontrado_detalles}
            
        if uploaded_ficha_url:
            doc_fields['imagen_ficha_url'] = {'stringValue': uploaded_ficha_url}
        if fecha_nacimiento_iso:
            doc_fields['fecha_nacimiento'] = {'timestampValue': fecha_nacimiento_iso}
        if denuncia:
            doc_fields['dni'] = {'stringValue': denuncia}
        if nombre_comisaria:
            doc_fields['unidad_a_cargo'] = {'stringValue': nombre_comisaria}
        elif dependencia:
            doc_fields['unidad_a_cargo'] = {'stringValue': dependencia}
            
        case_doc_id = case_info['id']
        firestore_url = f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/desaparecidos/{case_doc_id}"
        payload = {'fields': doc_fields}
        body = json.dumps(payload).encode('utf-8')
        
        fs_req = urllib.request.Request(firestore_url, data=body, headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, method='PATCH')
        with urllib.request.urlopen(fs_req, timeout=15):
            pass
            
        # Si es persona ubicada, registrar también en historial_encontrados
        if is_ubicado:
            try:
                hist_id = f"hist_{case_info['id']}"
                hist_url = f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/historial_encontrados/{hist_id}"
                hist_fields = {
                    'desaparecidoId': {'stringValue': case_info['id']},
                    'nombreDesaparecido': {'stringValue': f"{nombres} {apellidos}".upper()},
                    'fotoDesaparecidoUrl': {'stringValue': uploaded_photo_url},
                    'policiaId': {'stringValue': 'PNP_SISTEMA_CENTRAL'},
                    'nombrePolicia': {'stringValue': 'Policía Nacional del Perú'},
                    'placaPolicia': {'stringValue': 'PNP-OFICIAL'},
                    'comisaria': {'stringValue': nombre_comisaria},
                    'telefonoContacto': {'stringValue': telefono_comisaria},
                    'fechaEncontrado': {'timestampValue': now_iso},
                    'detalles': {'stringValue': encontrado_detalles},
                    'estado': {'stringValue': 'verificado'},
                    'origen': {'stringValue': 'PNP_PORTAL_OFICIAL'}
                }
                h_req = urllib.request.Request(hist_url, data=json.dumps({'fields': hist_fields}).encode('utf-8'), headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, method='PATCH')
                with urllib.request.urlopen(h_req, timeout=10):
                    pass
            except Exception as e:
                print(f"⚠️ Error registrando en historial_encontrados: {e}")
            
        print(f"✨ [NUEVO CASO REGISTRADO] {nombres} {apellidos} ({departamento}) - ID: {case_doc_id} (Ficha: {'SÍ' if uploaded_ficha_url else 'NO'})")
        return {
            'doc_id': case_doc_id,
            'id': case_doc_id,
            'nombres': nombres.upper(),
            'apellidos': apellidos.upper(),
            'nombre': f"{nombres} {apellidos}".upper(),
            'departamento': departamento,
            'provincia': provincia,
            'distrito': distrito,
            'foto_url': uploaded_photo_url,
            'imagen_ficha_url': uploaded_ficha_url or '',
            'fecha_desaparicion': fecha_desaparicion_iso
        }
    except Exception as e:
        print(f"❌ Error procesando nuevo caso {case_info.get('id')}: {e}")
        return None

def update_heartbeat(token, status, new_cases_count, origin='github_actions', error_msg=None):
    """Registra el pulso de sincronización en Firestore (system_status/sync_pnp)."""
    try:
        now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        fields = {
            'ultima_sincronizacion': {'timestampValue': now_iso},
            'estado': {'stringValue': status},
            'casos_nuevos': {'integerValue': str(new_cases_count)},
            'origen': {'stringValue': origin},
        }
        if error_msg:
            fields['ultimo_error'] = {'stringValue': str(error_msg)[:300]}
            
        url = f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/system_status/sync_pnp"
        payload = {'fields': fields}
        body = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(url, data=body, headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, method='PATCH')
        with urllib.request.urlopen(req, timeout=10):
            print(f"📡 Heartbeat registrado en Firestore: {status} ({new_cases_count} nuevos casos)")
    except Exception as e:
        print(f"⚠️ No se pudo registrar Heartbeat en Firestore: {e}")

def run_sync(dry_run=False, origin='local_script'):
    start_time = time.time()
    print("=" * 70)
    print("🔍 INICIANDO DETECCIÓN RÁPIDA INCREMENTAL DE CASOS PNP CON NOTAS DE ALERTA")
    print("=" * 70)
    print(f"🌐 Navegador detectado para captura: {BROWSER_PATH or 'NO DETECTADO'}")
    
    token = get_access_token()
    print("🔑 Autenticación con Firebase verificada.")
    
    known_ids, known_names, known_photos = load_known_cases_cache()
    known_fichas = load_known_fichas_cache()
    
    api_categories = [
        (1, 'MENORES', 'https://desaparecidosenperu.policia.gob.pe/Desaparecidos/menor_desaparecido'),
        (2, 'ADULTOS_Y_MUJERES', 'https://desaparecidosenperu.policia.gob.pe/Desaparecidos/mujer_desaparecido'),
        (4, 'UBICADOS', 'https://desaparecidosenperu.policia.gob.pe/Desaparecidos/UBICADOS'),
    ]
    
    new_cases_to_process = []
    healed_fichas_count = 0
    healed_photos_count = 0
    
    for tipo, cat, fallback_url in api_categories:
        print(f"\n📡 Consultando registros recientes de {cat}...")
        parsed_items = []
        
        # 1. Intentar primero con la API JSON directa (ultra rápida y datos completos)
        try:
            api_url = 'https://desaparecidosenperu.policia.gob.pe/Desaparecidos/Buscar'
            api_data = urllib.parse.urlencode({'Nombre': '', 'Sexo': '', 'Edad': '', 'Nacionalidad': '', 'Tipo': str(tipo)}).encode('utf-8')
            api_headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
                'X-Requested-With': 'XMLHttpRequest'
            }
            req = urllib.request.Request(api_url, data=api_data, headers=api_headers)
            with urllib.request.urlopen(req, context=ctx, timeout=15) as res:
                raw_items = json.loads(res.read().decode('utf-8', errors='replace'))
                for r in raw_items:
                    p = parse_api_item(r, tipo)
                    if p: parsed_items.append(p)
                print(f"   ⚡ API PNP devolvió {len(parsed_items)} casos recientes de {cat}.")
        except Exception as e:
            print(f"   ⚠️ API PNP no disponible ({e}). Usando fallback por HTML scraping...")
            
        # 2. Fallback HTML si la API falló
        if not parsed_items:
            try:
                req = urllib.request.Request(fallback_url, headers=HEADERS)
                with urllib.request.urlopen(req, context=ctx, timeout=20) as res:
                    html = res.read().decode('utf-8', errors='ignore')
                cards = re.findall(r'<div\s+class=[\x22\x27]col-md-3[\x22\x27]>[\s\S]*?</div>\s*</div>\s*</div>', html)
                for c in cards:
                    p = parse_card(c, cat)
                    if p: parsed_items.append(p)
                print(f"   📄 HTML devolvió {len(parsed_items)} tarjetas recientes de {cat}.")
            except Exception as e:
                print(f"   ⚠️ Error en fallback HTML: {e}")
                
        cat_new_cases = 0
        consecutive_existing = 0
        converged = False
        for parsed in parsed_items:
            exists = check_case_exists(token, parsed, known_ids, known_names)
            if exists:
                consecutive_existing += 1
                case_id = parsed['id']
                
                # 📸 AUTO-HEAL FOTO: Si el caso en Firestore no tenía foto en Firebase Storage y PNP ahora sí la autorizó/publicó
                if cat != 'UBICADOS' and case_id not in known_photos and not dry_run:
                    photo_to_upload = parsed.get('hd_photo') or parsed.get('card_photo')
                    if photo_to_upload and 'policia.gob.pe' in photo_to_upload:
                        print(f"   📸 [AUTO-HEAL FOTO] Nueva foto autorizada por PNP para {case_id} ({parsed['card_name']}). Subiendo a Storage...")
                        uploaded_photo_url, status = upload_photo_to_storage(token, photo_to_upload, case_id)
                        if uploaded_photo_url and 'firebasestorage' in uploaded_photo_url:
                            patch_photo_firestore_doc(token, case_id, uploaded_photo_url)
                            record_photo_in_cache(case_id, uploaded_photo_url)
                            known_photos[case_id] = uploaded_photo_url
                            healed_photos_count += 1
                            print(f"   ✅ [AUTO-HEAL FOTO] Foto autorizada vinculada a Firestore para {case_id}")

                # 📄 AUTO-HEAL FICHA: Si el caso no tenía Nota de Alerta generada (SIN LÍMITE de convergencia)
                if cat != 'UBICADOS' and case_id not in known_fichas and not dry_run and BROWSER_PATH:
                    print(f"   🩹 [AUTO-HEAL FICHA] Caso existente sin Nota de Alerta detectado: {case_id} ({parsed['card_name']}). Generando ficha...")
                    ficha_url = capture_and_upload_nota_alerta(token, parsed['detail_url'], case_id)
                    if ficha_url:
                        patch_ficha_firestore_doc(token, case_id, ficha_url)
                        record_ficha_in_cache(case_id, ficha_url)
                        known_fichas[case_id] = ficha_url
                        healed_fichas_count += 1
                        print(f"   ✅ [AUTO-HEAL FICHA] Nota de Alerta acoplada a Firestore para {case_id}")
                
                # Convergencia para detección de casos NUEVOS (no para auto-heal)
                if cat != 'UBICADOS' and consecutive_existing >= 5 and not converged:
                    converged = True
                    print(f"   🛑 [CONVERGENCIA DETECCIÓN] 5 casos consecutivos ya conocidos en {cat}. No se buscan más nuevos, pero se continúa auto-heal de fichas.")
                    # NO break aquí — seguimos procesando para auto-heal
            else:
                consecutive_existing = 0
                if not converged:
                    print(f"   🆕 Caso nuevo detectado: {parsed['id']} ({parsed['card_name']})")
                    new_cases_to_process.append(parsed)
                    cat_new_cases += 1
                
        if cat_new_cases == 0:
            print(f"   ✅ Categoría {cat} al día.")
            
    print("\n" + "-" * 70)
    total_new = len(new_cases_to_process)
    print(f"📊 RESUMEN: {total_new} casos nuevos | {healed_photos_count} fotos autorizadas acopladas | {healed_fichas_count} fichas auto-reparadas.")
    
    if total_new == 0:
        elapsed = time.time() - start_time
        print(f"⚡ Proceso concluido en {elapsed:.2f} segundos. Base de datos al día.")
        update_heartbeat(token, 'al_dia', 0, origin=origin)
        return 0
        
    if dry_run:
        print("💡 Modo DRY-RUN activado. No se realizaron cambios en Firestore.")
        return 0
        
    print(f"\n🚀 Procesando e ingiriendo {total_new} casos a Firestore y Storage (incluyendo Nota de Alerta)...")
    ingested_count = 0
    ingested_records = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(process_and_save_case, token, case) for case in new_cases_to_process]
        for f in as_completed(futures):
            res = f.result()
            if res:
                ingested_records.append(res)
                ingested_count += 1
                
    # Actualizar caché local
    if ingested_records:
        try:
            current_data = []
            if os.path.exists(CACHE_PATH):
                with open(CACHE_PATH, 'r', encoding='utf-8') as f:
                    current_data = json.load(f)
            current_data.extend(ingested_records)
            with open(CACHE_PATH, 'w', encoding='utf-8') as f:
                json.dump(current_data, f, ensure_ascii=False, indent=2)
            print(f"💾 Caché local actualizada con {len(ingested_records)} nuevos casos.")
        except Exception as e:
            print(f"⚠️ Error actualizando caché local: {e}")

    elapsed = time.time() - start_time
    print("=" * 70)
    print(f"🎉 SINCRONIZACIÓN EXITOSA: {ingested_count}/{total_new} nuevos casos incorporados con sus Notas de Alerta.")
    print(f"⏱️ Tiempo total: {elapsed:.2f} segundos.")
    print("=" * 70)
    
    update_heartbeat(token, 'sincronizado', ingested_count, origin=origin)
    return 0

if __name__ == '__main__':
    dry = '--dry-run' in sys.argv
    origin_arg = 'local_manual'
    for arg in sys.argv:
        if arg.startswith('--origin='):
            origin_arg = arg.split('=')[1]
            
    sys.exit(run_sync(dry_run=dry, origin=origin_arg))
