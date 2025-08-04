const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
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

// ... existing code ...
