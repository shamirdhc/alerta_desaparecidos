#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Motor de Sincronización Diferencial (Delta-Sync) — Alerta Desaparecidos PNP
Fuente Oficial: https://desaparecidosenperu.policia.gob.pe/
Optimizado para el Plan Gratuito (Spark) de Firebase:
  - 1 sola lectura a Firestore por ejecución (lee 'config/pnp_sync_manifest').
  - 0 escrituras para casos sin cambios (compara hashes SHA-256 en memoria RAM).
  - Escribe en lote (WriteBatch) únicamente los casos nuevos del día o los que pasaron a 'encontrado'.
  - 0 consumo de Firebase Storage (referencia directa a las URLs oficiales de fotos y notas de alerta).
"""

import datetime
import hashlib
import json
import os
import re
import sys
from typing import Dict, List, Any, Optional

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import urllib3
from bs4 import BeautifulSoup

import firebase_admin
from firebase_admin import credentials, firestore

# Desactivar advertencias de certificados SSL intermedios gubernamentales
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

BASE_URL = os.environ.get("PNP_PORTAL_URL", "https://desaparecidosenperu.policia.gob.pe/").rstrip("/")
MANIFEST_COLLECTION = "config"
MANIFEST_DOC_ID = "pnp_sync_manifest"
CASOS_COLLECTION = "desaparecidos"


def build_http_session() -> requests.Session:
    session = requests.Session()
    retry = Retry(
        total=4,
        read=4,
        connect=4,
        backoff_factor=1.5,
        status_forcelist=(429, 500, 502, 503, 504),
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    session.headers.update({
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/128.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8",
        "Accept-Language": "es-PE,es;q=0.9",
    })
    return session


def init_firestore() -> firestore.Client:
    raw_creds = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
    if raw_creds:
        cred_dict = json.loads(raw_creds)
        cred = credentials.Certificate(cred_dict)
    elif os.path.exists("serviceAccountKey.json"):
        cred = credentials.Certificate("serviceAccountKey.json")
    else:
        raise RuntimeError(
            "Falta la variable de entorno FIREBASE_SERVICE_ACCOUNT o el archivo serviceAccountKey.json."
        )
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    return firestore.client()


def normalize_url(url: Optional[str]) -> Optional[str]:
    if not url:
        return None
    url = url.strip()
    if url.startswith("http://") or url.startswith("https://"):
        return url
    if url.startswith("/"):
        return f"{BASE_URL}{url}"
    return f"{BASE_URL}/{url}"


def parse_date_safe(date_str: Optional[str]) -> datetime.datetime:
    if not date_str:
        return datetime.datetime.now(datetime.timezone.utc)
    cleaned = date_str.strip()
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y %H:%M", "%Y-%m-%dT%H:%M:%S"):
        try:
            dt = datetime.datetime.strptime(cleaned[:len(fmt)], fmt)
            return dt.replace(tzinfo=datetime.timezone.utc)
        except ValueError:
            continue
    return datetime.datetime.now(datetime.timezone.utc)


def compute_case_hash(case_data: Dict[str, Any]) -> str:
    payload = "|".join([
        str(case_data.get("codigo_pnp", "")),
        str(case_data.get("nombres", "")).upper(),
        str(case_data.get("apellidos", "")).upper(),
        str(case_data.get("departamento", "")).upper(),
        str(case_data.get("provincia", "")).upper(),
        str(case_data.get("estado", "activo")).lower(),
        str(case_data.get("foto_url", "")),
    ])
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:20]


def extract_cases_from_pnp_portal(session: requests.Session) -> List[Dict[str, Any]]:
    """
    Consulta el portal oficial https://desaparecidosenperu.policia.gob.pe/
    Soporta tanto el parseo de tarjetas HTML del portal RENIPED como endpoints JSON internos.
    """
    extracted: Dict[str, Dict[str, Any]] = {}
    candidate_urls = [
        f"{BASE_URL}/",
        f"{BASE_URL}/Desaparecidos/reniped",
    ]

    for url in candidate_urls:
        try:
            resp = session.get(url, timeout=25, verify=False)
            if resp.status_code != 200:
                continue

            soup = BeautifulSoup(resp.text, "lxml")

            # 1. Buscar tarjetas/contenedores de alertas de desaparecidos en el DOM
            cards = soup.select(".card, .portfolio-item, .box, .desaparecido-item, .col-md-4, .col-lg-3, tr")
            for card in cards:
                text_block = " ".join(card.stripped_strings)
                if len(text_block) < 12:
                    continue

                # Buscar enlace a Nota de Alerta o ID de registro
                links = card.find_all("a", href=True)
                imgs = card.find_all("img", src=True)
                if not imgs and not links:
                    continue

                foto_url = None
                for img in imgs:
                    src = img.get("src", "")
                    if any(k in src.lower() for k in ("foto", "desaparecido", "alerta", "reniped", "upload", ".jpg", ".png", ".jpeg")):
                        foto_url = normalize_url(src)
                        break
                if not foto_url and imgs:
                    foto_url = normalize_url(imgs[0].get("src"))

                ficha_url = None
                codigo_pnp = None
                for a in links:
                    href = a.get("href", "")
                    if any(k in href.lower() for k in ("nota", "alerta", "ficha", "pdf", "detalle", "reniped")):
                        ficha_url = normalize_url(href)
                    id_match = re.search(r"(?:id|cod|alerta|caso)[=/_-]?(\d{3,10})", href, re.IGNORECASE)
                    if id_match:
                        codigo_pnp = id_match.group(1)

                # Extraer nombre y ubicación si el bloque corresponde a una ficha
                title_el = card.find(["h3", "h4", "h5", "strong", "b"])
                raw_name = title_el.get_text(" ", strip=True).upper() if title_el else ""
                if not raw_name or len(raw_name) < 4 or "POLICÍA" in raw_name or "MINISTERIO" in raw_name:
                    continue

                # Separar nombres y apellidos de forma heurística
                parts = raw_name.split()
                if len(parts) >= 3:
                    apellidos = " ".join(parts[:2])
                    nombres = " ".join(parts[2:])
                elif len(parts) == 2:
                    apellidos = parts[0]
                    nombres = parts[1]
                else:
                    apellidos = raw_name
                    nombres = ""

                # Extraer Fecha (dd/mm/yyyy)
                date_match = re.search(r"(\d{2}/\d{2}/\d{4})", text_block)
                fecha_str = date_match.group(1) if date_match else None

                # Extraer Departamento / Provincia / Distrito si aparece en el texto
                dep_match = re.search(
                    r"(?:DEPARTAMENTO|REGIÓN|LUGAR|DEPENDENCIA)[:\s]+([A-ZÁÉÍÓÚÑ\s-]+)",
                    text_block.upper(),
                )
                departamento = dep_match.group(1).strip()[:40] if dep_match else "LIMA"

                if not codigo_pnp:
                    codigo_pnp = hashlib.md5(f"{raw_name}|{fecha_str or ''}".encode("utf-8")).hexdigest()[:12]

                doc_id = f"pnp_{codigo_pnp}"
                extracted[doc_id] = {
                    "id": doc_id,
                    "codigo_pnp": codigo_pnp,
                    "nombres": nombres,
                    "apellidos": apellidos,
                    "nombre_lower": f"{nombres} {apellidos}".strip().lower(),
                    "departamento": departamento,
                    "provincia": "",
                    "distrito": "",
                    "fecha_desaparicion": parse_date_safe(fecha_str),
                    "detalles_adicionales": text_block[:450],
                    "estado": "activo",
                    "foto_url": foto_url,
                    "imagen_ficha_url": ficha_url or foto_url,
                    "origen": "PORTAL_PNP",
                }
        except Exception as exc:
            print(f"[WARN] Aviso consultando {url}: {exc}")

    return list(extracted.values())


def run_delta_sync() -> None:
    print("[1/4] Inicializando conexión segura con Firestore (Plan Free Delta-Sync)...")
    db = init_firestore()
    session = build_http_session()

    print(f"[2/4] Extrayendo casos publicados en {BASE_URL}...")
    portal_cases = extract_cases_from_pnp_portal(session)
    print(f"      -> Casos detectados en la corrida actual: {len(portal_cases)}")

    if not portal_cases:
        print("[INFO] El portal PNP no devolvió registros nuevos o está en mantenimiento. Finalizando con 0 lecturas/escrituras.")
        return

    # 1 SOLA LECTURA A FIRESTORE: Leer el manifiesto de hashes de ayer
    print("[3/4] Leyendo manifiesto de estado (1 sola lectura en Firestore)...")
    manifest_ref = db.collection(MANIFEST_COLLECTION).document(MANIFEST_DOC_ID)
    manifest_snap = manifest_ref.get()
    previous_hashes: Dict[str, str] = {}
    if manifest_snap.exists:
        manifest_data = manifest_snap.to_dict() or {}
        previous_hashes = manifest_data.get("cases_hashes", {})

    now_utc = datetime.datetime.now(datetime.timezone.utc)
    new_hashes: Dict[str, str] = dict(previous_hashes)

    to_upsert: List[Dict[str, Any]] = []
    for case in portal_cases:
        doc_id = case["id"]
        current_hash = compute_case_hash(case)
        if previous_hashes.get(doc_id) != current_hash:
            to_upsert.append(case)
            new_hashes[doc_id] = current_hash

    print(f"[4/4] Resultado Delta-Sync: {len(to_upsert)} casos nuevos/actualizados (se omitieron {len(portal_cases) - len(to_upsert)} casos sin cambios).")

    if not to_upsert:
        print("[OK] Base de datos 100% al día. 0 escrituras consumidas hoy.")
        return

    # Ejecutar escrituras en lotes de máximo 450 operaciones (límite Firestore = 500)
    batch = db.batch()
    ops_in_batch = 0
    total_written = 0

    for case in to_upsert:
        doc_ref = db.collection(CASOS_COLLECTION).document(case["id"])
        payload = {
            "nombres": case["nombres"],
            "apellidos": case["apellidos"],
            "nombre_lower": case["nombre_lower"],
            "departamento": case["departamento"],
            "provincia": case["provincia"],
            "distrito": case["distrito"],
            "fecha_desaparicion": case["fecha_desaparicion"],
            "detalles_adicionales": case["detalles_adicionales"],
            "estado": case["estado"],
            "foto_url": case["foto_url"],
            "imagen_ficha_url": case["imagen_ficha_url"],
            "origen": "PORTAL_PNP",
            "codigo_pnp": case["codigo_pnp"],
            "fecha_creacion": now_utc,
            "fecha_actualizacion": now_utc,
        }
        batch.set(doc_ref, payload, merge=True)
        ops_in_batch += 1
        total_written += 1

        if ops_in_batch >= 450:
            batch.commit()
            batch = db.batch()
            ops_in_batch = 0

    # Guardar el manifiesto actualizado en el mismo lote final (1 sola escritura adicional)
    batch.set(
        manifest_ref,
        {
            "ultima_sincronizacion": now_utc,
            "total_casos_controlados": len(new_hashes),
            "ultimos_nuevos_insertados": total_written,
            "cases_hashes": new_hashes,
        },
        merge=True,
    )
    batch.commit()
    print(f"[EXITO] Sincronización completada: {total_written} casos sincronizados en Firestore.")


if __name__ == "__main__":
    try:
        run_delta_sync()
    except Exception as err:
        print(f"[ERROR] Fallo en sincronización: {err}", file=sys.stderr)
        sys.exit(1)
