const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Inicializar Firebase Admin
admin.initializeApp();

// Función que se ejecuta cuando se crea un nuevo comentario
exports.sendCommentNotification = onDocumentCreated(
    "missing_persons/{missingPersonId}/comments/{commentId}",
    async (event) => {
        try {
            console.log("🚀 Iniciando envío de notificación para nuevo comentario");
            
            const commentData = event.data.data();
            const missingPersonId = event.params.missingPersonId;
            const commentId = event.params.commentId;
            
            console.log("📝 Comentario ID:", commentId);
            console.log("👤 Persona desaparecida ID:", missingPersonId);
            
            // Obtener datos de la persona desaparecida
            const missingPersonDoc = await admin.firestore()
                .collection("missing_persons")
                .doc(missingPersonId)
                .get();
            
            if (!missingPersonDoc.exists) {
                console.log("❌ Persona desaparecida no encontrada");
                return null;
            }
            
            const missingPersonData = missingPersonDoc.data();
            const departamento = missingPersonData.departamento;
            
            if (!departamento) {
                console.log("❌ Departamento no especificado en el caso");
                return null;
            }
            
            console.log("🏢 Departamento del caso:", departamento);
            
            // Obtener policías del departamento con tokens FCM
            const policiasSnapshot = await admin.firestore()
                .collection("policias")
                .where("departamento", "==", departamento)
                .where("fcmToken", "!=", null)
                .get();
            
            if (policiasSnapshot.empty) {
                console.log("❌ No hay policías con tokens FCM en el departamento:", departamento);
                return null;
            }
            
            console.log("👮 Encontrados", policiasSnapshot.size, "policías con tokens FCM");
            
            // Recopilar tokens válidos
            const tokens = [];
            
            policiasSnapshot.forEach((doc) => {
                const policiaData = doc.data();
                const token = policiaData.fcmToken;
                
                if (token && typeof token === "string" && token.trim().length > 0) {
                    tokens.push(token.trim());
                    console.log("👮 Policía:", policiaData.nombre, policiaData.apellido, "- Departamento:", policiaData.departamento);
                }
            });
            
            if (tokens.length === 0) {
                console.log("❌ No hay tokens FCM válidos");
                return null;
            }
            
            console.log("📱 Tokens válidos encontrados:", tokens.length);
            
            // Preparar datos del mensaje
            const nombreCompleto = (missingPersonData.nombres || "") + " " + (missingPersonData.apellidos || "");
            const phoneNumber = commentData.phoneNumber || "Número desconocido";
            const comentarioTexto = commentData.text || "Sin texto";
            const ubicacion = commentData.location || "Ubicación no especificada";
            
            // Formatear fecha y hora
            const ahora = new Date();
            const fechaHora = ahora.toLocaleString("es-PE", {
                timeZone: "America/Lima",
                day: "2-digit",
                month: "2-digit",
                year: "numeric",
                hour: "2-digit",
                minute: "2-digit"
            });
            
            // Truncar texto si es muy largo para el cuerpo
            const textoTruncado = comentarioTexto.length > 60 ?
                comentarioTexto.substring(0, 60) + "..." :
                comentarioTexto;
            
            // Crear mensaje de notificación mejorado
            const message = {
                notification: {
                    title: "🚨 NUEVO COMENTARIO - CASO ACTIVO",
                    body: `👤 ${nombreCompleto}\n📱 ${phoneNumber}\n💬 "${textoTruncado}"`,
                    imageUrl: missingPersonData.photoUrl || null,
                },
                data: {
                    missingPersonId: missingPersonId,
                    commentId: commentId,
                    type: "comment",
                    departamento: departamento,
                    nombreCompleto: nombreCompleto,
                    phoneNumber: phoneNumber,
                    comentarioCompleto: comentarioTexto,
                    ubicacion: ubicacion,
                    fechaHora: fechaHora,
                    photoUrl: missingPersonData.photoUrl || "",
                    edad: missingPersonData.edad?.toString() || "",
                    genero: missingPersonData.genero || "",
                },
                android: {
                    notification: {
                        icon: "ic_launcher",
                        color: "#D32F2F",
                        channelId: "police_notifications",
                        priority: "high",
                        defaultSound: true,
                        defaultVibrateTimings: true,
                        defaultLightSettings: true,
                        sticky: true,
                        localOnly: false,
                        tag: `comment_${missingPersonId}`,
                        clickAction: "FLUTTER_NOTIFICATION_CLICK",
                        bodyLocKey: "comment_notification_body",
                        bodyLocArgs: [nombreCompleto, phoneNumber, textoTruncado],
                        titleLocKey: "comment_notification_title",
                        style: {
                            type: "bigText",
                            bigText: `📋 CASO: ${nombreCompleto}\n📱 CONTACTO: ${phoneNumber}\n📍 UBICACIÓN: ${ubicacion}\n💬 COMENTARIO: ${comentarioTexto}\n🕐 HORA: ${fechaHora}`,
                            summaryText: `Departamento: ${departamento}`,
                        },
                    },
                    priority: "high",
                    ttl: 3600000,
                },
                apns: {
                    payload: {
                        aps: {
                            alert: {
                                title: "🚨 NUEVO COMENTARIO - CASO ACTIVO",
                                subtitle: `Caso: ${nombreCompleto}`,
                                body: `📱 ${phoneNumber}: "${textoTruncado}"`,
                            },
                            badge: 1,
                            sound: "default",
                            category: "COMMENT_CATEGORY",
                            threadId: `case_${missingPersonId}`,
                            interruptionLevel: "timeSensitive",
                        },
                    },
                    headers: {
                        "apns-priority": "10",
                        "apns-push-type": "alert",
                    },
                },
                webpush: {
                    notification: {
                        title: "🚨 NUEVO COMENTARIO - CASO ACTIVO",
                        body: `${nombreCompleto}: "${textoTruncado}"`,
                        icon: "/icons/Icon-192.png",
                        badge: "/favicon.png",
                        image: missingPersonData.photoUrl || undefined,
                        tag: `comment_${missingPersonId}`,
                        requireInteraction: true,
                        actions: [
                            { action: "open_case", title: "🚨 Ver Pista" }
                        ]
                    },
                    fcmOptions: {
                        link: "/"
                    }
                },
                tokens: tokens,
            };
            
            console.log("📤 Enviando notificación mejorada...");
            console.log("   📋 Título:", message.notification.title);
            console.log("   💬 Cuerpo:", message.notification.body);
            
            // Enviar notificación
            const response = await admin.messaging().sendMulticast(message);
            
            console.log("✅ Notificaciones enviadas:", response.successCount + "/" + tokens.length);
            
            if (response.failureCount > 0) {
                console.log("❌ Fallos:", response.failureCount);
                response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                        console.log("   ❌ Token", idx, ":", resp.error.message);
                    }
                });
                
                // Limpiar tokens inválidos
                const batch = admin.firestore().batch();
                response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                        const invalidToken = tokens[idx];
                        // Buscar y limpiar el token inválido
                        policiasSnapshot.forEach((doc) => {
                            const policiaData = doc.data();
                            if (policiaData.fcmToken === invalidToken) {
                                batch.update(doc.ref, {
                                    fcmToken: admin.firestore.FieldValue.delete(),
                                });
                                console.log("🧹 Marcando token inválido para eliminación:", invalidToken);
                            }
                        });
                    }
                });
                
                if (response.failureCount > 0) {
                    await batch.commit();
                    console.log("🧹 Tokens inválidos eliminados");
                }
            }
            
            return {
                success: true,
                tokensEnviados: tokens.length,
                exitosos: response.successCount,
                fallidos: response.failureCount,
            };
            
        } catch (error) {
            console.error("❌ Error enviando notificación:", error);
            throw error;
        }
    }
);

