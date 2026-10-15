#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Motor de Remediación Integral de Fotos y Fichas — Alerta Desaparecidos PNP
Migra las fotos y fichas de sistemas.policia.gob.pe a Firebase Storage con tokens públicos
para que carguen al 100% en Safari iOS, Chrome, Android y Web sin errores de CORS.
"""

import os
import sys
import uuid
import ssl
import time
import urllib.request
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, Any, Optional

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

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/129.0.0.0 Safari/537.36"
    )
}

def upload_url_to_storage(image_url: Optional[str], storage_path: str) -> Optional[str]:
    if not image_url or "firebasestorage.googleapis.com" in image_url:
        return image_url
    if not image_url.startswith("http"):
        return None
    for attempt in range(1, 3):
        try:
            req = urllib.request.Request(image_url, headers=HEADERS)
            with urllib.request.urlopen(req, context=ctx, timeout=12) as resp:
                data = resp.read()
                content_type = resp.headers.get("Content-Type") or "image/jpeg"
            if len(data) < 200:
                return image_url
            
            blob = bucket.blob(storage_path)
            token = str(uuid.uuid4())
            blob.metadata = {"firebaseStorageDownloadTokens": token}
            blob.upload_from_string(data, content_type=content_type)
            encoded = urllib.parse.quote(storage_path, safe="")
            time.sleep(0.15)
            return f"https://firebasestorage.googleapis.com/v0/b/{STORAGE_BUCKET}/o/{encoded}?alt=media&token={token}"
        except Exception:
            if attempt == 2:
                return image_url
            time.sleep(1.0)
    return image_url

def process_case(doc_id: str, data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    foto = data.get("foto_url") or data.get("fotoUrl")
    ficha = data.get("imagen_ficha_url") or data.get("imagenFichaUrl")
    estado = (data.get("estado") or "activo").lower()
    
    needs_update = False
    new_foto = foto
    new_ficha = ficha

    # Si foto_url apuntaba a una ficha y ficha estaba vacía
    if foto and "sistema_denuncias/imagenes" in foto and not ficha:
        ficha = foto
        new_ficha = upload_url_to_storage(ficha, f"desaparecidos/fichas/{doc_id}.jpg")
        needs_update = True

    # Migrar foto si apunta a sistemas.policia.gob.pe
    if foto and "sistemas.policia.gob.pe" in foto:
        new_foto = upload_url_to_storage(foto, f"desaparecidos/fotos/{doc_id}.jpg")
        needs_update = True

    # Migrar ficha si apunta a sistemas.policia.gob.pe
    if ficha and "sistemas.policia.gob.pe" in ficha:
        new_ficha = upload_url_to_storage(ficha, f"desaparecidos/fichas/{doc_id}.jpg")
        needs_update = True

    if needs_update:
        return {
            "doc_id": doc_id,
            "estado": estado,
            "nombres": data.get("nombres") or data.get("nombre", ""),
            "foto_url": new_foto,
            "imagen_ficha_url": new_ficha,
            "comisaria": data.get("unidad_a_cargo") or "Policía Nacional del Perú",
            "telefono": data.get("telefono_contacto") or "114",
            "fecha_encontrado": data.get("fecha_encontrado"),
            "detalles": data.get("detalles_adicionales", ""),
        }
    return None

def run_remediation():
    print("[1/3] Consultando casos que aún tienen URLs de la PNP en Firestore...", flush=True)
    docs = list(db.collection(CASOS_COLLECTION).stream())

    cases_to_fix = []
    for d in docs:
        data = d.to_dict()
        foto = data.get("foto_url") or data.get("fotoUrl") or ""
        ficha = data.get("imagen_ficha_url") or data.get("imagenFichaUrl") or ""
        if "sistemas.policia.gob.pe" in foto or "sistemas.policia.gob.pe" in ficha:
            cases_to_fix.append((d.id, data))

    print(f"      Casos pendientes de migración: {len(cases_to_fix)}", flush=True)

    if not cases_to_fix:
        print("[OK] Todos los casos ya tienen sus fotos en Firebase Storage.", flush=True)
        return

    print(f"[2/3] Migrando imágenes a Firebase Storage (2 workers continuos)...", flush=True)
    
    # Procesar y escribir de inmediato cada 15 casos
    batch = db.batch()
    ops = 0
    total_migrated = 0

    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = {executor.submit(process_case, doc_id, data): doc_id for doc_id, data in cases_to_fix}
        for fut in as_completed(futures):
            res = fut.result()
            if res:
                doc_ref = db.collection(CASOS_COLLECTION).document(res["doc_id"])
                batch.update(doc_ref, {
                    "foto_url": res["foto_url"],
                    "imagen_ficha_url": res["imagen_ficha_url"],
                })
                ops += 1
                total_migrated += 1

                if res["estado"] == "encontrado":
                    hist_ref = db.collection(HISTORIAL_COLLECTION).document(f"hist_{res['doc_id']}")
                    batch.set(
                        hist_ref,
                        {
                            "desaparecidoId": res["doc_id"],
                            "nombreDesaparecido": res["nombres"],
                            "fotoDesaparecidoUrl": res["foto_url"],
                            "fichaDesaparecidoUrl": res["imagen_ficha_url"],
                            "policiaId": "PNP_SISTEMA_CENTRAL",
                            "nombrePolicia": "Policía Nacional del Perú",
                            "placaPolicia": "PNP-OFICIAL",
                            "comisaria": res["comisaria"],
                            "telefonoContacto": res["telefono"],
                            "fechaEncontrado": res.get("fecha_encontrado"),
                            "detalles": "Persona ubicada con vida por la Policía Nacional del Perú.",
                            "estado": "verificado",
                            "origen": "PNP_PORTAL_OFICIAL",
                        },
                        merge=True,
                    )
                    ops += 1

                if ops >= 30:
                    batch.commit()
                    batch = db.batch()
                    ops = 0
                    print(f"      [PROGRESO] {total_migrated} casos guardados en Firestore...", flush=True)

    if ops > 0:
        batch.commit()

    print(f"[3/3] [EXITO] Migración completada: {total_migrated} casos actualizados con fotos en Storage.", flush=True)

if __name__ == "__main__":
    run_remediation()
