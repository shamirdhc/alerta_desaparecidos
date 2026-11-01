#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Aplica la corrección definitiva de género (sexo) a los 2,080 documentos de Firestore
utilizando el Motor Maestro de Resolución de Género (tools.gender_resolver).
"""

import sys
import os
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)
if '.' not in sys.path:
    sys.path.insert(0, '.')

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

import firebase_admin
from firebase_admin import credentials, firestore
from tools.gender_resolver import resolve_gender
from collections import Counter

cred = credentials.Certificate('serviceAccountKey.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

print("====================================================================")
print("  CORRECTOR MAESTRO DE GÉNERO - ALERTA DESAPARECIDOS PNP")
print("====================================================================")

docs = list(db.collection('desaparecidos').stream())
print(f"Total documentos en Firestore: {len(docs)}")

batch = db.batch()
ops_in_batch = 0
total_updated = 0
updates_summary = Counter()

for d in docs:
    dic = d.to_dict()
    curr_sex = dic.get('sexo')
    nom = dic.get('nombre', '')
    
    new_sex = resolve_gender(
        nombres=dic.get('nombres', ''),
        apellidos=dic.get('apellidos', ''),
        nombre_completo=nom,
        detalles=dic.get('detalles_adicionales', ''),
        doc_id=d.id,
        dni=dic.get('dni', '')
    )
    
    if curr_sex != new_sex:
        doc_ref = db.collection('desaparecidos').document(d.id)
        batch.update(doc_ref, {'sexo': new_sex})
        ops_in_batch += 1
        total_updated += 1
        transition = f"{curr_sex or 'None'} -> {new_sex}"
        updates_summary[transition] += 1
        
        if total_updated <= 20 or total_updated % 50 == 0:
            print(f"   [{total_updated}] {d.id} | {nom}: {curr_sex} -> {new_sex}")
            
        if ops_in_batch >= 450:
            batch.commit()
            print(f"      [COMMIT] Lote de {ops_in_batch} escrituras enviado a Firestore.")
            batch = db.batch()
            ops_in_batch = 0

if ops_in_batch > 0:
    batch.commit()
    print(f"      [COMMIT] Lote final de {ops_in_batch} escrituras enviado a Firestore.")

print("\n====================================================================")
print(f"✅ ¡ACTUALIZACIÓN COMPLETADA CON ÉXITO!")
print(f"Total casos corregidos en Firestore: {total_updated}")
print("Resumen de transiciones:")
for trans, cnt in updates_summary.items():
    print(f"   • {trans}: {cnt} casos")
print("====================================================================")