// Función para limpiar tokens FCM inválidos
exports.cleanupInvalidTokens = onSchedule("every 24 hours", async (event) => {
    console.log("🧹 Iniciando limpieza de tokens FCM inválidos");
    
    try {
        const policiasWithTokens = await admin.firestore()
            .collection("policias")
            .where("fcmToken", "!=", null)
            .get();
        
        const batch = admin.firestore().batch();
        let tokensLimpiados = 0;
        
        policiasWithTokens.forEach((doc) => {
            const policiaData = doc.data();
            const token = policiaData.fcmToken;
            
            if (!token || typeof token !== "string" || token.trim().length === 0) {
                batch.update(doc.ref, {
                    fcmToken: admin.firestore.FieldValue.delete(),
                });
                tokensLimpiados++;
            }
        });
        
        if (tokensLimpiados > 0) {
            await batch.commit();
            console.log("🧹 Tokens limpiados:", tokensLimpiados);
        } else {
            console.log("✅ No hay tokens para limpiar");
        }
        
        return {tokensLimpiados: tokensLimpiados};
    } catch (error) {
        console.error("❌ Error en limpieza de tokens:", error);
        throw error;
    }
});

// Nueva función: Notificar a todos cuando se registra un nuevo desaparecido
exports.sendNewMissingPersonNotification = onDocumentCreated(
    "missing_persons/{missingPersonId}",
    async (event) => {
        try {
            console.log("🚀 Iniciando notificación de nuevo caso de persona desaparecida");
            
            const missingPersonData = event.data.data();
            const missingPersonId = event.params.missingPersonId;
            
            console.log("👤 Nueva persona desaparecida ID:", missingPersonId);
            console.log("📋 Datos:", missingPersonData);
            
            // Obtener todos los tokens FCM de policías y ciudadanos
            const [policiasSnapshot, ciudadanosSnapshot] = await Promise.all([
                admin.firestore()
                    .collection("policias")
                    .where("fcmToken", "!=", null)
                    .get(),
                admin.firestore()
                    .collection("ciudadanos")
                    .where("fcmToken", "!=", null)
                    .get()
            ]);
            
            console.log("👮 Policías con tokens:", policiasSnapshot.size);
            console.log("👤 Ciudadanos con tokens:", ciudadanosSnapshot.size);
            
            // Recopilar todos los tokens válidos
            const allTokens = [];
            
            // Tokens de policías
            policiasSnapshot.forEach((doc) => {
                const policiaData = doc.data();
                const token = policiaData.fcmToken;
                
                if (token && typeof token === "string" && token.trim().length > 0) {
                    allTokens.push({
                        token: token.trim(),
                        userType: "police",
                        userId: doc.id,
                        name: `${policiaData.nombre || ""} ${policiaData.apellido || ""}`.trim()
                    });
                }
            });
            
            // Tokens de ciudadanos
            ciudadanosSnapshot.forEach((doc) => {
                const ciudadanoData = doc.data();
                const token = ciudadanoData.fcmToken;
                
                if (token && typeof token === "string" && token.trim().length > 0) {
                    allTokens.push({
                        token: token.trim(),
                        userType: "citizen",
                        userId: doc.id,
                        name: `${ciudadanoData.nombres || ""} ${ciudadanoData.apellidos || ""}`.trim()
                    });
                }
            });
            
            if (allTokens.length === 0) {
                console.log("❌ No hay tokens FCM válidos para enviar notificaciones");
                return null;
            }
            
            console.log("📱 Total de tokens válidos encontrados:", allTokens.length);
            
            // Preparar datos del mensaje (mejorado)
            const nombreCompleto = `${missingPersonData.nombres || ""} ${missingPersonData.apellidos || ""}`.trim();
            const edad = missingPersonData.edad || "Edad no especificada";
            const genero = missingPersonData.genero || "";
            const departamento = missingPersonData.departamento || "Departamento no especificado";
            const provincia = missingPersonData.provincia || "";
            const distrito = missingPersonData.distrito || "";
            const fechaDesaparicion = missingPersonData.fechaDesaparicion || "";
            const telefono = missingPersonData.telefono || "";
            const fechaRegistro = missingPersonData.fecha_registro || "";
            const rol = missingPersonData.rol || "";
            
            // Formatear ubicación
            let ubicacion = departamento;
            if (provincia) ubicacion += `, ${provincia}`;
            if (distrito) ubicacion += `, ${distrito}`;
            
            // Formatear fecha y hora actual
            const ahora = new Date();
            const fechaHora = ahora.toLocaleString("es-PE", {
                timeZone: "America/Lima",
                day: "2-digit",
                month: "2-digit",
                year: "numeric",
                hour: "2-digit",
                minute: "2-digit"
            });
            
            // Crear mensaje diferenciado para policías y ciudadanos
            const tokens = allTokens.map(tokenData => tokenData.token);
            
            // Mensaje para todos
            const message = {
                notification: {
                    title: "🚨 NUEVA PERSONA DESAPARECIDA",
                    body: `👤 ${nombreCompleto}${edad !== "Edad no especificada" ? ` (${edad} años)` : ""}\n📍 ${ubicacion}\n⚠️ Tu ayuda es importante para encontrarla`,
                    imageUrl: missingPersonData.photoUrl || null,
                },
                data: {
                    missingPersonId: missingPersonId,
                    type: "new_missing_person",
                    nombreCompleto: nombreCompleto,
                    nombres: missingPersonData.nombres || "",
                    apellidos: missingPersonData.apellidos || "",
                    edad: edad.toString(),
                    genero: genero,
                    departamento: departamento,
                    provincia: provincia,
                    distrito: distrito,
                    ubicacion: ubicacion,
                    fechaDesaparicion: fechaDesaparicion,
                    fechaRegistro: fechaRegistro,
                    telefono: telefono,
                    rol: rol,
                    fechaNotificacion: fechaHora,
                    photoUrl: missingPersonData.photoUrl || "",
                    descripcion: missingPersonData.descripcion || "",
                    circunstancias: missingPersonData.circunstancias || "",
                    vetado: missingPersonData.vetado || false,
                },
                android: {
                    notification: {
                        icon: "ic_launcher",
                        color: "#FF6B35",
                        channelId: "missing_person_alerts",
                        priority: "high",
                        defaultSound: true,
                        defaultVibrateTimings: true,
                        defaultLightSettings: true,
                        sticky: false,
                        localOnly: false,
                        tag: `missing_${missingPersonId}`,
                        clickAction: "FLUTTER_NOTIFICATION_CLICK",
                        style: {
                            type: "bigText",
                            bigText: `🆘 NUEVA PERSONA DESAPARECIDA\n\n👤 NOMBRE: ${nombreCompleto}\n🎂 EDAD: ${edad}${genero ? `\n⚧ GÉNERO: ${genero}` : ""}\n📍 UBICACIÓN: ${ubicacion}${fechaDesaparicion ? `\n📅 FECHA DESAPARICIÓN: ${fechaDesaparicion}` : ""}\n\n⚠️ Si tienes información sobre esta persona, contacta inmediatamente a las autoridades.\n\n🕐 Notificación enviada: ${fechaHora}`,
                            summaryText: `Caso reportado en ${departamento}`,
                        },
                    },
                    priority: "high",
                    ttl: 86400000, // 24 horas
                },
                apns: {
                    payload: {
                        aps: {
                            alert: {
                                title: "🚨 NUEVA PERSONA DESAPARECIDA",
                                subtitle: `${nombreCompleto} - ${ubicacion}`,
                                body: `${edad !== "Edad no especificada" ? `${edad} años` : ""}${genero ? ` - ${genero}` : ""}\n⚠️ Tu ayuda es importante`,
                            },
                            badge: 1,
                            sound: "default",
                            category: "MISSING_PERSON_CATEGORY",
                            threadId: `missing_person_alerts`,
                            interruptionLevel: "timeSensitive",
                        },
                    },
                    headers: {
                        "apns-priority": "10",
                        "apns-push-type": "alert",
                    },
                },
                webpush: {
                    notification: {
                        title: "🚨 ALERTA: PERSONA DESAPARECIDA",
                        body: `${nombreCompleto} (${departamento})`,
                        icon: "/icons/Icon-192.png",
                        badge: "/favicon.png",
                        image: missingPersonData.photoUrl || undefined,
                        tag: `case_${missingPersonId}`,
                        requireInteraction: true,
                        actions: [
                            { action: "open_case", title: "🔍 Ver Caso" }
                        ]
                    },
                    fcmOptions: {
                        link: "/"
                    }
                },
                tokens: tokens,
            };
            
            console.log("📤 Enviando notificación a todos los usuarios...");
            console.log("   📋 Título:", message.notification.title);
            console.log("   💬 Cuerpo:", message.notification.body);
            console.log("   👥 Destinatarios:", tokens.length);
            
            // Enviar notificación
            const response = await admin.messaging().sendMulticast(message);
            
            console.log("✅ Notificaciones enviadas:", response.successCount + "/" + tokens.length);
            
            if (response.failureCount > 0) {
                console.log("❌ Fallos:", response.failureCount);
                
                // Limpiar tokens inválidos
                const batch = admin.firestore().batch();
                let tokensLimpiados = 0;
                
                response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                        const invalidTokenData = allTokens[idx];
                        const collection = invalidTokenData.userType === "police" ? "policias" : "ciudadanos";
                        
                        console.log(`   ❌ Token inválido (${invalidTokenData.userType}):`, resp.error.message);
                        
                        // Marcar token para eliminación
                        batch.update(
                            admin.firestore().collection(collection).doc(invalidTokenData.userId),
                            {
                                fcmToken: admin.firestore.FieldValue.delete(),
                            }
                        );
                        tokensLimpiados++;
                    }
                });
                
                if (tokensLimpiados > 0) {
                    await batch.commit();
                    console.log("🧹 Tokens inválidos eliminados:", tokensLimpiados);
                }
            }
            
            // Registrar estadísticas de la notificación
            await admin.firestore()
                .collection("notification_stats")
                .add({
                    type: "new_missing_person",
                    missingPersonId: missingPersonId,
                    nombreCompleto: nombreCompleto,
                    totalEnviados: tokens.length,
                    exitosos: response.successCount,
                    fallidos: response.failureCount,
                    policias: policiasSnapshot.size,
                    ciudadanos: ciudadanosSnapshot.size,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    departamento: departamento,
                });
            
            return {
                success: true,
                totalEnviados: tokens.length,
                exitosos: response.successCount,
                fallidos: response.failureCount,
                policias: policiasSnapshot.size,
                ciudadanos: ciudadanosSnapshot.size,
            };
            
        } catch (error) {
            console.error("❌ Error enviando notificación de nueva persona desaparecida:", error);
            throw error;
        }
    }
);

