#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Motor de Sincronización Diferencial (Delta-Sync) — Alerta Desaparecidos PNP
Fuente Oficial: https://desaparecidosenperu.policia.gob.pe/
Optimizado para el Plan Gratuito (Spark) de Firebase:
  - Consulta el endpoint oficial de búsqueda JSON (/Desaparecidos/Buscar).
  - 1 sola lectura a Firestore por ejecución (lee 'config/pnp_sync_manifest').
  - 0 escrituras para casos sin cambios (compara hashes SHA-256 en memoria RAM).
  - Escribe en lote (WriteBatch) únicamente los casos nuevos del día o los que cambiaron a 'encontrado'.
  - 0 consumo de Firebase Storage (referencia directa a las URLs oficiales de fotos y notas de alerta).
"""

import datetime
import hashlib
import json
import os
import re
import sys
import base64
import ssl
import urllib.request
import urllib.parse
from typing import Dict, List, Any, Optional, Tuple

import firebase_admin
from firebase_admin import credentials, firestore

BASE_URL = os.environ.get("PNP_PORTAL_URL", "https://desaparecidosenperu.policia.gob.pe").rstrip("/")
MANIFEST_COLLECTION = "config"
MANIFEST_DOC_ID = "pnp_sync_manifest"
CASOS_COLLECTION = "desaparecidos"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/128.0.0.0 Safari/537.36"
    ),
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    "X-Requested-With": "XMLHttpRequest",
    "Referer": f"{BASE_URL}/Desaparecidos/mujer_desaparecido",
}


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


def decode_dni(encoded: Optional[str]) -> str:
    if not encoded:
        return ""
    try:
        raw = base64.b64decode(encoded).decode("utf-8", errors="ignore").strip()
        return raw if re.match(r"^\w{6,12}$", raw) else str(encoded).strip()
    except Exception:
        return str(encoded).strip()


def parse_full_name(nombre_completo: str) -> Tuple[str, str]:
    parts = [p.strip().upper() for p in nombre_completo.split() if p.strip()]
    if len(parts) <= 1:
        return nombre_completo.strip().upper(), ""
    if len(parts) == 2:
        return parts[0], parts[1]
    if len(parts) == 3:
        return parts[0], f"{parts[1]} {parts[2]}"
    return " ".join(parts[:2]), " ".join(parts[2:])


def parse_location(lugar_str: Optional[str]) -> Tuple[str, str, str]:
    dep, prov, dist = "LIMA", "", ""
    if not lugar_str:
        return dep, prov, dist
    # Formato habitual PNP: DEPARTAMENTO-PROVINCIA-DISTRITO- DIRECCIÓN
    parts = [p.strip() for p in lugar_str.split("-") if p.strip()]
    if len(parts) >= 1:
        dep = parts[0].upper()
    if len(parts) >= 2:
        prov = parts[1].upper()
    if len(parts) >= 3:
        dist = parts[2].split(",")[0].strip().upper()
    return dep, prov, dist


def parse_date_safe(date_str: Optional[str]) -> datetime.datetime:
    if not date_str:
        return datetime.datetime.now(datetime.timezone.utc)
    cleaned = (
        date_str.strip()
        .replace("p.m.", "PM")
        .replace("a.m.", "AM")
        .replace("p. m.", "PM")
        .replace("a. m.", "AM")
    )
    for fmt in (
        "%d/%m/%Y %I:%M:%S %p",
        "%d/%m/%Y %H:%M:%S",
        "%d/%m/%Y %H:%M",
        "%d/%m/%Y",
        "%Y-%m-%d",
    ):
        try:
            dt = datetime.datetime.strptime(cleaned, fmt)
            return dt.replace(tzinfo=datetime.timezone.utc)
        except ValueError:
            pass
        try:
            dt = datetime.datetime.strptime(cleaned[:len(fmt)], fmt)
            return dt.replace(tzinfo=datetime.timezone.utc)
        except ValueError:
            pass
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


def extract_cases_from_pnp_portal() -> List[Dict[str, Any]]:
    """
    Consulta el endpoint oficial de la Policía Nacional del Perú:
    https://desaparecidosenperu.policia.gob.pe/Desaparecidos/Buscar
    - Tipo 1: Menores (0 a 17 años)
    - Tipo 2: Adultos y Mujeres (18 a más)
    - Tipo 4: Personas Ubicadas (Casos resueltos / encontrados)
    """
    extracted: Dict[str, Dict[str, Any]] = {}
    buscar_url = f"{BASE_URL}/Desaparecidos/Buscar"
    ctx = ssl._create_unverified_context()

    tipos = [
        ("1", "activo", "MENORES (0-17)"),
        ("2", "activo", "ADULTOS (18+)"),
        ("4", "encontrado", "PERSONAS UBICADAS"),
    ]

    for tipo, estado, label in tipos:
        print(f"   -> Consultando {label} (Tipo {tipo})...")
        data = urllib.parse.urlencode({
            "Nombre": "",
            "Sexo": "",
            "Edad": "",
            "Nacionalidad": "",
            "Tipo": tipo,
        }).encode("utf-8")

        items: List[Dict[str, Any]] = []
        for attempt in range(1, 4):
            try:
                req = urllib.request.Request(buscar_url, data=data, headers=HEADERS)
                with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
                    raw_data = resp.read().decode("utf-8", errors="replace")
                    items = json.loads(raw_data)
                    print(f"      [OK] {len(items)} registros recibidos.")
                    break
            except Exception as e:
                print(f"      [AVISO] Intento {attempt} falló para Tipo {tipo}: {e}")
                if attempt == 3:
                    # Intento con URL HTTP si HTTPS es rechazado por el proxy
                    if buscar_url.startswith("https://"):
                        try:
                            http_url = buscar_url.replace("https://", "http://", 1)
                            req_http = urllib.request.Request(http_url, data=data, headers=HEADERS)
                            with urllib.request.urlopen(req_http, context=ctx, timeout=20) as resp_http:
                                items = json.loads(resp_http.read().decode("utf-8", errors="replace"))
                                print(f"      [OK HTTP] {len(items)} registros recibidos vía HTTP.")
                        except Exception as e_http:
                            print(f"      [WARN] Falló fallback HTTP: {e_http}")

        for item in items:
            nombre_completo = (item.get("NOMBRE_COMPLETO") or "").strip().upper()
            if not nombre_completo:
                continue

            nombres, apellidos = parse_full_name(nombre_completo)
            dep, prov, dist = parse_location(item.get("LUGAR_DESAPARICION", ""))
            dni = decode_dni(item.get("DNI"))
            f_desap_str = item.get("FECHA_DESAPARICION", "")

            if dni and len(dni) >= 8:
                raw_id = dni
            else:
                raw_id = hashlib.md5(f"{nombre_completo}|{f_desap_str}".encode("utf-8")).hexdigest()[:12]

            doc_id = f"pnp_{raw_id}"
            foto_url = (item.get("RUTA_IMAGEN") or "").strip()
            ficha_url = (item.get("IMAGEN") or "").strip()

            detalles_parts = []
            if item.get("EDAD_PERSONA"):
                detalles_parts.append(f"Edad: {item.get('EDAD_PERSONA')} años.")
            if item.get("VESTIMENTA"):
                detalles_parts.append(f"Vestimenta: {item.get('VESTIMENTA')}.")
            if item.get("LUGAR_DESAPARICION"):
                detalles_parts.append(f"Lugar: {item.get('LUGAR_DESAPARICION')}.")

            detalles = " ".join(detalles_parts)[:500]

            fecha_desap = parse_date_safe(f_desap_str)
            fecha_encontrado = (
                parse_date_safe(item.get("FECHA_APARICION")) if estado == "encontrado" else None
            )

            extracted[doc_id] = {
                "id": doc_id,
                "codigo_pnp": raw_id,
                "dni": dni if (dni and len(dni) >= 8) else "",
                "nombres": nombres,
                "apellidos": apellidos,
                "nombre_lower": f"{nombres} {apellidos}".strip().lower(),
                "departamento": dep,
                "provincia": prov,
                "distrito": dist,
                "fecha_desaparicion": fecha_desap,
                "fecha_encontrado": fecha_encontrado,
                "detalles_adicionales": detalles,
                "estado": estado,
                "foto_url": foto_url if foto_url else None,
                "imagen_ficha_url": ficha_url if ficha_url else foto_url,
                "origen": "PORTAL_PNP",
            }

    return list(extracted.values())


def run_delta_sync() -> None:
    print("[1/4] Inicializando conexión segura con Firestore (Plan Free Delta-Sync)...")
    db = init_firestore()

    print(f"[2/4] Extrayendo casos oficiales desde {BASE_URL}/Desaparecidos/Buscar...")
    portal_cases = extract_cases_from_pnp_portal()
    print(f"      -> Total de casos extraídos del portal PNP: {len(portal_cases)}")

    if not portal_cases:
        print("[INFO] El portal PNP no devolvió registros en esta ejecución. Finalizando con 0 escrituras.")
        return

    # 1 SOLA LECTURA A FIRESTORE: Leer el manifiesto de hashes previo
    print("[3/4] Leyendo manifiesto de control (1 sola lectura en Firestore)...")
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

    print(
        f"[4/4] Resultado Delta-Sync: {len(to_upsert)} casos nuevos o modificados "
        f"(se omitieron {len(portal_cases) - len(to_upsert)} casos sin cambios - 0 escrituras)."
    )

    if not to_upsert:
        print("[OK] Base de datos 100% al día con la PNP. 0 escrituras consumidas.")
        return

    # Escrituras en lotes de máximo 450 operaciones (límite Firestore = 500)
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
            "dni": case["dni"],
            "fecha_actualizacion": now_utc,
        }
        if case.get("fecha_encontrado"):
            payload["fecha_encontrado"] = case["fecha_encontrado"]
        if case["estado"] == "activo":
            payload.setdefault("fecha_creacion", now_utc)

        batch.set(doc_ref, payload, merge=True)
        ops_in_batch += 1
        total_written += 1

        if ops_in_batch >= 450:
            batch.commit()
            batch = db.batch()
            ops_in_batch = 0

    # Guardar manifiesto actualizado en el mismo lote final
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
    print(f"[EXITO] Sincronización completada: {total_written} casos actualizados en Firestore.")


if __name__ == "__main__":
    try:
        run_delta_sync()
    except Exception as err:
        print(f"[ERROR] Fallo en sincronización: {err}", file=sys.stderr)
        sys.exit(1)
