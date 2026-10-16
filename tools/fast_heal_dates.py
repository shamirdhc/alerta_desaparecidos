#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Motor de Remediación Rápida de Fechas de Desaparición.
Aprovecha fetch_portal_cases para consultar en masa los casos vigentes de la PNP,
parsea las fechas reales con el nuevo motor robusto parse_date_safe y actualiza
las fechas en Firestore.
"""

import os
import sys
from typing import Dict, Any

import firebase_admin
from firebase_admin import credentials, firestore

sys.path.insert(0, os.path.abspath("."))
from scripts.sync_desaparecidos_pnp import fetch_portal_cases, parse_date_safe

STORAGE_BUCKET = "alerta-desaparecidos-pnp.firebasestorage.app"
CASOS_COLLECTION = "desaparecidos"

if not firebase_admin._apps:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred, {"storageBucket": STORAGE_BUCKET})

db = firestore.client()

def main():
    print("[1/3] Consultando casos del portal PNP en masa...")
    cases = fetch_portal_cases({}, mode="daily")
    print(f"      Total de casos vigentes recuperados de la PNP: {len(cases)}")

    portal_date_map: Dict[str, Any] = {}
    for c in cases:
        cid = c["id"]
        f_str = c.get("f_desap_str") or c.get("f_aparicion_str")
        if f_str:
            dt = parse_date_safe(f_str)
            if dt:
                portal_date_map[cid] = dt
                # También mapear por nombre en mayúsculas
                nom = c.get("nombre_completo")
                if nom:
                    portal_date_map[nom] = dt

    print(f"      Mapeadas {len(portal_date_map)} fechas oficiales válidas.")

    print("[2/3] Leyendo casos de Firestore y comparando fechas...")
    docs = list(db.collection(CASOS_COLLECTION).stream())
    
    batch = db.batch()
    ops = 0
    updated_count = 0

    for d in docs:
        doc_id = d.id
        data = d.to_dict()
        f_desap = data.get("fecha_desaparicion")
        f_act = data.get("fecha_actualizacion")
        f_crea = data.get("fecha_creacion")
        nombre = (data.get("nombre") or "").strip().upper()

        # Determinar si la fecha actual en Firestore es sospechosa (fallback a now_utc)
        is_suspicious = False
        if f_desap and f_act and abs((f_desap - f_act).total_seconds()) < 600:
            is_suspicious = True
        elif f_desap and f_crea and abs((f_desap - f_crea).total_seconds()) < 600:
            is_suspicious = True

        # Buscar fecha real
        real_dt = portal_date_map.get(doc_id) or portal_date_map.get(nombre)

        if real_dt and (is_suspicious or (f_desap and abs((real_dt - f_desap).total_seconds()) > 86400)):
            batch.update(d.reference, {"fecha_desaparicion": real_dt})
            ops += 1
            updated_count += 1
            print(f"      [CORREGIDO] {nombre} ({doc_id}) -> {real_dt} (antes: {f_desap})")

            if ops >= 50:
                batch.commit()
                batch = db.batch()
                ops = 0

    if ops > 0:
        batch.commit()

    print(f"\n[3/3] [EXITO] Remediación completada: {updated_count} casos actualizados con su fecha oficial real.")

if __name__ == "__main__":
    main()