/**
 * =============================================================================
 * MOTOR DE SINCRONIZACIÓN REAL PNP — TRIPLE CAPA (Capa 1: Cloud Function)
 * =============================================================================
 * Consulta la API JSON del portal oficial de la PNP, compara contra Firestore,
 * ingesta casos nuevos con fotos en Storage, y transiciona ubicados.
 * =============================================================================
 */

const PNP_API_URL = "https://desaparecidosenperu.policia.gob.pe/Desaparecidos/Buscar";
const PNP_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    "X-Requested-With": "XMLHttpRequest",
};

const STORAGE_BUCKET_NAME = "alerta-desaparecidos-pnp.firebasestorage.app";

const DEPARTAMENTOS_MAP = {
    "AMAZONAS": "AMAZONAS", "ANCASH": "ÁNCASH", "ÁNCASH": "ÁNCASH",
    "APURIMAC": "APURÍMAC", "APURÍMAC": "APURÍMAC", "AREQUIPA": "AREQUIPA",
    "AYACUCHO": "AYACUCHO", "CAJAMARCA": "CAJAMARCA", "CALLAO": "CALLAO",
    "CUSCO": "CUSCO", "CUZCO": "CUSCO", "HUANCAVELICA": "HUANCAVELICA",
    "HUANUCO": "HUÁNUCO", "HUÁNUCO": "HUÁNUCO", "ICA": "ICA",
    "JUNIN": "JUNÍN", "JUNÍN": "JUNÍN", "LA LIBERTAD": "LA LIBERTAD",
    "LAMBAYEQUE": "LAMBAYEQUE", "LIMA": "LIMA", "LORETO": "LORETO",
    "MADRE DE DIOS": "MADRE DE DIOS", "MOQUEGUA": "MOQUEGUA", "PASCO": "PASCO",
    "PIURA": "PIURA", "PUNO": "PUNO", "SAN MARTIN": "SAN MARTÍN",
    "SAN MARTÍN": "SAN MARTÍN", "TACNA": "TACNA", "TUMBES": "TUMBES", "UCAYALI": "UCAYALI",
};

