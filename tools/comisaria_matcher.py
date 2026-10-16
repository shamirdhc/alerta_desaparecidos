import json
import os
import re
import unicodedata

COMISARIAS_JSON_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "assets", "data", "comisarias_nacional.json")
)

def strip_accents(text):
    if not text:
        return ""
    text = unicodedata.normalize('NFD', text)
    text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
    return text.upper().strip()

def clean_comisaria_name(name):
    """
    Limpia y extrae el nombre clave de la comisaría eliminando prefijos y sufijos comunes.
    Ej: "COMISARIA PNP ACEQUIA ALTA 'C'" -> "ACEQUIA ALTA"
        "REGPOL - AREQUIPA - COMISARIA ACEQUIA ALTA 'C'" -> "ACEQUIA ALTA"
        "COMISARIA VITARTE" -> "VITARTE"
    """
    s = strip_accents(name)
    # Si viene con jerarquía policial separada por guiones
    if '-' in s:
        parts = [p.strip() for p in s.split('-') if p.strip()]
        # Usar la última parte que suele ser la comisaría
        s = parts[-1]
        
    # Eliminar comillas y tipos de categoría ("A", "B", "C", 'A', etc.)
    s = re.sub(r'[\'"][A-Z][\'"]', '', s)
    s = re.sub(r'\b[A-Z]\b$', '', s)
    
    # Remover prefijos habituales
    s = re.sub(r'\b(COMISARIA|CPNP|PNP|SEC|SECTORIAL|FAMILIA|DEPINCRI|DIVPOL|REGPOL|SUBURBANA|TURISMO)\b', ' ', s)
    s = re.sub(r'[^A-Z0-9\s]', ' ', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s

class ComisariaMatcher:
    def __init__(self, json_path=COMISARIAS_JSON_PATH):
        self.comisarias = []
        if os.path.exists(json_path):
            with open(json_path, 'r', encoding='utf-8') as f:
                self.comisarias = json.load(f)
        else:
            print(f"⚠️ No se encontró archivo de comisarías en {json_path}")
            
        # Pre-indexar
        self._build_index()

    def _build_index(self):
        self.by_dep = {}
        for c in self.comisarias:
            dep = strip_accents(c.get('departamento', ''))
            key_name = clean_comisaria_name(c.get('nombre', ''))
            raw_name = strip_accents(c.get('nombre', ''))
            distrito = strip_accents(c.get('distrito', ''))
            tel = c.get('telefono', '').strip()
            
            entry = {
                'raw': c,
                'key_name': key_name,
                'raw_name': raw_name,
                'departamento': dep,
                'distrito': distrito,
                'telefono': tel,
                'nombre_oficial': c.get('nombre', '')
            }
            self.by_dep.setdefault(dep, []).append(entry)

    def match(self, dependencia_raw, departamento=None, provincia=None, distrito=None):
        """
        Encuentra la comisaría más adecuada y devuelve un dict con:
        {
            'matched': bool,
            'nombre': str,
            'telefono': str,
            'direccion': str,
            'distrito': str,
            'departamento': str,
            'match_type': str
        }
        """
        dep_norm = strip_accents(departamento or "")
        dist_norm = strip_accents(distrito or "")
        key_target = clean_comisaria_name(dependencia_raw or "")
        raw_target = strip_accents(dependencia_raw or "")

        # 1. Búsqueda en el departamento indicado por key_name exacto
        candidates = self.by_dep.get(dep_norm, self.comisarias)
        if isinstance(candidates, list) and candidates and isinstance(candidates[0], dict) and 'key_name' in candidates[0]:
            pass
        else:
            # Fallback a todas
            candidates = [
                {
                    'raw': c,
                    'key_name': clean_comisaria_name(c.get('nombre', '')),
                    'raw_name': strip_accents(c.get('nombre', '')),
                    'departamento': strip_accents(c.get('departamento', '')),
                    'distrito': strip_accents(c.get('distrito', '')),
                    'telefono': c.get('telefono', '').strip(),
                    'nombre_oficial': c.get('nombre', '')
                }
                for c in self.comisarias
            ]

        # Nivel 1: key_name coincide exactamente dentro del departamento
        if key_target and len(key_target) >= 3:
            for item in candidates:
                if item['departamento'] == dep_norm or not dep_norm:
                    if item['key_name'] == key_target and item['telefono']:
                        return self._build_result(item, 'KEY_NAME_DEP_MATCH')
                        
            # Contención de key_name
            for item in candidates:
                if item['departamento'] == dep_norm or not dep_norm:
                    if (key_target in item['key_name'] or item['key_name'] in key_target) and item['telefono']:
                        return self._build_result(item, 'KEY_NAME_CONTAINS_DEP_MATCH')

        # Nivel 2: Búsqueda global a nivel nacional si key_target es muy específico
        if key_target and len(key_target) >= 4:
            all_entries = [
                item for dep_list in self.by_dep.values() for item in dep_list
            ]
            for item in all_entries:
                if item['key_name'] == key_target and item['telefono']:
                    return self._build_result(item, 'NATIONAL_EXACT_MATCH')

        # Nivel 3: Match por distrito y departamento
        if dist_norm and len(dist_norm) >= 3:
            dep_candidates = self.by_dep.get(dep_norm, [])
            for item in dep_candidates:
                if item['distrito'] == dist_norm and item['telefono']:
                    return self._build_result(item, 'DISTRITO_DEP_MATCH')
                if dist_norm in item['key_name'] and item['telefono']:
                    return self._build_result(item, 'DISTRITO_IN_NAME_MATCH')

        # Nivel 4: Si no hubo match telefónico directo, devolver datos con fallback a Línea 114
        fallback_name = dependencia_raw.strip() if dependencia_raw else "Policía Nacional del Perú"
        if '-' in fallback_name:
            fallback_name = fallback_name.split('-')[-1].strip()
            
        return {
            'matched': False,
            'nombre': fallback_name,
            'telefono': '01 418-4030',
            'direccion': '',
            'distrito': distrito or '',
            'departamento': departamento or '',
            'match_type': 'FALLBACK_PNP'
        }

    def _build_result(self, item, match_type):
        raw = item['raw']
        return {
            'matched': True,
            'nombre': item['nombre_oficial'],
            'telefono': item['telefono'],
            'direccion': raw.get('direccion', ''),
            'distrito': raw.get('distrito', ''),
            'departamento': raw.get('departamento', ''),
            'match_type': match_type
        }

# Instancia singleton para uso rápido
_default_matcher = None

def get_matcher():
    global _default_matcher
    if _default_matcher is None:
        _default_matcher = ComisariaMatcher()
    return _default_matcher

def find_comisaria_phone(dependencia_raw, departamento=None, provincia=None, distrito=None):
    matcher = get_matcher()
    return matcher.match(dependencia_raw, departamento, provincia, distrito)
