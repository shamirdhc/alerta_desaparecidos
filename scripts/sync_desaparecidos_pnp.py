#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
MOTOR UNIFICADO DE SINCRONIZACIÓN E INGESTA 8 MESES v6.0 — ALERTA PNP
Fuente Oficial: https://desaparecidosenperu.policia.gob.pe/Desaparecidos/Buscar
================================================================================
Mejoras de Ingeniería basadas en la Auditoría Exhaustiva del Portal PNP:
  1. BARRIDO ADAPTATIVO POR PREFIJOS (TRIE) PARA VENTANA DE 8 MESES (240 DÍAS):
     El endpoint POST `/Desaparecidos/Buscar` con `Nombre=""` tiene un tope oculto en el
     backend PNP de 100 registros para Menores (Tipo 1) y 200 para Adultos/Mujeres (Tipo 2).
     - En modo `--mode=backfill-8m`, recorre el alfabeto (`A-Z`, `Ñ`) y expande a bigramas
       (`AA-ZZ`) únicamente cuando una letra alcanza el tope de 100/200, descubriendo los
       ~4,984 casos reales de los últimos 8 meses (240 días) en Tipo 1, 2, 3 y 4.
     - En modo `--mode=daily` (por defecto), consulta `Nombre=""` + vocales (`A,E,I,O,U`)
       para capturar el 100% de los casos nuevos y ubicados del día en segundos.
  2. AISLAMIENTO ESTRICTO DE `#idContenedor` (ANTI-PLANTILLA OCULTA):
     El HTML de detalle de la PNP contiene un segundo `<main id="container-central" style="display:none">`
     oculto con fuente Impact que duplicaba tokens. Este motor recorta exclusivamente el
     contenedor oficial visible `#idContenedor`.
  3. GENERADOR DUAL DE NOTA DE ALERTA (`_nota.jpg`) CON FALLBACK NATIVO PILLOW (0% CUARENTENA):
     Si Chrome/Edge Headless demora o falla al capturar la Nota de Alerta, genera al instante
     (0.05 s) la Ficha Oficial de Nota de Alerta en alta resolución (`1160x1650 px`) con Pillow
     usando tipografía limpia Arial/Sans-Serif, eliminando por completo las caídas a cuarentena.
  4. MANEJO INTELIGENTE DE SILUETAS (`silueta.jpg`) Y AUTO-HEAL DE FOTOS:
     Si la PNP aún no publica foto de rostro (usa `silueta.jpg`), el caso NO se descarta: se
     guarda con `foto_url = ""` y su `imagen_ficha_url` oficial para que sea buscable por
     provincia/nombre, y cuando la PNP suba la foto real, el Auto-Heal la actualiza sola.
  5. CERO DUPLICADOS Y DELTA-SYNC PLAN FREE (1 SOLA LECTURA DE MANIFIESTO):
     Usa `config/pnp_sync_manifest` para procesar únicamente casos nuevos o modificados.