const FEMALE_NAMES = new Set([
    "MARIA", "ANA", "LUZ", "FLOR", "ROSA", "CARMEN", "PILAR", "MILAGROS",
    "SOFIA", "VALERIA", "CAMILA", "LUCERO", "XIOMARA", "GENESIS",
    "MARIELA", "ANTONELLA", "MELISSA", "DAYANA", "STEFANY",
    "KATHERINE", "CINTHIA", "WENDY", "LESLIE", "DEYSI",
    "KIARA", "BRIANA", "ALISON", "NATHALY", "NATALIA",
    "NAYELI", "CIELO", "SCARLETT", "RUTH", "MIRIAM",
    "LIZ", "LIZETH", "YULISSA", "MERCEDES", "ROSARIO",
    "BEATRIZ", "ROCIO", "GLADYS", "MARITZA", "MARIBEL",
    "NICOLE", "ABIGAIL", "KAREN", "SHIRLEY", "EVELYN",
    "JAZMIN", "DIANA", "ANDREA", "ADRIANA", "PAOLA",
    "PATRICIA", "CLAUDIA", "GABRIELA", "DANIELA", "CAROLINA",
    "JIMENA", "VANESSA", "FATIMA", "JESSICA", "VERONICA",
    "MONICA", "CECILIA", "SILVIA", "SANDRA", "TERESA",
    "ELIZABETH", "VALENTINA", "ALEXANDRA", "KIMBERLY",
    "JENNIFER", "ZOE", "SUSANA", "ROXANA", "ESTRELLA",
    "BRENDA", "LADY", "ESMERALDA", "GUADALUPE", "ANGELICA",
]);

const MALE_NAMES = new Set([
    "CARLOS", "JUAN", "JOSE", "JORGE", "LUIS", "MIGUEL", "ANGEL", "VICTOR",
    "PEDRO", "MANUEL", "CESAR", "JESUS", "DAVID", "DANIEL", "DIEGO",
    "RAFAEL", "GABRIEL", "OSCAR", "JAVIER", "CRISTIAN", "CHRISTIAN",
    "ALEX", "ALEXANDER", "JHON", "EDGAR", "EDWIN", "WALTER",
    "RICARDO", "ROBERTO", "MARCOS", "SERGIO", "RODRIGO", "ALONSO",
    "SEBASTIAN", "LEONARDO", "ALEJANDRO", "ANTHONY", "PIERO",
    "FABRIZIO", "MATHIAS", "THIAGO", "LIAM", "DYLAN", "GAEL",
    "LUCAS", "MATEO", "JOAQUIN", "NICOLAS", "BRUNO",
    "FELIPE", "GONZALO", "JULIO", "MARIO", "MARTIN",
    "PABLO", "RAUL", "RUBEN", "SAMUEL", "TOMAS",
    "HECTOR", "HUGO", "FELIX", "ANDRES", "ANTONIO",
    "EDUARDO", "EMILIO", "ENRIQUE", "FERNANDO", "FRANCISCO",
    "GERARDO", "GUILLERMO", "GUSTAVO", "SANTIAGO", "KEVIN", "BRYAN",
]);

/**
 * Determina el sexo a partir del nombre completo.
 */
function determineSexo(fullName) {
    const tokens = fullName.split(/\s+/).filter((t) => t.length > 1).map((t) => t.toUpperCase());
    const givenNames = tokens.slice(0, 2);
    const fem = givenNames.filter((t) => FEMALE_NAMES.has(t));
    const male = givenNames.filter((t) => MALE_NAMES.has(t));
    if (male.length > 0 && fem.length === 0) return "MASCULINO";
    if (fem.length > 0 && male.length === 0) return "FEMENINO";
    if (givenNames.length > 0) {
        const first = givenNames[0];
        if (first.endsWith("A") && first !== "JOSHUA") return "FEMENINO";
        if (first.endsWith("O") || first.endsWith("E") || first.endsWith("R")) return "MASCULINO";
    }
    return "MASCULINO";
}

/**
 * Normaliza el departamento extraído del lugar del hecho.
 */
function normalizeDepartment(raw) {
    if (!raw) return "LIMA";
    const clean = raw.trim().toUpperCase();
    if (clean.startsWith("LIMA")) return "LIMA";
    for (const [k, v] of Object.entries(DEPARTAMENTOS_MAP)) {
        if (k === clean || clean.includes(k)) return v;
    }
    return clean;
}

/**
 * Parsea una fecha del portal PNP al formato ISO.
 */
