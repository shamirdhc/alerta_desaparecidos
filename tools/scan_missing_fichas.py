import json
import urllib.request
import ssl
from attach_notas_alerta import get_valid_token, FIRESTORE_PROJECT

token = get_valid_token()
ctx = ssl._create_unverified_context()

sin_ficha = []
con_ficha = []
total_docs = 0
page_token = None

while True:
    url = f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/desaparecidos?pageSize=300"
    if page_token:
        url += f"&pageToken={page_token}"
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    with urllib.request.urlopen(req, context=ctx) as res:
        data = json.loads(res.read().decode('utf-8'))
    
    docs = data.get('documents', [])
    total_docs += len(docs)
    for d in docs:
        doc_id = d['name'].split('/')[-1]
        fields = d.get('fields', {})
        ficha = fields.get('imagen_ficha_url', {}).get('stringValue', '')
        if not ficha or ficha.strip() == '':
            sin_ficha.append({
                'id': doc_id,
                'nombre': fields.get('nombres', {}).get('stringValue', '') + ' ' + fields.get('apellidos', {}).get('stringValue', ''),
                'estado': fields.get('estado', {}).get('stringValue', ''),
                'foto': fields.get('foto_url', {}).get('stringValue', ''),
                'detail_url': fields.get('detail_url_pnp', {}).get('stringValue', '')
            })
        else:
            con_ficha.append(doc_id)
    
    page_token = data.get('nextPageToken')
    if not page_token:
        break

print(f"Total docs en BD: {total_docs}")
print(f"Total CON ficha: {len(con_ficha)}")
print(f"Total SIN ficha: {len(sin_ficha)}")
print("\nCasos sin ficha:")
for c in sin_ficha:
    print(f"  {c['id']} | {c['nombre']} | {c['estado']} | detail: {c['detail_url']}")

with open("tools/casos_sin_ficha.json", "w", encoding="utf-8") as f:
    json.dump(sin_ficha, f, indent=2, ensure_ascii=False)
print(f"\nGuardados {len(sin_ficha)} casos en tools/casos_sin_ficha.json")
