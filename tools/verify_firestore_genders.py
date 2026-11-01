import os
import sys
import firebase_admin
from firebase_admin import credentials, firestore
from collections import Counter

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

sa_path = os.path.join(ROOT_DIR, "serviceAccountKey.json")
if not firebase_admin._apps:
    cred = credentials.Certificate(sa_path)
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("Leyendo todos los documentos de 'desaparecidos' en Firestore...")
docs = list(db.collection("desaparecidos").stream())
print(f"Total documentos encontrados: {len(docs)}")

counts = Counter()
null_or_unknown = []
female_sample = []
male_sample = []

for d in docs:
    data = d.to_dict()
    sexo = data.get("sexo")
    counts[sexo] += 1
    
    nombre = data.get("nombre") or f"{data.get('nombres', '')} {data.get('apellidos', '')}".strip()
    if not sexo:
        null_or_unknown.append((d.id, nombre))
    elif sexo == "FEMENINO" and len(female_sample) < 10:
        female_sample.append((d.id, nombre))
    elif sexo == "MASCULINO" and len(male_sample) < 10:
        male_sample.append((d.id, nombre))

print("\n--- DISTRIBUCIÓN ACTUAL DE GÉNERO EN FIRESTORE ---")
for k, v in counts.items():
    pct = (v / len(docs)) * 100
    print(f"  {k}: {v} ({pct:.1f}%)")

if null_or_unknown:
    print(f"\nDocumentos sin sexo definido ({len(null_or_unknown)}):")
    for doc_id, nom in null_or_unknown[:10]:
        print(f"  ID: {doc_id} | Nombre: {nom}")
else:
    print("\n[EXCELENTE] 0 documentos sin sexo definido.")

print("\nMuestra FEMENINO:")
for doc_id, nom in female_sample:
    print(f"  - {nom} ({doc_id})")

print("\nMuestra MASCULINO:")
for doc_id, nom in male_sample:
    print(f"  - {nom} ({doc_id})")