function parsePnpDate(dateStr) {
    if (!dateStr) return null;
    const clean = dateStr.trim().toLowerCase();
    const isPM = clean.includes("p.m.") || clean.includes("pm");
    const isAM = clean.includes("a.m.") || clean.includes("am");
    const stripped = clean.replace(/[a-z.\s]/g, " ").trim();
    const parts = stripped.split(/[\s/:]+/);
    if (parts.length >= 3) {
        try {
            let [day, month, year] = [parseInt(parts[0]), parseInt(parts[1]), parseInt(parts[2])];
            let hour = parts.length > 3 ? parseInt(parts[3]) : 0;
            const minute = parts.length > 4 ? parseInt(parts[4]) : 0;
            const second = parts.length > 5 ? parseInt(parts[5]) : 0;
            if (isPM && hour < 12) hour += 12;
            if (isAM && hour === 12) hour = 0;
            const pad = (n) => String(n).padStart(2, "0");
            return `${year}-${pad(month)}-${pad(day)}T${pad(hour)}:${pad(minute)}:${pad(second)}Z`;
        } catch (e) {
            return null;
        }
    }
    return null;
}

/**
 * Genera keywords de búsqueda a partir de los campos del caso.
 */
function generateKeywords(name, lugar, dept) {
    const words = new Set();
    const raw = `${name} ${lugar || ""} ${dept || ""}`.toLowerCase();
    const clean = raw.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const tokens = [...raw.split(/[\s\-,./;:]+/), ...clean.split(/[\s\-,./;:]+/)];
    for (const t of tokens) {
        const trimmed = t.trim();
        if (trimmed.length >= 2) {
            words.add(trimmed);
            for (let l = 2; l <= Math.min(trimmed.length, 7); l++) {
                words.add(trimmed.substring(0, l));
            }
        }
    }
    return [...words].sort().slice(0, 80);
}

/**
 * Consulta la API del portal PNP con barrido alfabético para superar el límite de 200 del servidor.
 */
async function fetchPnpCases(tipo) {
    const itemsByDni = new Map();
    const alphabet = "abcdefghijklmnopqrstuvwxyz";

    for (const char of alphabet) {
        try {
            const body = `Nombre=${char}&Sexo=&Edad=&Nacionalidad=&Tipo=${tipo}`;
            const controller = new AbortController();
            const timeout = setTimeout(() => controller.abort(), 12000);

            const response = await fetch(PNP_API_URL, {
                method: "POST",
                headers: PNP_HEADERS,
                body: body,
                signal: controller.signal,
            });
            clearTimeout(timeout);

            if (response.ok) {
                const data = await response.json();
                for (const item of data) {
                    const dni = item.DNI;
                    if (dni && !itemsByDni.has(dni)) {
                        itemsByDni.set(dni, item);
                    }
                }
            }
        } catch (e) {
            // Continuar con la siguiente letra
            continue;
        }
    }

    return [...itemsByDni.values()];
}

/**
 * Descarga una imagen y la sube a Firebase Storage, retorna la URL pública.
 */
