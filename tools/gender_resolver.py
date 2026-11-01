#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
MOTOR MAESTRO DE RESOLUCIÓN DE GÉNERO (SEXO) - ALERTA DESAPARECIDOS PNP
Combina:
  1. Base de datos oficial de la Policía Nacional del Perú (PNP Oficial Buscar M/F)
  2. Gramática forense en ficha/detalles (FENOTIPO MESTIZA/MESTIZO, etc.)
  3. Diccionario exhaustivo de nombres peruanos, quechuas, aymaras e internacionales
  4. Aislamiento estricto de apellidos peruanos comunes
================================================================================
"""

import json
import os
import re
from typing import Optional, Set

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PNP_OFFICIAL_PATH = os.path.join(ROOT_DIR, "tools", "pnp_official_genders.json")

# Diccionario de nombres femeninos (Perú / Latinoamérica / Internacional)
FEMALE_GIVEN_NAMES: Set[str] = {
    'MARIA', 'MARÍA', 'ANA', 'ROSA', 'CARMEN', 'PILAR', 'FLOR', 'ISABEL', 'RUTH',
    'ESTHER', 'LUCIA', 'LUCÍA', 'BEATRIZ', 'MERCEDES', 'ROCIO', 'ROCÍO', 'ROSARIO',
    'MIRIAM', 'MYRIAM', 'JUDITH', 'BELEN', 'BELÉN', 'INES', 'INÉS', 'CONSUELO',
    'MARIBEL', 'ABIGAIL', 'GLADYS', 'SONIA', 'YOLANDA', 'LILIANA', 'JULIA', 'NORMA',
    'OLGA', 'RAQUEL', 'VILMA', 'ZOILA', 'ELIZABETH', 'ELIZABET', 'TERESA', 'SILVIA',
    'SANDRA', 'CECILIA', 'MONICA', 'MÓNICA', 'VERONICA', 'VERÓNICA', 'JESSICA', 'YESSICA',
    'FATIMA', 'FÁTIMA', 'VANESSA', 'VANESA', 'XIMENA', 'JIMENA', 'CAROLINA', 'DANIELA',
    'GABRIELA', 'CLAUDIA', 'PATRICIA', 'PAOLA', 'ALEJANDRA', 'ADRIANA', 'ANDREA',
    'DIANA', 'NOEMI', 'NOEMÍ', 'AZUCENA', 'KEIKO', 'VALERIA', 'SOFIA', 'SOFÍA',
    'ANGELICA', 'ANGÉLICA', 'GUADALUPE', 'MILAGROS', 'CAMILA', 'KAMILA', 'LUCERO',
    'LUCERITO', 'XIOMARA', 'GENESIS', 'GÉNESIS', 'SOL', 'MARIELA', 'ANTONELLA',
    'MELISSA', 'MELISA', 'DAYANA', 'STEFANY', 'STEPHANY', 'ESTEFANY', 'ESTEFANI',
    'KATHERINE', 'CINTHIA', 'CYNTHIA', 'WENDY', 'LESLIE', 'LESLY', 'DEYSI', 'DAISY',
    'DAYSI', 'KEYLA', 'KIARA', 'BRIANA', 'BRIANNA', 'BRISSA', 'ALISON', 'ALISSON',
    'NATHALY', 'NATALY', 'NATALIA', 'NAYELI', 'NAYELY', 'CIELO', 'ARACELLY', 'ARACELY',
    'SCARLETT', 'SCARLET', 'LUANA', 'LIZ', 'LIZETH', 'LISETH', 'YULISSA', 'YULISA',
    'NICOLE', 'NICOLL', 'KAREN', 'SHIRLEY', 'EVELYN', 'EVELIN', 'JAZMIN', 'JAZMÍN',
    'YASMIN', 'YASMÍN', 'DOMENICA', 'ASTRID', 'BIANCA', 'DANNA', 'EMILY', 'FIORELLA',
    'GIANNA', 'GRECIA', 'INGRID', 'ITXEL', 'ITZEL', 'LIA', 'LÍA', 'MIA', 'MÍA',
    'ROMINA', 'SAMANTHA', 'VALENTINA', 'ZULEMA', 'ALEXANDRA', 'BRITANY', 'BRITHANY',
    'BRITTHANY', 'HEIDY', 'HEYDI', 'JHOSELYN', 'JOCELYN', 'JOCELYNE', 'KIMBERLY',
    'MARYORI', 'MAYRA', 'MAYTE', 'MELANY', 'MISHELL', 'NAHOMI', 'NAOMI', 'SHEILA',
    'YADHIRA', 'YAMILE', 'YAMILET', 'YAMILETH', 'YOBANA', 'JENIFER', 'JENNIFER',
    'ZOE', 'ZOÉ', 'SUSANA', 'LEONOR', 'MABEL', 'MARY', 'FORTUNATA', 'MARGARITA',
    'VIVIAN', 'MARISA', 'ESTRELLA', 'ROXANA', 'ROXANNA', 'ZENAIDA', 'FELICITA',
    'FELÍCITA', 'FELICITAS', 'RUBI', 'RUBÍ', 'ESMERALDA', 'BRENDA', 'LADY', 'ANNEL',
    'YANELY', 'CRHIS', 'JACKELINE', 'DAMARIS', 'TAMIKO', 'DARLYNNE', 'IVONNE',
    'MARINEZ', 'YAMILI', 'NINOSKA', 'PALOMA', 'SAMIRA', 'DAYRA', 'YURELI', 'URPI',
    'SAYARUMI', 'MAYARA', 'MARYTRINY', 'DANELY', 'AYLIN', 'JHAMELIN', 'CESIA',
    'SHUEMIT', 'JAKELIN', 'NAYSER', 'RAYCHEL', 'GINYER', 'ANGELI', 'GUISELA',
    'JANNY', 'ANAGABRIELA', 'ANACLO', 'MARGOLITH', 'HANET', 'ISABET', 'ANGHELA',
    'YERALDIN', 'SHANTALL', 'GAELA', 'RAYSHEEL', 'HAYLEY', 'CONNIE', 'BRIANY',
    'YANDHY', 'MAYLEYDY', 'NATIVIDAD', 'CLARA', 'YURICA', 'SHARON', 'SHAROL',
    'BETZABE', 'BETHSABE', 'GRETHEL', 'YOMIRA', 'YOSHIRA', 'YADIRA', 'YOMALI',
    'YORLADY', 'KEYLI', 'KAORI', 'KIOMARA', 'KASANDRA', 'KASSANDRA', 'KLARITA',
    'CLARITA', 'CANDY', 'CRISTEL', 'KRISTEL', 'CYNTHYA', 'CINTIA', 'DEYSY',
    'DENISSE', 'DALIA', 'DULCE', 'EDITH', 'ELENA', 'ELVIRA', 'EMA', 'EMMA',
    'ERIKA', 'ERICA', 'EUGENIA', 'EVA', 'EVITA', 'FANNY', 'FANY', 'GISELLE',
    'GISELA', 'GISELLA', 'GLORIA', 'GRACIELA', 'HILDA', 'ILDA', 'ISABELA',
    'ISABELLA', 'IVON', 'IVETH', 'JACQUELINE', 'JANET', 'JEANETTE', 'JESSENIA',
    'YESENIA', 'YESSENIA', 'JOHANA', 'JOHANNA', 'JOVANA', 'JUANITA', 'JULIETA',
    'KARINA', 'KARLA', 'KATIA', 'KATTY', 'KATHY', 'LEYDI', 'LEYDY', 'LEIDY',
    'LIDIA', 'LORENA', 'LOURDES', 'LUCILA', 'MAGALY', 'MAIRA', 'MANUELA',
    'MARCELA', 'MARLENE', 'MARLENY', 'MARTA', 'MARTHA', 'MAXIMILIANA', 'MIRTA',
    'MIRTHA', 'NADIA', 'NATALIE', 'NAZARETH', 'NERY', 'NELLY', 'NELI', 'NILDA',
    'NANCY', 'NOELIA', 'OLINDA', 'PATTY', 'PERLA', 'REGINA', 'RENATA', 'REYNA',
    'RINA', 'RITA', 'ROSALIA', 'ROSALÍA', 'ROSALINDA', 'ROSALVA', 'ROSALBA',
    'ROSANA', 'ROSMERY', 'ROSEMARY', 'RUT', 'SABINA', 'SALOME', 'SALOMÉ', 'SARA',
    'SARITA', 'SEFORA', 'SILVANA', 'SOLANGE', 'SOLEDAD', 'STEPHANIE', 'SUGEY',
    'TANIA', 'THALIA', 'THALÍA', 'WALKIRIA', 'YACKELINE', 'YANETH', 'YANINA',
    'YENI', 'YENIFER', 'YENNY', 'YESICA', 'YULI', 'YULITH', 'ZAIDA', 'ALBA',
    'ALMA', 'AMPARO', 'SOCORRO', 'ASUNCION', 'ASUNCIÓN', 'CANDELARIA', 'CLEMENCIA',
    'ENCARNACION', 'ENCARNACIÓN', 'ESPERANZA', 'EULALIA', 'EVANGELINA', 'FELISA',
    'FIDELA', 'HERMELINDA', 'IGNACIA', 'JUSTINA', 'LEOCADIA', 'LORETO', 'MAGDALENA',
    'MATILDE', 'MODESTA', 'NICOLASA', 'PASCUALA', 'PETRONILA', 'RAIMUNDA', 'RAMONA',
    'RUFINA', 'SEBASTIANA', 'TEODORA', 'TEOFILA', 'TEÓFILA', 'VICENTA', 'VICTORIA',
    'VIRGINIA', 'AIDA', 'AÍDA', 'ALICIA', 'AMALIA', 'AMANDA', 'AMELIA', 'ANABEL',
    'ANABELLA', 'ANAHI', 'ANAHÍ', 'ARIANA', 'AURORA', 'BERTHA', 'BERTA', 'CELIA',
    'CLOTILDE', 'DORA', 'ELSA', 'EUNICE', 'FLORENCIA', 'HERMINIA', 'HONORIA',
    'IRENE', 'IRIS', 'ISADORA', 'JOSEFINA', 'LEONARDA', 'LIGIA', 'LUCRECIA',
    'MARINA', 'NURIA', 'OFELIA', 'PENELOPE', 'PENÉLOPE', 'REBECA', 'SILVINA',
    'SUSI', 'SUZY', 'VIOLETA', 'YANIRE', 'YOVANA', 'YOBANA', 'YOLITA', 'LUZ',
    'MERI', 'MARI', 'SONALY', 'MAYUMI', 'CLEVIA', 'ELISA', 'YANIRA', 'FERNANDITA',
    'TALITA', 'SARAY', 'NICOL', 'DARCY', 'MIRLEY', 'BRITH', 'EMELYN', 'ANAGABRIELA',
    'CELINDA', 'GOENITH', 'YONSHU', 'ALBERTA', 'YASHIRA', 'YURIKO', 'YURITZA',
    'KATHERIN', 'LISBET', 'LISBETH', 'MARJORIE', 'YADIRA', 'YAMILET', 'YAMILE',
    'BRIGITTE', 'BRIGITH', 'BRIGHIT', 'BRIGGITTE', 'MARICIELO', 'ALLISON', 'ALYSON',
    'MAYLI', 'JAMILET', 'MAYLEN', 'CARITO', 'NIKOL', 'ANGIE', 'NAGGELY', 'YOMAIRA',
    'LIZBETH', 'DAIANA', 'KAHORI', 'NICOLLE', 'KIMBERLEY', 'DAFNE', 'CAROLAY', 'SHERINEE'
}

# Diccionario de nombres masculinos
MALE_GIVEN_NAMES: Set[str] = {
    'CARLOS', 'JUAN', 'JOSE', 'JOSÉ', 'JORGE', 'LUIS', 'MIGUEL', 'ANGEL', 'ÁNGEL',
    'VICTOR', 'VÍCTOR', 'PEDRO', 'MANUEL', 'CESAR', 'CÉSAR', 'JESUS', 'JESÚS',
    'DAVID', 'DANIEL', 'DIEGO', 'RAFAEL', 'GABRIEL', 'OSCAR', 'ÓSCAR', 'JAVIER',
    'CRISTIAN', 'CHRISTIAN', 'ALEX', 'ALEXANDER', 'JHON', 'JHONATHAN', 'EDGAR',
    'EDWIN', 'ELVIS', 'WALTER', 'RICARDO', 'ROBERTO', 'MARCOS', 'MARCO', 'SERGIO',
    'RODRIGO', 'ALONSO', 'SEBASTIAN', 'SEBASTIÁN', 'LEONARDO', 'ALEJANDRO',
    'ANTHONY', 'JEAN', 'PIERO', 'FABRIZIO', 'MATHIAS', 'MATIAS', 'MATÍAS',
    'THIAGO', 'TIAGO', 'IAN', 'LIAM', 'DYLAN', 'GAEL', 'LUCAS', 'MATEO',
    'JOAQUIN', 'JOAQUÍN', 'NICOLAS', 'NICOLÁS', 'ADRIANO', 'ALVARO', 'ÁLVARO',
    'BRUNO', 'DARIO', 'DARÍO', 'ESTEBAN', 'FELIPE', 'GONZALO', 'IGNACIO', 'JAIME',
    'JULIO', 'MARIO', 'MARTIN', 'MARTÍN', 'PABLO', 'RAUL', 'RAÚL', 'RUBEN',
    'RUBÉN', 'SAMUEL', 'TOMAS', 'TOMÁS', 'VICENTE', 'HECTOR', 'HÉCTOR', 'HUGO',
    'MAX', 'FELIX', 'FÉLIX', 'ALEXIS', 'ANDRES', 'ANDRÉS', 'ANTONIO', 'ARTURO',
    'CRISTOBAL', 'CRISTÓBAL', 'EDUARDO', 'EMILIO', 'ENRIQUE', 'ERNESTO', 'FERNANDO',
    'FRANCISCO', 'GERARDO', 'GUILLERMO', 'GUSTAVO', 'HERNAN', 'HERNÁN', 'JAIR',
    'JHOSEP', 'JOSEPH', 'JULIAN', 'JULIÁN', 'MANOLO', 'MAURICIO', 'NESTOR', 'NÉSTOR',
    'ORLANDO', 'PATRICIO', 'RAMON', 'RAMÓN', 'RENATO', 'RODOLFO', 'RONALD', 'SALVADOR',
    'SANTIAGO', 'TAYLOR', 'WILSON', 'YERSON', 'YOMAR', 'JHAMPOOL', 'EMERSON',
    'BASTIAN', 'BENJAMIN', 'BENJAMÍN', 'HUMBERTO', 'ALDAIR', 'REYNALDO', 'AURELIO',
    'LEONIDAS', 'MOISES', 'MOISÉS', 'AARON', 'AARÓN', 'CLAUDIO', 'EBER', 'OMAR',
    'JOEL', 'URIEL', 'AMERICO', 'AMÉRICO', 'JOSHUA', 'ABEL', 'FELICIANO', 'LUIGI',
    'GREGORIO', 'BERNARDO', 'DARWIN', 'GENARO', 'RENZO', 'PAUL', 'ARMANDO',
    'FREDDY', 'ELIAS', 'ELÍAS', 'BRYAN', 'BRAYAN', 'JIMMY', 'KEVIN', 'PAULO',
    'AXEL', 'JHAIR', 'FREDY', 'OWEN', 'CRISTOPHER', 'CHRISTOPHER', 'ERICK', 'ERIC',
    'EDINSON', 'EDISON', 'EDGARDO', 'ALBERTO', 'ALFREDO', 'ALONZO', 'AMADO',
    'ANIBAL', 'ANÍBAL', 'APOLINAR', 'ARIEL', 'ARNOLD', 'AUGUSTO', 'BRAULIO',
    'CAMILO', 'CIRO', 'CRISPIN', 'DIONISIO', 'DOMINGO', 'EDILBERTO', 'ELIODORO',
    'ELISEO', 'EMILIANO', 'EUSTAQUIO', 'FABIAN', 'FABIÁN', 'FAUSTINO', 'FEDERICO',
    'FIDEL', 'FLAVIO', 'FRANK', 'FRANKLIN', 'GERMAN', 'GERMÁN', 'GUIDO', 'HEBER',
    'HELBERT', 'HILARIO', 'ISMAEL', 'ISRAEL', 'IVAN', 'IVÁN', 'JACINTO', 'JEREMY',
    'JHEREMY', 'JHOJAN', 'JHONNY', 'JONATHAN', 'JORDAN', 'JORDY', 'JUSTO',
    'LORENZO', 'LUCIO', 'MARCELINO', 'MARCELO', 'MARCIANO', 'MARIANO', 'MAXIMO',
    'MÁXIMO', 'MELCHOR', 'MODESTO', 'NEIL', 'NELSON', 'NICANOR', 'NORBERTO',
    'OSWALDO', 'OSVALDO', 'PERCY', 'REGINALDO', 'REINALDO', 'RICHARD', 'ROGELIO',
    'ROGER', 'ROMAN', 'ROMÁN', 'ROMULO', 'RÓMULO', 'RONAL', 'RONALDO', 'ROY',
    'SABINO', 'SAUL', 'SAÚL', 'SEVERO', 'SILVESTRE', 'TEODORO', 'TIMOTEO',
    'URBANO', 'VALENTIN', 'VALENTÍN', 'VALERIO', 'WALDIR', 'WILFREDO', 'WILLY',
    'WILLIAN', 'WILLIAM', 'YASSER', 'YURI', 'ADOLFO', 'AGUSTIN', 'AGUSTÍN',
    'ALBINO', 'ALFONSO', 'ANASTACIO', 'ANICETO', 'ANSELMO', 'APOLONIO', 'ARCANGEL',
    'ARISTIDES', 'ARQUIMEDES', 'BALDOMERO', 'BARTOLOME', 'BASILIO', 'BELISARIO',
    'BENIGNO', 'BERNABE', 'BLAS', 'BONIFACIO', 'CALIXTO', 'CANDIDO', 'CASIMIRO',
    'CAYETANO', 'CELESTINO', 'CIRILO', 'CLEMENTE', 'CLEVER', 'CRESCENCIO', 'CRISANTO',
    'CRISOSTOMO', 'DELFIN', 'DEMETRIO', 'DOROTEO', 'EFRAIN', 'EFRÉN', 'ELEODORO',
    'ELEUTERIO', 'ELOY', 'EPIMENIO', 'ERASMO', 'ESTANISLAO', 'EUCLIDES', 'EUSEBIO',
    'EVARISTO', 'EZEQUIEL', 'FERMIN', 'FILEMON', 'FLORENTINO', 'FORTUNATO',
    'FROILAN', 'FULGENCIO', 'GABINO', 'GASPAR', 'GILDER', 'GODOFREDO', 'GRIMALDO',
    'HERACLIO', 'HERIBERTO', 'HERMENEGILDO', 'HIPOLITO', 'HOMERO', 'HONORIO',
    'IDELFONSO', 'ILDEFONSO', 'INOCENCIO', 'ISIDORO', 'ISIDRO', 'JEFFERSON',
    'JHONY', 'JOAN', 'JULIANO', 'JUSTINIANO', 'LAUREANO', 'LAZARO', 'LIDIO',
    'LISANDRO', 'LUCIANO', 'LUDOVICO', 'MACARIO', 'MAGNO', 'MAMERTO', 'MANFRED',
    'MAURO', 'MAXIMILIANO', 'MELITON', 'NARCISO', 'NAZARIO', 'NICODEMUS', 'OCTAVIO',
    'OLIVER', 'ONESIMO', 'PASCUAL', 'PASTOR', 'PAULINO', 'PLINIO', 'POLICARPO',
    'POMPILIO', 'PRISCILIANO', 'QUIRINO', 'REMEDIOS', 'RUFINO', 'RUPERTO',
    'SATURNINO', 'SEGUNDO', 'SERAPIO', 'SILVIO', 'SIMEON', 'SIMON', 'SIMÓN',
    'SIXTO', 'TACIANO', 'TADEO', 'TELMO', 'TEOBALDO', 'TEOFILO', 'TEÓFILO',
    'TIBURCIO', 'TORIBIO', 'ULISES', 'VALDEMAR', 'VENANCIO', 'WENCESLAO', 'YONY',
    'YONATAN', 'ZACARIAS', 'JOSUE', 'JOSUÉ', 'BRANDON', 'YVAN', 'DAVIDSON',
    'JOAS', 'ABAD', 'OSTHIN', 'JHONALY', 'JOSIAS'
}

# Apellidos peruanos comunes para que no se confundan con nombres
COMMON_SURNAMES: Set[str] = {
    'QUISPE', 'MAMANI', 'HUAMAN', 'HUAMÁN', 'FLORES', 'SANCHEZ', 'SÁNCHEZ',
    'GOMEZ', 'GÓMEZ', 'CHAVEZ', 'CHÁVEZ', 'DIAZ', 'DÍAZ', 'GARCIA', 'GARCÍA',
    'ROJAS', 'MENDOZA', 'TORRES', 'CASTILLO', 'RAMOS', 'ESPINOZA', 'LOPEZ',
    'LÓPEZ', 'VASQUEZ', 'VÁSQUEZ', 'PEREZ', 'PÉREZ', 'GONZALES', 'GONZÁLEZ',
    'MORALES', 'GUTIERREZ', 'GUTIÉRREZ', 'CONDORI', 'ROMERO', 'VARGAS', 'CASTRO',
    'RIVERA', 'ALVAREZ', 'ÁLVAREZ', 'HERRERA', 'MEDINA', 'SILVA', 'MEJIA',
    'MEJÍA', 'SALAZAR', 'ORTIZ', 'ORTÍZ', 'GUZMAN', 'GUZMÁN', 'SOTO', 'PAREDES',
    'CRUZ', 'DELGADO', 'PEÑA', 'ALVARADO', 'CONTRERAS', 'CACERES', 'CÁCERES',
    'PALACIOS', 'AGUILAR', 'VALVERDE', 'CARDENAS', 'CÁRDENAS', 'RIOS', 'RÍOS',
    'ACOSTA', 'SALAS', 'CORDOVA', 'CÓRDOVA', 'CALDERON', 'CALDERÓN', 'CAMACHO',
    'CARBAJAL', 'CARRASCO', 'CARRILLO', 'CHACON', 'CHACÓN', 'CORONEL', 'CUBAS',
    'DAVILA', 'DÁVILA', 'DELACRUZ', 'ESCOBAR', 'FARFAN', 'FARFÁN', 'GALLARDO',
    'GUEVARA', 'HIDALGO', 'LOAYZA', 'LUJAN', 'LUJÁN', 'MALDONADO', 'MARIN',
    'MARÍN', 'MIRANDA', 'MONTOYA', 'NAVARRO', 'NÚÑEZ', 'NUNEZ', 'OCHOA', 'OLIVERA',
    'PACHECO', 'PINTO', 'PONCE', 'PORTAL', 'PRADO', 'QUINTANA', 'QUIROZ', 'RANGEL',
    'REYES', 'ROBLES', 'RODRIGUEZ', 'RODRÍGUEZ', 'ROSAS', 'RUIZ', 'RUÍZ', 'SALGADO',
    'SANDOVAL', 'SANTACRUZ', 'SERNA', 'SOLIS', 'SOLÍS', 'SUAREZ', 'SUÁREZ', 'TAPIA',
    'TEJADA', 'TELLO', 'TRUJILLO', 'VALDEZ', 'VALDIVIA', 'VALLE', 'VALLEJOS',
    'VEGA', 'VELASQUEZ', 'VELÁSQUEZ', 'VERA', 'VILLANUEVA', 'VILLAR', 'VILLEGAS',
    'YUPANQUI', 'ZAMBRANO', 'ZAPATA', 'ZAVALETA', 'ZEGARRA', 'ZUÑIGA', 'ZUNIGA',
    'SANTOS', 'HORNA', 'MERA', 'MOREY', 'TOWELL', 'ING', 'CURI', 'LLALLA',
    'CHAMPI', 'MENESES', 'PUMA', 'SAMAME', 'DÁVILA', 'DAVILA', 'AMASIFEN',
    'HUAYTA', 'YEPES', 'COAGUILA', 'CHIVIGORRI', 'CUNYA', 'TALLEDO', 'MIRES'
}

_PNP_NORMALIZED_CACHE = None

def _load_pnp_cache():
    global _PNP_NORMALIZED_CACHE
    if _PNP_NORMALIZED_CACHE is not None:
        return _PNP_NORMALIZED_CACHE
    cache = {}
    if os.path.exists(PNP_OFFICIAL_PATH):
        try:
            with open(PNP_OFFICIAL_PATH, "r", encoding="utf-8") as f:
                raw = json.load(f)
            import base64
            for b64, gender in raw.get("by_dni", {}).items():
                cache[b64] = gender
                safe = b64.replace("=", "_").replace("/", "_").replace("+", "_")
                cache[safe] = gender
                cache[f"pnp_{safe}"] = gender
                try:
                    padded = b64.strip() + "=" * (-len(b64.strip()) % 4)
                    dec = base64.b64decode(padded).decode("utf-8", errors="ignore").strip()
                    if dec:
                        cache[dec] = gender
                        cache[f"pnp_{dec}"] = gender
                except Exception:
                    pass
            for name, gender in raw.get("by_name", {}).items():
                clean = " ".join(name.strip().upper().split())
                cache[clean] = gender
        except Exception:
            pass
    _PNP_NORMALIZED_CACHE = cache
    return cache


def clean_token(t: str) -> str:
    return re.sub(r"[^A-ZÁÉÍÓÚÑ]", "", (t or "").upper().strip())


def resolve_gender(
    nombres: Optional[str] = "",
    apellidos: Optional[str] = "",
    nombre_completo: Optional[str] = "",
    detalles: Optional[str] = "",
    doc_id: Optional[str] = "",
    dni: Optional[str] = "",
    category: Optional[str] = "",
    url_route: Optional[str] = ""
) -> str:
    """
    Determina de manera inequívoca y exhaustiva el género (MASCULINO o FEMENINO).
    """
    # 0. Extracción de tokens de nombres previos para validación
    clean_full = " ".join((nombre_completo or f"{nombres or ''} {apellidos or ''}").strip().upper().split())
    name_tokens = [clean_token(w) for w in (nombres or "").split() if clean_token(w)]
    full_tokens = [clean_token(w) for w in clean_full.split() if clean_token(w)]
    given_candidates = name_tokens if name_tokens else full_tokens
    non_surname = [t for t in given_candidates if t not in COMMON_SURNAMES] or given_candidates

    fem_matches = [t for t in non_surname if t in FEMALE_GIVEN_NAMES]
    male_matches = [t for t in non_surname if t in MALE_GIVEN_NAMES]

    # Si los nombres de pila son 100% inequívocos, prevalecen sobre cualquier error tipográfico del portal PNP
    if fem_matches and not male_matches:
        return "FEMENINO"
    if male_matches and not fem_matches:
        return "MASCULINO"

    # 1. Chequeo contra Base Oficial PNP
    cache = _load_pnp_cache()
    if doc_id and doc_id in cache:
        return cache[doc_id]
    if dni and dni in cache:
        return cache[dni]
    if clean_full in cache:
        return cache[clean_full]

    # 2. Chequeo de URL oficial de Nota de Alerta
    if url_route:
        if "nota_alerta_mujer" in url_route:
            return "FEMENINO"
        if "nota_alerta_hombre" in url_route:
            return "MASCULINO"

    # 3. Chequeo gramatical forense en ficha oficial
    det_upper = (detalles or "").upper()
    if "FENOTIPO: MESTIZA" in det_upper or "FENOTIPO : MESTIZA" in det_upper or "FENOTIPO : BLANCA" in det_upper:
        return "FEMENINO"
    if "FENOTIPO: MESTIZO" in det_upper or "FENOTIPO : MESTIZO" in det_upper or "FENOTIPO : BLANCO" in det_upper:
        return "MASCULINO"

    # 4. Extracción de tokens de nombres
    name_tokens = [clean_token(w) for w in (nombres or "").split() if clean_token(w)]
    full_tokens = [clean_token(w) for w in clean_full.split() if clean_token(w)]
    
    given_candidates = name_tokens if name_tokens else full_tokens
    non_surname = [t for t in given_candidates if t not in COMMON_SURNAMES]
    if not non_surname:
        non_surname = given_candidates

    # Búsqueda en diccionarios
    fem_matches = [t for t in non_surname if t in FEMALE_GIVEN_NAMES]
    male_matches = [t for t in non_surname if t in MALE_GIVEN_NAMES]

    if fem_matches and not male_matches:
        return "FEMENINO"
    if male_matches and not fem_matches:
        return "MASCULINO"
    if fem_matches and male_matches:
        # Nombres compuestos (el primer nombre decide: 'MARIA JOSE' -> F, 'JOSE MARIA' -> M)
        for t in non_surname:
            if t in FEMALE_GIVEN_NAMES:
                return "FEMENINO"
            if t in MALE_GIVEN_NAMES:
                return "MASCULINO"

    # Si se evaluó solo 'nombres' y fue ambiguo, intentar con el full name
    if given_candidates != full_tokens:
        full_non_surname = [t for t in full_tokens if t not in COMMON_SURNAMES]
        fem_full = [t for t in full_non_surname if t in FEMALE_GIVEN_NAMES]
        male_full = [t for t in full_non_surname if t in MALE_GIVEN_NAMES]
        if fem_full and not male_full:
            return "FEMENINO"
        if male_full and not fem_full:
            return "MASCULINO"
        if fem_full and male_full:
            for t in full_non_surname:
                if t in FEMALE_GIVEN_NAMES:
                    return "FEMENINO"
                if t in MALE_GIVEN_NAMES:
                    return "MASCULINO"

    # 5. Heurísticas morfológicas de sufijos para nombres no catalogados
    first_name = non_surname[0] if non_surname else (full_tokens[0] if full_tokens else "")
    if first_name:
        if first_name in {"JOSHUA", "SASHA", "LUKA", "ISSA"}:
            return "MASCULINO"
        if first_name.endswith(("ITH", "ETH", "ETTE", "INA", "ELA", "ILA", "IRA", "ITA", "ANA", "ENA", "IA", "CIA", "NDA", "RRA")):
            return "FEMENINO"
        if first_name.endswith("A"):
            return "FEMENINO"
        if first_name.endswith(("O", "IO", "OR", "ON", "ÓN", "AN", "ÁN", "ER", "EL", "OS", "IN", "ÍN", "US", "TO", "RO")):
            return "MASCULINO"

    # 6. Pistas de contexto
    if "MUJER" in (category or "").upper():
        return "FEMENINO"
    if "HOMBRE" in (category or "").upper():
        return "MASCULINO"
    if " LA EMBARCO" in det_upper or "DESAPARECIDA" in det_upper or "MENOR DE EDAD DE SEXO FEMENINO" in det_upper:
        return "FEMENINO"
    if "DESAPARECIDO" in det_upper or "MENOR DE EDAD DE SEXO MASCULINO" in det_upper:
        return "MASCULINO"

    return "MASCULINO"