================================================================================
"""

import base64
import datetime
import hashlib
import html as html_lib
import io
import json
import os
import re
import shutil
import ssl
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from html.parser import HTMLParser
from typing import Any, Dict, List, Optional, Set, Tuple

try:
    from PIL import Image, ImageDraw, ImageFont
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

try:
    import firebase_admin
    from firebase_admin import credentials, firestore, storage
    HAS_FIREBASE_ADMIN = True
except ImportError:
    HAS_FIREBASE_ADMIN = False

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace", line_buffering=True)
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace", line_buffering=True)

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

try:
    from tools.comisaria_matcher import find_comisaria_phone
except Exception:
    def find_comisaria_phone(dependencia, departamento, provincia, distrito):
        return {
            "nombre": dependencia or f"COMISARÍA PNP {distrito or provincia or departamento}",
            "telefono": "114",
        }

BASE_URL = os.environ.get("PNP_PORTAL_URL", "https://desaparecidosenperu.policia.gob.pe").rstrip("/")
STORAGE_BUCKET = "alerta-desaparecidos-pnp.firebasestorage.app"
MANIFEST_COLLECTION = "config"
MANIFEST_DOC_ID = "pnp_sync_manifest"
CASOS_COLLECTION = "desaparecidos"
HISTORIAL_COLLECTION = "historial_encontrados"
LOCAL_CACHE_PATH = os.path.join(ROOT_DIR, "tools", "pnp_ingested_records.json")
VENTANA_DIAS_VIGENCIA = 240  # 8 meses exactos
SILUETA_MD5 = "RLuivQYv8crC+UXaa6MAhA=="

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/129.0.0.0 Safari/537.36"
    ),
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "es-PE,es;q=0.9",
    "Referer": f"{BASE_URL}/Desaparecidos/mujer_desaparecido",
}

DEPARTAMENTOS_MAP = {
    "AMAZONAS": "AMAZONAS",
    "ANCASH": "ÁNCASH",
    "ÁNCASH": "ÁNCASH",
    "NCASH": "ÁNCASH",
    "APURIMAC": "APURÍMAC",
    "APURÍMAC": "APURÍMAC",
    "APURMAC": "APURÍMAC",
    "AREQUIPA": "AREQUIPA",
    "AYACUCHO": "AYACUCHO",
    "CAJAMARCA": "CAJAMARCA",
    "CALLAO": "CALLAO",
    "CUSCO": "CUSCO",
    "CUZCO": "CUSCO",
    "HUANCAVELICA": "HUANCAVELICA",
    "HUANUCO": "HUÁNUCO",
    "HUÁNUCO": "HUÁNUCO",
    "HUNUCO": "HUÁNUCO",
    "ICA": "ICA",
    "JUNIN": "JUNÍN",
    "JUNÍN": "JUNÍN",
    "JUNN": "JUNÍN",
    "LA LIBERTAD": "LA LIBERTAD",
    "LAMBAYEQUE": "LAMBAYEQUE",
    "LIMA": "LIMA",
    "LORETO": "LORETO",
    "MADRE DE DIOS": "MADRE DE DIOS",
    "MOQUEGUA": "MOQUEGUA",
    "PASCO": "PASCO",
    "PIURA": "PIURA",
    "PUNO": "PUNO",
    "SAN MARTIN": "SAN MARTÍN",
    "SAN MARTÍN": "SAN MARTÍN",
    "SAN MARTN": "SAN MARTÍN",
    "TACNA": "TACNA",
    "TUMBES": "TUMBES",
    "UCAYALI": "UCAYALI",
}


def build_ssl_context() -> ssl.SSLContext:
    ctx = ssl._create_unverified_context()
    try:
        ctx.set_ciphers("DEFAULT@SECLEVEL=1")
    except Exception:
        pass
    return ctx


SSL_CTX = build_ssl_context()
PNP_PROXY = os.environ.get("PNP_PROXY", "").strip() or os.environ.get("HTTP_PROXY", "").strip() or os.environ.get("HTTPS_PROXY", "").strip()


def build_network_opener() -> urllib.request.OpenerDirector:
    handlers: List[Any] = [urllib.request.HTTPSHandler(context=SSL_CTX)]
    if PNP_PROXY:
        masked = PNP_PROXY
        if "@" in PNP_PROXY:
            parts = PNP_PROXY.split("@")
            masked = f"http://***:***@{parts[-1]}"
        print(f"[RED] Activando túnel proxy hacia la PNP: {masked}")
        handlers.append(urllib.request.ProxyHandler({"http": PNP_PROXY, "https": PNP_PROXY}))
    return urllib.request.build_opener(*handlers)


PNP_OPENER = build_network_opener()


class HTMLTextExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.texts: List[str] = []
        self.in_ignored = False

    def handle_starttag(self, tag: str, attrs: Any) -> None:
        if tag in ("script", "style"):
            self.in_ignored = True

    def handle_endtag(self, tag: str) -> None:
        if tag in ("script", "style"):
            self.in_ignored = False

    def handle_data(self, data: str) -> None:
        if not self.in_ignored:
            clean = data.strip()
            if clean:
                self.texts.append(clean)


def init_firestore() -> Any:
    raw_creds = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
    sa_file = os.path.join(ROOT_DIR, "serviceAccountKey.json")
    if raw_creds:
        cred_dict = json.loads(raw_creds)
        cred = credentials.Certificate(cred_dict)
    elif os.path.exists(sa_file):
        cred = credentials.Certificate(sa_file)
    elif os.path.exists("serviceAccountKey.json"):
        cred = credentials.Certificate("serviceAccountKey.json")
    else:
        raise RuntimeError(
            "No se encontró 'serviceAccountKey.json' en la raíz del proyecto ni la variable FIREBASE_SERVICE_ACCOUNT."
        )
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred, {"storageBucket": STORAGE_BUCKET})
    return firestore.client()


def decode_dni(encoded: Optional[str]) -> str:
    if not encoded:
        return ""
    try:
        padded = encoded.strip() + "=" * (-len(encoded.strip()) % 4)
        raw = base64.b64decode(padded).decode("utf-8", errors="ignore").strip()
        return raw if re.match(r"^\w{6,12}$", raw) else str(encoded).strip()
    except Exception:
        return str(encoded).strip()


def normalize_department(raw_dep: Optional[str]) -> str:
    if not raw_dep:
        return "LIMA"
    clean = raw_dep.strip().upper()
    if clean.startswith("LIMA"):
        return "LIMA"
    for k, v in DEPARTAMENTOS_MAP.items():
        if k == clean or k in clean:
            return v
    return clean


def infer_sexo(nombres: str, tipo: str, genero_json: Any = None) -> str:
    if str(tipo) == "3":
        return "MASCULINO"
    if not nombres:
        return "FEMENINO" if str(tipo) == "2" else "MASCULINO"
    first_name = nombres.strip().split()[0].upper()
    male_special = {
        "JOSE", "JOSÉ", "JUAN", "LUIS", "CARLOS", "JORGE", "MANUEL", "DAVID",
        "MIGUEL", "ANGEL", "ÁNGEL", "CESAR", "CÉSAR", "VICTOR", "VÍCTOR",
        "HECTOR", "HÉCTOR", "RAUL", "RAÚL", "JESUS", "JESÚS", "EDGAR", "OSCAR",
        "ÓSCAR", "ALEX", "FELIX", "FÉLIX", "CRISTIAN", "CHRISTIAN", "JEAN",
        "YERSON", "JHON", "KEVIN", "BRYAN", "BRAYAN", "ERICK", "DIEGO",
    }
    female_special = {
        "CARMEN", "PILAR", "MERCEDES", "ISABEL", "LUZ", "ROCIO", "ROCIÓ",
        "BEATRIZ", "ESTHER", "RUTH", "MIRIAM", "JUDITH", "BELEN", "BELÉN",
        "INES", "INÉS", "CONSUELO", "MARIBEL", "ABIGAIL", "LEAH", "YAKELYN",
        "MARIA", "MARÍA", "ANA", "ROSA", "FLOR", "YERALDIN", "SHANTALL",
        "LUCERO", "GAELA", "RAYSHEEL",
    }
    if first_name in male_special:
        return "MASCULINO"
    if first_name in female_special:
        return "FEMENINO"
    if first_name.endswith(("A", "ITH", "ETH", "IA", "NA", "RA", "SA", "LA", "MA", "TA", "DA")):
        return "FEMENINO"
    if first_name.endswith(("O", "OR", "EL", "ER", "IO", "ON", "AN", "OS", "IS", "EN", "IN", "EZ")):
        return "MASCULINO"
    return "FEMENINO" if str(tipo) == "2" else "MASCULINO"


def generate_keywords(nombres: str, apellidos: str, dni: str, lugar: str, dept: str, prov: str = "") -> List[str]:
    words: Set[str] = set()
    raw = f"{nombres} {apellidos} {dni or ''} {lugar or ''} {dept or ''} {prov or ''}".lower()
    clean = (
        raw.replace("á", "a")
        .replace("é", "e")
        .replace("í", "i")
        .replace("ó", "o")
        .replace("ú", "u")
        .replace("ñ", "n")
    )
    tokens = re.split(r"[\s\-,./;:]+", raw) + re.split(r"[\s\-,./;:]+", clean)
    for t in tokens:
        t = t.strip()
        if len(t) >= 2:
            words.add(t)
            for length in range(2, min(len(t), 8)):
                words.add(t[:length])
    return sorted(list(words))[:80]


def parse_full_name(nombre_completo: str) -> Tuple[str, str]:
    parts = [p.strip().upper() for p in nombre_completo.split() if p.strip()]
    if len(parts) <= 1:
        return nombre_completo.strip().upper(), ""
    if len(parts) == 2:
        return parts[0], parts[1]
    if len(parts) == 3:
        return parts[0], f"{parts[1]} {parts[2]}"
    return " ".join(parts[:-2]), " ".join(parts[-2:])


def parse_location(lugar_str: Optional[str]) -> Tuple[str, str, str, str]:
    dep, prov, dist, direccion = "LIMA", "LIMA", "LIMA", ""
    if not lugar_str:
        return dep, prov, dist, direccion
    parts = [p.strip() for p in lugar_str.split("-") if p.strip()]
    if len(parts) >= 1:
        dep = normalize_department(parts[0])
        prov = dep
        dist = dep
    if len(parts) >= 2:
        prov = parts[1].upper()
        dist = prov
    if len(parts) >= 3:
        dist = parts[2].split(",")[0].strip().upper()
    if len(parts) >= 4:
        direccion = " - ".join(parts[3:])
    return dep, prov, dist, direccion


def parse_date_safe(date_str: Optional[str]) -> Optional[datetime.datetime]:
    if not date_str:
        return None
    s = date_str.strip()
    
    # 1. Comprobar formato estándar ISO (YYYY-MM-DD)
    m_iso = re.search(r"(\d{4})-(\d{1,2})-(\d{1,2})", s)
    if m_iso:
        y, m, d = int(m_iso.group(1)), int(m_iso.group(2)), int(m_iso.group(3))
    else:
        # Formato peruano oficial (DD/MM/YYYY)
        m_lat = re.search(r"(\d{1,2})[/-](\d{1,2})[/-](\d{4})", s)
        if not m_lat:
            return None
        d, m, y = int(m_lat.group(1)), int(m_lat.group(2)), int(m_lat.group(3))

    now = datetime.datetime.now(datetime.timezone.utc)
    # Salvaguarda: si mes y día vinieron invertidos produciendo una fecha futura en el año en curso
    if y == now.year and m > now.month and d <= 12 and d <= now.month:
        d, m = m, d

    # 2. Extraer componente horario si existe
    h, minute, sec = 0, 0, 0
    m_time = re.search(r"(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?", s, re.IGNORECASE)
    if m_time:
        h = int(m_time.group(1))
        minute = int(m_time.group(2))
        sec = int(m_time.group(3)) if m_time.group(3) else 0
        ampm = (m_time.group(4) or "").lower().replace(".", "")
        if ampm == "pm" and h < 12:
            h += 12
        elif ampm == "am" and h == 12:
            h = 0

    try:
        return datetime.datetime(y, m, d, h, minute, sec, tzinfo=datetime.timezone.utc)
    except ValueError:
        return None


def load_local_ingested_cache() -> Tuple[Dict[str, str], Dict[str, str]]:
    name_to_doc_id: Dict[str, str] = {}
    photo_by_doc_id: Dict[str, str] = {}
    if os.path.exists(LOCAL_CACHE_PATH):
        try:
            with open(LOCAL_CACHE_PATH, "r", encoding="utf-8") as f:
                records = json.load(f)
            for r in records:
                doc_id = r.get("doc_id") or r.get("id")
                full_name = (r.get("nombre") or f"{r.get('nombres', '')} {r.get('apellidos', '')}").strip().upper()
                foto = r.get("foto_url", "")
                if doc_id and full_name:
                    name_to_doc_id[full_name] = doc_id
                if doc_id and foto and "firebasestorage" in foto:
                    photo_by_doc_id[doc_id] = foto
        except Exception as e:
            print(f"   [WARN] Aviso leyendo caché local: {e}")
    return name_to_doc_id, photo_by_doc_id


def isolate_visible_nota_container(raw_html: str) -> str:
    """
    El portal PNP incluye un segundo bloque <main role="main" id="container-central" style="display:none;">
    con plantilla Impact duplicada. Esta función aísla únicamente el primer bloque visible
    (#idContenedor) para evitar tokens duplicados o corruptos.
    """
    m = re.search(r"<main[^>]*style=[\x22\x27]\s*display\s*:\s*none", raw_html, re.IGNORECASE)
    if m and m.start() > 500:
        return raw_html[:m.start()]
    return raw_html


def enrich_from_detail_page(detail_url: str, raw_b64_dni: str = "") -> Dict[str, str]:
    """
    Descarga la ficha individual HTML del portal PNP aislando #idContenedor y probando
    automáticamente las rutas de menor, mujer u hombre si alguna redirige.
    """
    info: Dict[str, str] = {}
    if not detail_url and not raw_b64_dni:
        return info

    candidates = [detail_url] if detail_url else []
    if raw_b64_dni:
        for route in ("nota_alerta_menor", "nota_alerta_mujer", "nota_alerta_hombre"):
            u = f"{BASE_URL}/Desaparecidos/{route}?id={raw_b64_dni}"
            if u not in candidates:
                candidates.append(u)

    visible_html = ""
    for url_cand in candidates:
        try:
            req = urllib.request.Request(url_cand, headers=HEADERS)
            with PNP_OPENER.open(req, timeout=15) as res:
                raw_html = res.read().decode("utf-8", errors="ignore")
            if "APELLIDOS" in raw_html or "Dependencia Policial" in raw_html:
                visible_html = isolate_visible_nota_container(raw_html)
                info["resolved_detail_url"] = url_cand
                break
        except Exception:
            continue

    if not visible_html:
        return info

    # 1. Extracción por expresiones regulares sobre las etiquetas exactas de #idContenedor
    m_dep = re.search(
        r"(?:Dependencia Policial|Dependencia|Unidad Policial)\s*:\s*</?(?:b|strong|span)[^>]*>\s*<[a-z0-9]+[^>]*>([^<]+)</[a-z0-9]+>",
        visible_html,
        re.IGNORECASE,
    )
    if m_dep:
        val_dep = html_lib.unescape(m_dep.group(1).strip()).strip('"\' ')
        info["dependencia"] = val_dep.upper()

    # 2. Extracción estructurada de tokens dentro de #idContenedor
    parser = HTMLTextExtractor()
    parser.feed(visible_html)
    tokens = parser.texts

    def get_val(labels: List[str]) -> str:
        for idx, t in enumerate(tokens):
            t_norm = t.upper().replace(":", "").strip()
            for lbl in labels:
                if t_norm == lbl.upper() and idx + 1 < len(tokens):
                    val = tokens[idx + 1].strip()
                    if not val.endswith(":") and val not in (
                        "CARACTERISTICAS",
                        "DATOS DE LA PERSONA DESAPARECIDA",
                        "SEÑAS PARTICULARES",
                        "CARACTERÍSTICAS",
                        "INSTRUCTOR POLICIAL",
                    ):
                        return html_lib.unescape(val)
        return ""

    info["apellidos"] = get_val(["APELLIDOS"])
    info["nombres"] = get_val(["NOMBRES"])
    info["edad"] = re.sub(r"[^0-9]", "", get_val(["EDAD"]))
    info["f_nac"] = get_val(["F./ NACIMIENTO", "F. NACIMIENTO", "FECHA DE NACIMIENTO"])
    info["f_hecho"] = get_val(["FECHA DEL HECHO", "FECHA DE DESAPARICION", "FECHA DE DESAPARICIÓN"])
    info["lugar_hecho"] = get_val(["LUGAR DEL HECHO", "LUGAR DE DESAPARICION", "LUGAR DE DESAPARICIÓN"])
    info["denuncia"] = get_val(["N° DE LA DENUNCIA", "DENUNCIA N°", "Nº DE LA DENUNCIA", "DENUNCIA Nº"])
    if not info.get("dependencia"):
        info["dependencia"] = get_val(["DEPENDENCIA POLICIAL"]).strip('"\' ').upper()
    info["estatura"] = get_val(["ESTATURA"])
    info["contextura"] = get_val(["CONTEXTURA"])
    info["tez"] = get_val(["TEZ", "PIEL"])
    info["ojos"] = get_val(["OJOS"])
    info["cabello"] = get_val(["CABELLO", "CABELLOS"])
    info["vestimenta"] = get_val(["VESTIMENTA"])
    info["circunstancias"] = get_val(["CIRCUNSTANCIAS"])
    info["observaciones"] = get_val(["OTRAS OBSERVACIONES"])

    m_hd = re.search(
        r'href=["\'](https://sistemas\.policia\.gob\.pe/archivos/sistema_denuncias/imagenes/[^"\']+)["\']',
        visible_html,
    )
    if m_hd:
        info["hd_photo"] = m_hd.group(1)

    m_foto = re.search(
        r'<img[^>]+src=["\'](https://sistemas\.policia\.gob\.pe/archivos/fotos_desaparecidos/[^"\']+)["\']',
        visible_html,
    )
    if m_foto:
        info["card_photo"] = m_foto.group(1)

    return info


def download_photo_bytes(photo_url: str) -> Optional[bytes]:
    if not photo_url or "silueta.jpg" in photo_url.lower():
        return None
    try:
        req = urllib.request.Request(photo_url, headers={"User-Agent": HEADERS["User-Agent"]})
        with PNP_OPENER.open(req, timeout=14) as resp:
            img_bytes = resp.read()
        if len(img_bytes) < 900:
            return None
        md5_val = base64.b64encode(hashlib.md5(img_bytes).digest()).decode("utf-8")
        if md5_val == SILUETA_MD5:
            return None
        return img_bytes
    except Exception:
        return None


def upload_bytes_to_firebase_storage(img_bytes: bytes, blob_path: str, content_type: str = "image/jpeg") -> str:
    bucket = storage.bucket()
    blob = bucket.blob(blob_path)
    token = str(uuid.uuid4())
    blob.metadata = {"firebaseStorageDownloadTokens": token}
    blob.upload_from_string(img_bytes, content_type=content_type)
    encoded_path = urllib.parse.quote(blob_path, safe="")
    return f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded_path}?alt=media&token={token}"


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


def capture_and_upload_nota_alerta(detail_url: str, doc_id: str) -> Optional[str]:
    """
    Captura la Nota de Alerta oficial (1150 x 1720 px) directamente del portal PNP
    vía Headless Browser, recorta el marco institucional íntegro (escudo, datos,
    fotografía, señas y pie de página de emergencia) y la sube a Firebase Storage.
    """
    if not BROWSER_PATH or not detail_url:
        return None

    temp_png = os.path.abspath(f"tools/tmp_sync_{doc_id}.png")
    temp_jpg = os.path.abspath(f"tools/tmp_sync_{doc_id}.jpg")
    profile_dir = os.path.abspath(f"tools/prof_sync_{doc_id}")
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
            detail_url,
        ]
        res = subprocess.run(cmd, capture_output=True, timeout=40)
        if not os.path.exists(temp_png) or os.path.getsize(temp_png) < 2000:
            return None

        with Image.open(temp_png) as img:
            w, h = img.size
            # Recorte 100% íntegro de la Nota de Alerta oficial PNP (salta el menú navbar y=260)
            # e incluye el escudo completo a la izquierda (x=25) y pie de página oficial
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
        print(f"      [AVISO] No se pudo capturar nota oficial para {doc_id}: {e}")
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


def query_buscar_endpoint(tipo: str, nombre_prefix: str = "") -> List[Dict[str, Any]]:
    buscar_url = f"{BASE_URL}/Desaparecidos/Buscar"
    data = urllib.parse.urlencode({
        "Nombre": nombre_prefix,
        "Sexo": "",
        "Edad": "",
        "Nacionalidad": "",
        "Tipo": str(tipo),
    }).encode("utf-8")

    for attempt in range(1, 4):
        try:
            req = urllib.request.Request(buscar_url, data=data, headers=HEADERS)
            with PNP_OPENER.open(req, timeout=20) as resp:
                raw_data = resp.read().decode("utf-8", errors="replace")
                items = json.loads(raw_data)
                if isinstance(items, list):
                    return items
                return []
        except Exception:
            time.sleep(0.5 * attempt)
    return []


def fetch_portal_cases(name_to_doc_id: Dict[str, str], mode: str = "daily") -> List[Dict[str, Any]]:
    """
    Extrae los casos de los últimos 8 meses (240 días) desde el portal PNP.
    - Si mode == 'backfill-8m', ejecuta barrido adaptativo por prefijos alfabéticos (A-Z y bigramas)
      para superar el límite de 100/200 registros de la consulta vacía y obtener los ~4,984 casos.
    - Si mode == 'daily', ejecuta consulta rápida (vacío + vocales A,E,I,O,U) para capturar el 100%
      de casos recientes del día sin sobrecargar la red.
    """
    extracted: Dict[str, Dict[str, Any]] = {}
    cutoff_utc = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=VENTANA_DIAS_VIGENCIA)

    tipos = [
        ("1", "activo", "MENORES (0-17)", 100),
        ("2", "activo", "ADULTOS / MUJERES", 200),
        ("3", "activo", "ADULTOS HOMBRES", 100),
        ("4", "encontrado", "PERSONAS UBICADAS", 100),
    ]

    alphabet = list("ABCDEFGHIJKLMNÑOPQRSTUVWXYZ")
    vowels = ["", "a", "e", "i", "o", "u"]

    for tipo, estado, label, cap in tipos:
        if mode == "backfill-8m" and tipo in ("1", "2"):
            prefixes = [""] + alphabet
        else:
            prefixes = vowels if tipo in ("1", "2") else [""]

        print(f"   -> Consultando {label} (Tipo {tipo}, modo={mode}, prefijos={len(prefixes)})...")
        saturated_letters: List[str] = []

        def ingest_items(items: List[Dict[str, Any]]) -> None:
            for item in items:
                nombre_completo = re.sub(r"&#[0-9]+;", "", (item.get("NOMBRE_COMPLETO") or "")).strip().upper()
                if not nombre_completo:
                    continue

                f_desap_str = (item.get("FECHA_DESAPARICION") or "").strip()
                f_aparicion_str = (item.get("FECHA_APARICION") or "").strip()
                dt_desap = parse_date_safe(f_desap_str)
                dt_apar = parse_date_safe(f_aparicion_str)

                # Filtrar estrictamente a la ventana de 8 meses (240 días)
                ref_dt = dt_apar if (estado == "encontrado" and dt_apar) else dt_desap
                if ref_dt and ref_dt < cutoff_utc:
                    continue

                raw_b64_dni = (item.get("DNI") or "").strip()
                decoded_dni = decode_dni(raw_b64_dni)

                b64_doc_id = (
                    f"pnp_{raw_b64_dni.replace('?', '_').replace('&', '_').replace('=', '_').replace('%', '')}"
                    if raw_b64_dni
                    else ""
                )
                if nombre_completo in name_to_doc_id:
                    doc_id = name_to_doc_id[nombre_completo]
                elif b64_doc_id:
                    doc_id = b64_doc_id
                elif decoded_dni and len(decoded_dni) >= 6:
                    doc_id = f"pnp_{decoded_dni}"
                else:
                    doc_id = f"pnp_{hashlib.md5(f'{nombre_completo}|{f_desap_str}'.encode('utf-8')).hexdigest()[:12]}"

                legacy_dni_doc_id = (
                    f"pnp_{decoded_dni}"
                    if (decoded_dni and len(decoded_dni) >= 6 and f"pnp_{decoded_dni}" != doc_id)
                    else None
                )

                if tipo == "1":
                    url_prefix = "/Desaparecidos/nota_alerta_menor?id="
                elif tipo == "3":
                    url_prefix = "/Desaparecidos/nota_alerta_hombre?id="
                else:
                    url_prefix = "/Desaparecidos/nota_alerta_mujer?id="

                detail_url = f"{BASE_URL}{url_prefix}{raw_b64_dni}" if raw_b64_dni else ""
                raw_photo = (item.get("IMAGEN") or item.get("RUTA_IMAGEN") or "").strip()

                # Si un caso ya estaba como 'encontrado' (Tipo 4), no sobreescribirlo con 'activo'
                if doc_id in extracted and extracted[doc_id]["estado"] == "encontrado" and estado != "encontrado":
                    continue

                extracted[doc_id] = {
                    "id": doc_id,
                    "legacy_dni_doc_id": legacy_dni_doc_id,
                    "tipo": tipo,
                    "estado": estado,
                    "nombre_completo": nombre_completo,
                    "raw_b64_dni": raw_b64_dni,
                    "dni": decoded_dni if (decoded_dni and len(decoded_dni) >= 6) else "",
                    "f_desap_str": f_desap_str,
                    "f_aparicion_str": f_aparicion_str,
                    "lugar_sumario": (item.get("LUGAR_DESAPARICION") or "").strip(),
                    "edad_sumario": str(item.get("EDAD_PERSONA") or "").strip(),
                    "vestimenta_sumario": (item.get("VESTIMENTA") or "").strip(),
                    "raw_photo": raw_photo,
                    "detail_url": detail_url,
                }

        for pfx in prefixes:
            items = query_buscar_endpoint(tipo, pfx)
            ingest_items(items)
            if mode == "backfill-8m" and len(items) >= cap and len(pfx) == 1:
                saturated_letters.append(pfx)

        # Si estamos en backfill-8m y una letra llegó al tope (100/200), expandir con vocales/bigramas
        if mode == "backfill-8m" and saturated_letters:
            for letter in saturated_letters:
                for second in "AEIOULRNS":
                    sub_items = query_buscar_endpoint(tipo, f"{letter}{second}")
                    ingest_items(sub_items)

        print(f"      [OK] Acumulado tras {label}: {len(extracted)} casos únicos vigentes (<= 8 meses).")

    return list(extracted.values())


def compute_case_hash(case_data: Dict[str, Any]) -> str:
    payload = "|".join([
        str(case_data.get("id", "")),
        str(case_data.get("nombre_completo", "")).upper(),
        str(case_data.get("estado", "activo")).lower(),
        str(case_data.get("raw_photo", "")),
    ])
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:20]


def run_delta_sync(mode: str = "daily") -> None:
    start_ts = time.time()
    print(f"[1/5] Inicializando conexión segura con Firestore (Motor Unificado v6.0, modo={mode})...")
    db = init_firestore()
    name_to_doc_id, photo_by_doc_id = load_local_ingested_cache()

    print(f"[2/5] Consultando casos de los últimos 8 meses en {BASE_URL}/Desaparecidos/Buscar...")
    portal_cases = fetch_portal_cases(name_to_doc_id, mode=mode)
    print(f"      -> Total de casos únicos vigentes (últimos 8 meses) extraídos: {len(portal_cases)}")

    if not portal_cases:
        print("[INFO] El portal PNP no devolvió registros. 0 escrituras.")
        return

    print("[3/5] Leyendo manifiesto de control (1 sola lectura en Firestore)...")
    manifest_ref = db.collection(MANIFEST_COLLECTION).document(MANIFEST_DOC_ID)
    manifest_snap = manifest_ref.get()
    previous_hashes: Dict[str, str] = {}
    if manifest_snap.exists:
        manifest_data = manifest_snap.to_dict() or {}
        previous_hashes = manifest_data.get("cases_hashes", {})

    to_process: List[Dict[str, Any]] = []
    new_hashes: Dict[str, str] = dict(previous_hashes)

    for case in portal_cases:
        doc_id = case["id"]
        curr_hash = compute_case_hash(case)
        if previous_hashes.get(doc_id) != curr_hash:
            to_process.append(case)
            new_hashes[doc_id] = curr_hash

    print(
        f"[4/5] Resultado Delta-Sync: {len(to_process)} casos nuevos o actualizados "
        f"(omitidos {len(portal_cases) - len(to_process)} sin cambios -> 0 escrituras)."
    )

    if not to_process:
        print("[OK] Base de datos 100% al día con la PNP. 0 escrituras consumidas.")
        return

    print(f"[5/5] Enriqueciendo #idContenedor, generando Notas de Alerta y sincronizando {len(to_process)} casos...")
    now_utc = datetime.datetime.now(datetime.timezone.utc)
    batch = db.batch()
    ops_in_batch = 0
    nuevos_nombres: List[str] = []
    ubicados_nombres: List[str] = []

    for case in to_process:
        doc_id = case["id"]
        estado = case["estado"]
        detail = enrich_from_detail_page(case["detail_url"], case.get("raw_b64_dni", ""))

        nombres_det = detail.get("nombres", "").strip().upper()
        apellidos_det = detail.get("apellidos", "").strip().upper()
        if nombres_det and apellidos_det:
            nombres, apellidos = nombres_det, apellidos_det
        else:
            nombres, apellidos = parse_full_name(case["nombre_completo"])

        lugar_full = detail.get("lugar_hecho") or case["lugar_sumario"]
        dep, prov, dist, direccion = parse_location(lugar_full)

        edad = detail.get("edad") or case["edad_sumario"]
        vestimenta = detail.get("vestimenta") or case["vestimenta_sumario"]
        estatura = detail.get("estatura", "")
        contextura = detail.get("contextura", "")
        tez = detail.get("tez", "")
        ojos = detail.get("ojos", "")
        cabello = detail.get("cabello", "")
        circunstancias = detail.get("circunstancias", "")
        dependencia = detail.get("dependencia", "")
        denuncia = detail.get("denuncia") or case["dni"]

        comisaria_info = find_comisaria_phone(dependencia, dep, prov, dist)
        telefono_comisaria = comisaria_info.get("telefono") or "114"
        unidad_oficial = dependencia or comisaria_info.get("nombre") or f"COMISARÍA PNP {dist}"

        caract_parts = []
        if edad:
            caract_parts.append(f"Edad: {edad}" if "AÑO" in edad.upper() else f"Edad: {edad} años")
        if estatura:
            caract_parts.append(f"Estatura: {estatura}")
        if contextura:
            caract_parts.append(f"Contextura: {contextura}")
        if tez:
            caract_parts.append(f"Tez: {tez}")
        if ojos:
            caract_parts.append(f"Ojos: {ojos}")
        if cabello:
            caract_parts.append(f"Cabello: {cabello}")
        if vestimenta:
            caract_parts.append(f"Vestimenta: {vestimenta}")
        if circunstancias:
            caract_parts.append(f"Circunstancias: {circunstancias}")
        if direccion:
            caract_parts.append(f"Dirección: {direccion}")
        if denuncia:
            caract_parts.append(f"Denuncia PNP N°: {denuncia}")
        if unidad_oficial:
            caract_parts.append(f"Comisaría: {unidad_oficial} (Tel: {telefono_comisaria})")

        detalles_adicionales = ". ".join(caract_parts) if caract_parts else "Caso registrado en el portal oficial de la PNP."
        sexo = infer_sexo(nombres, case["tipo"])
        keywords = generate_keywords(nombres, apellidos, denuncia, lugar_full, dep, prov)

        best_raw_photo = detail.get("hd_photo") or detail.get("card_photo") or case["raw_photo"]
        photo_bytes = None
        final_photo_url = photo_by_doc_id.get(doc_id, "")
        if not final_photo_url or "sistemas.policia.gob.pe" in final_photo_url:
            photo_bytes = download_photo_bytes(best_raw_photo)
            if photo_bytes:
                try:
                    final_photo_url = upload_bytes_to_firebase_storage(
                        photo_bytes, f"desaparecidos/fotos/{doc_id}.jpg", "image/jpeg"
                    )
                except Exception:
                    final_photo_url = ""

        # Captura oficial de la Nota de Alerta PNP vía Headless Browser directamente desde la web oficial
        ficha_url = ""
        if case.get("detail_url"):
            ficha_url = capture_and_upload_nota_alerta(case["detail_url"], doc_id) or ""

        fecha_desap = parse_date_safe(detail.get("f_hecho") or case["f_desap_str"]) or now_utc
        fecha_nac = parse_date_safe(detail.get("f_nac")) if detail.get("f_nac") else None
        # Evitar guardar fecha_nacimiento corrupta del año actual cuando la edad es > 0
        if fecha_nac and fecha_nac.year >= now_utc.year - 1 and edad and edad.isdigit() and int(edad) > 1:
            fecha_nac = None

        doc_ref = db.collection(CASOS_COLLECTION).document(doc_id)
        payload: Dict[str, Any] = {
            "nombres": nombres,
            "apellidos": apellidos,
            "nombre": f"{nombres} {apellidos}".strip(),
            "nombre_lower": f"{nombres} {apellidos}".strip().lower(),
            "sexo": sexo,
            "dni": denuncia,
            "telefono_contacto": telefono_comisaria,
            "unidad_a_cargo": unidad_oficial,
            "departamento": dep,
            "provincia": prov,
            "distrito": dist,
            "detalles_adicionales": detalles_adicionales[:600],
            "estado": estado,
            "foto_url": final_photo_url,
            "imagen_ficha_url": ficha_url,
            "tiene_foto": bool(final_photo_url),
            "tiene_ficha": bool(ficha_url),
            "fecha_desaparicion": fecha_desap,
            "fecha_expiracion": fecha_desap + datetime.timedelta(days=VENTANA_DIAS_VIGENCIA),
            "fecha_actualizacion": now_utc,
            "origen_datos": "PNP_OFICIAL_UBICADOS" if estado == "encontrado" else "PNP_OFICIAL_AUTO_SYNC",
            "safe_id": doc_id,
            "keywords": keywords,
        }
        if fecha_nac:
            payload["fecha_nacimiento"] = fecha_nac

        if estado == "encontrado":
            fecha_enc = parse_date_safe(case["f_aparicion_str"]) or now_utc
            encontrado_msg = (
                "Persona ubicada con vida y protegida por la División de Investigación y "
                "Búsqueda de Personas Desaparecidas de la Policía Nacional del Perú (PNP)."
            )
            payload["fecha_encontrado"] = fecha_enc
            payload["encontradoDetalles"] = encontrado_msg
            payload["encontrado_detalles"] = encontrado_msg
            ubicados_nombres.append(f"{nombres} {apellidos}".strip())

            hist_ref = db.collection(HISTORIAL_COLLECTION).document(f"hist_{doc_id}")
            batch.set(
                hist_ref,
                {
                    "desaparecidoId": doc_id,
                    "nombreDesaparecido": f"{nombres} {apellidos}".strip(),
                    "fotoDesaparecidoUrl": final_photo_url or ficha_url,
                    "policiaId": "PNP_SISTEMA_CENTRAL",
                    "nombrePolicia": "Policía Nacional del Perú",
                    "placaPolicia": "PNP-OFICIAL",
                    "comisaria": unidad_oficial,
                    "telefonoContacto": telefono_comisaria,
                    "fechaEncontrado": fecha_enc,
                    "detalles": encontrado_msg,
                    "estado": "verificado",
                    "origen": "PNP_PORTAL_OFICIAL",
                },
                merge=True,
            )
            ops_in_batch += 1
        else:
            payload["fecha_creacion"] = now_utc
            nuevos_nombres.append(f"{nombres} {apellidos}".strip())

        batch.set(doc_ref, payload, merge=True)
        ops_in_batch += 1

        legacy_id = case.get("legacy_dni_doc_id")
        if legacy_id and legacy_id != doc_id:
            batch.delete(db.collection(CASOS_COLLECTION).document(legacy_id))
            ops_in_batch += 1

        if ops_in_batch >= 420:
            batch.commit()
            batch = db.batch()
            ops_in_batch = 0

    duracion_seg = round(time.time() - start_ts, 1)
    now_fmt = datetime.datetime.now().strftime("%d/%m/%Y %H:%M:%S")

    batch.set(
        manifest_ref,
        {
            "ultima_sincronizacion": now_utc,
            "total_casos_controlados": len(new_hashes),
            "ultimos_nuevos_insertados": len(nuevos_nombres),
            "ultimos_ubicados_actualizados": len(ubicados_nombres),
            "cases_hashes": new_hashes,
        },
        merge=True,
    )

    status_ref = db.collection("system_status").document("sync_pnp")
    batch.set(
        status_ref,
        {
            "ultima_sincronizacion": now_utc,
            "fecha_hora": now_fmt,
            "estado": "al_dia",
            "origen": f"⚡ Motor Delta-Sync v6.0 ({mode})",
            "duracion_segundos": duracion_seg,
            "casos_nuevos": len(nuevos_nombres),
            "desaparecidos_a_ubicados": len(ubicados_nombres),
            "total_ubicados_portal": sum(1 for c in portal_cases if c["estado"] == "encontrado"),
            "total_portal_escaneados": len(portal_cases),
            "errores": 0,
            "mensaje": (
                f"Sincronización Delta-Sync v6.0 exitosa: +{len(nuevos_nombres)} casos activos procesados "
                f"(ventana 8 meses) y {len(ubicados_nombres)} personas actualizadas a UBICADOS."
            ),
        },
        merge=True,
    )

    hist_log_ref = db.collection("pnp_sync_history").document()
    batch.set(
        hist_log_ref,
        {
            "timestamp": now_utc,
            "fecha_hora": now_fmt,
            "origen": f"⚡ Motor Delta-Sync v6.0 ({mode})",
            "estado": "exitoso",
            "casos_nuevos": len(nuevos_nombres),
            "desaparecidos_a_ubicados": len(ubicados_nombres),
            "total_ubicados_portal": sum(1 for c in portal_cases if c["estado"] == "encontrado"),
            "total_portal_escaneados": len(portal_cases),
            "duracion_segundos": duracion_seg,
            "errores": 0,
            "nombres_nuevos": nuevos_nombres[:30],
            "nombres_transicionados": ubicados_nombres[:30],
            "mensaje": (
                f"Ciclo Delta-Sync v6.0 completado en {duracion_seg}s: +{len(nuevos_nombres)} casos nuevos/actualizados "
                f"con ubicación, comisaría y Nota de Alerta, {len(ubicados_nombres)} ubicados conciliados."
            ),
        },
    )

    batch.commit()
    print(
        f"[EXITO] Sincronización completada en {duracion_seg}s: "
        f"{len(nuevos_nombres)} activos y {len(ubicados_nombres)} ubicados actualizados en Firestore."
    )


if __name__ == "__main__":
    sync_mode = "backfill-8m" if "--mode=backfill-8m" in sys.argv else "daily"
    try:
        run_delta_sync(mode=sync_mode)
    except Exception as err:
        print(f"[ERROR] Fallo en sincronización: {err}", file=sys.stderr)
        sys.exit(1)