async function downloadAndUploadPhoto(imageUrl, storagePath) {
    if (!imageUrl) return null;

    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 20000);

        const response = await fetch(imageUrl, {
            headers: {"User-Agent": PNP_HEADERS["User-Agent"]},
            signal: controller.signal,
        });
        clearTimeout(timeout);

        if (!response.ok) return null;

        const buffer = Buffer.from(await response.arrayBuffer());
        if (buffer.length < 1000) return null;

        const bucket = admin.storage().bucket(STORAGE_BUCKET_NAME);
        const file = bucket.file(storagePath);
        const downloadToken = require("crypto").randomUUID();

        await file.save(buffer, {
            metadata: {
                contentType: "image/jpeg",
                metadata: {firebaseStorageDownloadTokens: downloadToken},
            },
        });

        const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${STORAGE_BUCKET_NAME}/o/${encodeURIComponent(storagePath)}?alt=media&token=${downloadToken}`;
        return publicUrl;
    } catch (e) {
        console.warn(`⚠️ Error subiendo foto ${storagePath}: ${e.message}`);
        return null;
    }
}

/**
 * Intenta descargar la imagen de la Nota de Alerta oficial del portal PNP.
 * El portal PNP muestra la nota en una página HTML, pero la imagen del afiche
 * se puede extraer directamente desde el HTML del detalle.
 * Descarga la imagen del afiche, la sube a Storage, retorna la URL pública.
 */
async function downloadNotaAlertaImage(dni, safeId) {
    try {
        // Intentar con endpoint de menores y adultos
        const endpoints = [
            `https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_menor?id=${dni}`,
            `https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_mujer?id=${dni}`,
        ];

        let detailHtml = null;
        let validUrl = null;

        for (const url of endpoints) {
            try {
                const controller = new AbortController();
                const timeout = setTimeout(() => controller.abort(), 12000);
                const response = await fetch(url, {
                    headers: PNP_HEADERS,
                    signal: controller.signal,
                });
                clearTimeout(timeout);

                if (response.ok) {
                    const html = await response.text();
                    if (html.includes("NOTA DE ALERTA") && html.includes("DATOS DE LA PERSONA DESAPARECIDA")) {
                        detailHtml = html;
                        validUrl = url;
                        break;
                    }
                }
            } catch (e) {
                continue;
            }
        }

        if (!detailHtml || !validUrl) {
            return {fichaUrl: null, detailUrl: null};
        }

        // Extraer imagen HD del afiche si existe en el HTML
        const fichaImgMatch = detailHtml.match(/src=["'](https:\/\/sistemas\.policia\.gob\.pe\/archivos\/[^"']+)["']/i);
        let fichaStorageUrl = null;

        if (fichaImgMatch && fichaImgMatch[1]) {
            const fichaImgUrl = fichaImgMatch[1];
            fichaStorageUrl = await downloadAndUploadPhoto(
                fichaImgUrl,
                `desaparecidos/fichas/${safeId}_nota.jpg`,
            );
        }

        return {fichaUrl: fichaStorageUrl, detailUrl: validUrl};
    } catch (e) {
        console.warn(`⚠️ Error procesando Nota de Alerta para ${safeId}: ${e.message}`);
        return {fichaUrl: null, detailUrl: null};
    }
}

/**
 * Construye el safe_id a partir del DNI codificado del portal PNP.
 */
function buildSafeId(dni) {
    return `pnp_${dni.replace(/[?&=%]/g, "_")}`;
}

/**
 * =============================================================================
 * MOTOR CENTRAL DE SINCRONIZACIÓN Y AUDITORÍA PNP (TRIPLE CAPA)
 * =============================================================================
 * Ejecuta el barrido alfabético en la API de la PNP, concilia casos nuevos y
 * ubicados, descarga imágenes y registra cada ejecución en `pnp_sync_history`.
 * =============================================================================
 */
async function executePnpSync(origen = "Cloud Function (Programada 4h)") {
    console.log(`🔍 [SYNC MOTOR] Iniciando ciclo de sincronización [Origen: ${origen}]...`);
    const startTime = Date.now();
    const stats = {
        nuevos: 0,
        ubicados_transicionados: 0,
        errores: 0,
        total_portal: 0,
        total_ubicados_portal: 0,
    };
    const nuevosNombres = [];
    const transicionadosNombres = [];

    try {
        // ─── FASE 0: Obtener IDs existentes en Firestore ───
        console.log("📦 Obteniendo casos existentes en Firestore...");
        const existingIds = new Set();
        const existingSnap = await admin.firestore().collection("desaparecidos").select().get();
        existingSnap.forEach((doc) => existingIds.add(doc.id));
        console.log(`   📋 ${existingIds.size} casos ya registrados en Firestore.`);

        // ─── FASE 1: Obtener casos activos del portal PNP (Menores + Adultos) ───
        console.log("📡 Consultando portal PNP con barrido alfabético...");
        const [menores, adultos] = await Promise.all([
            fetchPnpCases(1),
            fetchPnpCases(2),
        ]);
        console.log(`   ⚡ Portal: ${menores.length} menores + ${adultos.length} adultos`);

        // Unificar por DNI (sin duplicados entre categorías)
        const allActiveByDni = new Map();
        for (const c of menores) {
            if (c.DNI) allActiveByDni.set(c.DNI, {...c, _tipo: 1, _cat: "MENORES"});
        }
        for (const c of adultos) {
            if (c.DNI && !allActiveByDni.has(c.DNI)) {
                allActiveByDni.set(c.DNI, {...c, _tipo: 2, _cat: "ADULTOS"});
            }
        }
        stats.total_portal = allActiveByDni.size;

        // ─── FASE 2: Identificar e ingestar casos nuevos ───
        const nuevos = [];
        for (const [dni, caso] of allActiveByDni) {
            const safeId = buildSafeId(dni);
            if (!existingIds.has(safeId)) {
                nuevos.push({safeId, dni, caso});
            }
        }
        console.log(`🆕 Se identificaron ${nuevos.length} casos NUEVOS para ingestar.`);

        // Procesar en lotes de 5 (reducido para dar tiempo a descarga de notas)
        const BATCH_SIZE = 5;
        for (let i = 0; i < nuevos.length; i += BATCH_SIZE) {
            const batch = nuevos.slice(i, i + BATCH_SIZE);
            const promises = batch.map(async ({safeId, dni, caso}) => {
                try {
                    const nombreCompleto = (caso.NOMBRE_COMPLETO || "").trim().toUpperCase();
                    const partsName = nombreCompleto.split(/\s+/);
                    const nombres = partsName.slice(0, Math.ceil(partsName.length / 2)).join(" ");
                    const apellidos = partsName.slice(Math.ceil(partsName.length / 2)).join(" ");

                    // Descargar y subir foto a Storage
                    const photoUrl = caso.IMAGEN || caso.RUTA_IMAGEN;
                    const storagePhotoUrl = await downloadAndUploadPhoto(
                        photoUrl,
                        `desaparecidos/fotos/${safeId}.jpg`,
                    );

                    if (!storagePhotoUrl) {
                        console.warn(`   ⚠️ Sin foto para ${safeId}, omitido.`);
                        stats.errores++;
                        return;
                    }

                    // 📄 Descargar Nota de Alerta oficial PNP
                    let fichaUrl = "";
                    let detailUrl = "";
                    try {
                        const notaResult = await downloadNotaAlertaImage(dni, safeId);
                        fichaUrl = notaResult.fichaUrl || "";
                        detailUrl = notaResult.detailUrl || "";
                        if (fichaUrl) {
                            console.log(`   📄 [NOTA] Nota de Alerta descargada para ${safeId}`);
                        } else if (detailUrl) {
                            console.log(`   ℹ️ [NOTA] Página de detalle hallada pero sin imagen HD para ${safeId} (se marcará para auto-heal)`);
                        }
                    } catch (notaErr) {
                        console.warn(`   ⚠️ Error descargando Nota de Alerta para ${safeId}: ${notaErr.message}`);
                    }

                    // Parsear lugar geográfico
                    const lugar = (caso.LUGAR_DESAPARICION || "").trim();
                    const lugarParts = lugar.split("-").map((p) => p.trim()).filter(Boolean);
                    const departamento = normalizeDepartment(lugarParts[0] || "");
                    const provincia = (lugarParts[1] || departamento).toUpperCase();
                    const distrito = (lugarParts[2] || provincia).toUpperCase();

                    const fechaDesaparicion = parsePnpDate(caso.FECHA_DESAPARICION) ||
                        new Date().toISOString();
                    const exp = new Date(new Date(fechaDesaparicion).getTime() + 240 * 86400000);

                    const sexo = determineSexo(nombreCompleto);
                    const keywords = generateKeywords(nombreCompleto, lugar, departamento);

                    const vestimenta = (caso.VESTIMENTA || "").trim();
                    const detalles = [
                        caso.EDAD_PERSONA ? `Edad: ${caso.EDAD_PERSONA} años` : "",
                        vestimenta ? `Vestimenta: ${vestimenta}` : "",
                        `Lugar: ${lugar}`,
                    ].filter(Boolean).join(". ");

                    const caseData = {
                        nombres: nombres,
                        apellidos: apellidos,
                        nombre: nombreCompleto,
                        sexo: sexo,
                        foto_url: storagePhotoUrl,
                        imagen_ficha_url: fichaUrl,
                        detail_url_pnp: detailUrl,
                        unidad_a_cargo: "DIVINPD_PNP",
                        departamento: departamento,
                        provincia: provincia,
                        distrito: distrito,
                        telefono_contacto: "01 418-4030",
                        detalles_adicionales: detalles || "Caso registrado desde el portal oficial PNP.",
                        fecha_desaparicion: admin.firestore.Timestamp.fromDate(new Date(fechaDesaparicion)),
                        fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
                        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
                        fecha_expiracion: admin.firestore.Timestamp.fromDate(exp),
                        estado: "activo",
                        safe_id: safeId,
                        keywords: keywords,
                        origen_datos: "PNP_CLOUD_FUNCTION_SYNC",
                        necesita_nota_alerta: fichaUrl ? false : true,
                    };

                    await admin.firestore().collection("desaparecidos").doc(safeId).set(caseData);
                    stats.nuevos++;
                    nuevosNombres.push(`${nombreCompleto} (${departamento})`);
                    console.log(`   ✅ [NUEVO] ${nombreCompleto} (${safeId}) | Nota: ${fichaUrl ? "SÍ" : "PENDIENTE"}`);
                } catch (e) {
                    console.error(`   ❌ Error procesando ${safeId}: ${e.message}`);
                    stats.errores++;
                }
            });
            await Promise.all(promises);
        }

        // ─── FASE 2.5: AUTO-HEAL — Reparar casos existentes sin Nota de Alerta ───
        console.log("🩹 [AUTO-HEAL] Buscando casos existentes sin Nota de Alerta...");
        try {
            const sinNotaSnap = await admin.firestore()
                .collection("desaparecidos")
                .where("necesita_nota_alerta", "==", true)
                .where("estado", "==", "activo")
                .limit(20)
                .get();

            let healedCount = 0;
            for (const doc of sinNotaSnap.docs) {
                const data = doc.data();
                const docDni = (data.safe_id || doc.id).replace("pnp_", "");
                try {
                    const notaResult = await downloadNotaAlertaImage(docDni, doc.id);
                    if (notaResult.fichaUrl) {
                        await doc.ref.update({
                            imagen_ficha_url: notaResult.fichaUrl,
                            detail_url_pnp: notaResult.detailUrl || "",
                            necesita_nota_alerta: false,
                            fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
                        });
                        healedCount++;
                        console.log(`   🩹 [HEAL] Nota de Alerta vinculada a ${doc.id}`);
                    }
                } catch (e) {
                    // Continuar con el siguiente
                }
            }
            if (healedCount > 0) {
                console.log(`   ✅ ${healedCount} casos reparados con Nota de Alerta.`);
            } else if (sinNotaSnap.size === 0) {
                console.log("   ✅ Todos los casos tienen su Nota de Alerta.");
            } else {
                console.log(`   ⚠️ ${sinNotaSnap.size} casos pendientes, no se encontraron imágenes HD aún.`);
            }
        } catch (healErr) {
            console.warn(`   ⚠️ Error en auto-heal: ${healErr.message}`);
        }

        // ─── FASE 3: Conciliación de UBICADOS ───
        console.log("🔄 [FASE UBICADOS] Consultando sección oficial de personas ubicadas...");
        const ubicados = await fetchPnpCases(4);
        stats.total_ubicados_portal = ubicados.length;
        console.log(`   📡 Portal reporta ${ubicados.length} personas UBICADAS.`);

        const ubicadosMap = new Map();
        for (const u of ubicados) {
            if (u.DNI) {
                const sId = buildSafeId(u.DNI);
                ubicadosMap.set(sId, (u.NOMBRE_COMPLETO || sId).trim().toUpperCase());
            }
        }

        // Transicionar casos activos que ahora están en UBICADOS
        const activosSnap = await admin.firestore()
            .collection("desaparecidos")
            .where("estado", "==", "activo")
            .get();

        const transitionBatch = admin.firestore().batch();
        let batchCount = 0;

        activosSnap.forEach((doc) => {
            if (ubicadosMap.has(doc.id)) {
                const now = new Date();
                const exp = new Date(now.getTime() + 240 * 86400000);
                const nombrePersona = doc.data().nombre || ubicadosMap.get(doc.id) || doc.id;

                transitionBatch.update(doc.ref, {
                    estado: "encontrado",
                    fecha_aparicion: admin.firestore.FieldValue.serverTimestamp(),
                    fecha_expiracion: admin.firestore.Timestamp.fromDate(exp),
                    origen_ubicacion: `Sincronización Automática Portal PNP (${origen})`,
                    fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
                });
                batchCount++;
                stats.ubicados_transicionados++;
                transicionadosNombres.push(nombrePersona);
                console.log(`   🎉 [UBICADA] ${doc.id} -> ${nombrePersona} a encontrado`);
            }
        });

        if (batchCount > 0) {
            await transitionBatch.commit();
            console.log(`   ✅ ${batchCount} casos transicionados a ENCONTRADO.`);
        }

        // ─── FASE 4: Guardar Auditoría en pnp_sync_history ───
        const elapsed = parseFloat(((Date.now() - startTime) / 1000).toFixed(1));
        const totalFirestore = existingIds.size + stats.nuevos;
        const mensajeExito = `Sync completado: +${stats.nuevos} nuevos, ${stats.ubicados_transicionados} pasaron a ubicados, portal registra ${stats.total_ubicados_portal} ubicados en total (${elapsed}s).`;

        const historyDoc = {
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            fecha_hora: new Date().toLocaleString("es-PE", {timeZone: "America/Lima"}),
            origen: origen,
            estado: "exitoso",
            casos_nuevos: stats.nuevos,
            total_ubicados_portal: stats.total_ubicados_portal,
            desaparecidos_a_ubicados: stats.ubicados_transicionados,
            total_portal_escaneados: stats.total_portal,
            total_firestore_actual: totalFirestore,
            duracion_segundos: elapsed,
            errores: stats.errores,
            nombres_transicionados: transicionadosNombres.slice(0, 50),
            nombres_nuevos: nuevosNombres.slice(0, 50),
            mensaje: mensajeExito,
        };

        const logRef = await admin.firestore().collection("pnp_sync_history").add(historyDoc);

        // ─── FASE 5: Actualizar system_status/sync_pnp ───
        await admin.firestore().collection("system_status").doc("sync_pnp").set({
            ultima_sincronizacion: admin.firestore.FieldValue.serverTimestamp(),
            fecha_hora: new Date().toLocaleString("es-PE", {timeZone: "America/Lima"}),
            estado: "al_dia",
            origen: origen,
            casos_nuevos: stats.nuevos,
            total_ubicados_portal: stats.total_ubicados_portal,
            desaparecidos_a_ubicados: stats.ubicados_transicionados,
            total_portal_escaneados: stats.total_portal,
            total_firestore_actual: totalFirestore,
            duracion_segundos: elapsed,
            errores: stats.errores,
            ultimo_log_id: logRef.id,
            mensaje: mensajeExito,
        }, {merge: true});

        console.log(`\n🎉 [SYNC EXITOSO] +${stats.nuevos} nuevos | ${stats.ubicados_transicionados} a ubicados | ${stats.total_ubicados_portal} ubicados PNP | ${elapsed}s`);

        // Disparar runner de captura HD de Notas de Alerta con Chrome en GitHub Actions si hay casos nuevos
        if (stats.nuevos > 0) {
            await triggerGitHubFichaWorkflow(stats.nuevos);
        }

        return {success: true, stats, logId: logRef.id, elapsed};
    } catch (error) {
        console.error("❌ Error crítico en motor de sincronización PNP:", error.message);
        const elapsed = parseFloat(((Date.now() - startTime) / 1000).toFixed(1));

        // Registrar en historial como error
        await admin.firestore().collection("pnp_sync_history").add({
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            fecha_hora: new Date().toLocaleString("es-PE", {timeZone: "America/Lima"}),
            origen: origen,
            estado: "error",
            casos_nuevos: 0,
            total_ubicados_portal: 0,
            desaparecidos_a_ubicados: 0,
            total_portal_escaneados: 0,
            total_firestore_actual: 0,
            duracion_segundos: elapsed,
            errores: 1,
            nombres_transicionados: [],
            nombres_nuevos: [],
            mensaje: `Falla en sincronización: ${error.message}`,
        });

        // Registrar fallo en status
        await admin.firestore().collection("system_status").doc("sync_pnp").set({
            estado: "error",
            ultimo_error: String(error.message).substring(0, 500),
            ultima_falla: admin.firestore.FieldValue.serverTimestamp(),
            origen: origen,
        }, {merge: true});

        // Intentar activar failover de GitHub Actions si aplica
        await triggerGitHubFailover(error.message);

        return {success: false, error: error.message};
    }
}

/**
 * Dispara el webhook de contingencia en GitHub Actions ante un fallo de Cloud Functions.
 */
async function triggerGitHubFailover(errorMessage) {
    const githubToken = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
    const githubRepo = process.env.GITHUB_REPO || "shamirdhc/alerta_desaparecidos";

    console.log(`⚠️ Activando Failover: Notificando a GitHub Actions (${githubRepo})...`);

    if (!githubToken) {
        console.warn("⚠️ GITHUB_TOKEN no configurado. GitHub Actions se activará mediante su schedule pasivo (cada 6h).");
        return false;
    }

    try {
        const response = await fetch(`https://api.github.com/repos/${githubRepo}/dispatches`, {
            method: "POST",
            headers: {
                "Accept": "application/vnd.github.v3+json",
                "Authorization": `Bearer ${githubToken}`,
                "User-Agent": "Firebase-Cloud-Function-Failover",
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                event_type: "pnp_sync_failover",
                client_payload: {
                    error: String(errorMessage),
                    timestamp: new Date().toISOString(),
                },
            }),
        });

        if (response.ok) {
            console.log("✅ Webhook de GitHub Actions activado con éxito.");
            return true;
        } else {
            console.error(`❌ Error en respuesta de GitHub API: ${response.status} ${response.statusText}`);
            return false;
        }
    } catch (e) {
        console.error("❌ Excepción al invocar GitHub Dispatch API:", e);
        return false;
    }
}

/**
 * Dispara el runner de captura HD de Notas de Alerta en GitHub Actions con Chrome headless.
 */
async function triggerGitHubFichaWorkflow(nuevosCount) {
    const githubToken = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
    const githubRepo = process.env.GITHUB_REPO || "shamirdhc/alerta_desaparecidos";

    console.log(`📄 Disparando GitHub Actions para captura HD de Notas de Alerta (${nuevosCount} casos)...`);

    if (!githubToken) {
        console.warn("⚠️ GITHUB_TOKEN no configurado en entorno. GitHub Actions se ejecutará vía cron para generar las notas.");
        return false;
    }

    try {
        const response = await fetch(`https://api.github.com/repos/${githubRepo}/dispatches`, {
            method: "POST",
            headers: {
                "Accept": "application/vnd.github.v3+json",
                "Authorization": `Bearer ${githubToken}`,
                "User-Agent": "Firebase-Cloud-Function-Fichas",
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                event_type: "pnp_sync_fichas",
                client_payload: {
                    nuevos: nuevosCount,
                    timestamp: new Date().toISOString(),
                },
            }),
        });

        if (response.ok) {
            console.log("✅ Webhook de Notas de Alerta enviado a GitHub Actions.");
            return true;
        } else {
            console.warn(`⚠️ Error en respuesta de GitHub API: ${response.status}`);
            return false;
        }
    } catch (e) {
        console.warn("⚠️ Excepción al invocar GitHub Dispatch para fichas:", e.message);
        return false;
    }
}

/**
 * 1. SINCRONIZACIÓN AUTOMÁTICA PROGRAMADA (cada 4 horas)
 */
exports.syncPnpCasesScheduled = onSchedule(
    {
        schedule: "every 4 hours",
        timeZone: "America/Lima",
        retryCount: 1,
        memory: "1GiB",
        timeoutSeconds: 540,
    },
    async (event) => {
        return await executePnpSync("Cloud Function (Programada 4h)");
    },
);

/**
 * 2. ENDPOINT CALLABLE para App Policial y SuperAdmin
 */
exports.triggerManualPnpSync = onCall(
    {
        memory: "1GiB",
        timeoutSeconds: 540,
    },
    async (request) => {
        if (!request.auth) {
            throw new Error("Usuario no autenticado");
        }
        console.log("👮 Solicitud manual de sincronización recibida de:", request.auth.uid);
        return await executePnpSync(`Manual App (${request.auth.uid})`);
    },
);

/**
 * 3. ENDPOINT HTTP REST para disparar y monitorear desde navegador o panel SuperAdmin
 */
exports.apiSyncPnp = onRequest(
    {
        memory: "1GiB",
        timeoutSeconds: 540,
        cors: true,
    },
    async (req, res) => {
        try {
            console.log("🌐 Solicitud HTTP de sincronización recibida");
            const origen = req.query.origen || req.body?.origen || "HTTP SuperAdmin Web";
            const result = await executePnpSync(origen);
            res.status(200).json(result);
        } catch (e) {
            res.status(500).json({success: false, error: e.message});
        }
    },
);


