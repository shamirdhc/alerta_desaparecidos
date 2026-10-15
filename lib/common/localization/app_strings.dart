import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';

class AppStrings {
  final bool isQuechua;

  AppStrings(this.isQuechua);

  factory AppStrings.of(BuildContext context) {
    final langService = Provider.of<LanguageService>(context, listen: true);
    return AppStrings(langService.isQuechua);
  }

  static String tr(BuildContext context, {required String es, required String qu}) {
    final isQ = Provider.of<LanguageService>(context, listen: false).isQuechua;
    return isQ ? qu : es;
  }

  // --- PLATAFORMA CIUDADANA Y LOGIN ---
  String get officialPnp => isQuechua ? 'CHINKASQAKUNAMANTA LLIKACHAW' : 'ALERTA DESAPARECIDOS';
  String get loginGreeting => isQuechua ? 'Allinllachu! Akllay simiykita' : 'Bienvenido, selecciona tu idioma';
  String get loginTitle => isQuechua ? 'Chinkasqa Runakunamanta Willakuy' : 'Alerta de Desapariciones';
  String get loginSubtitle => isQuechua
      ? 'Yaykuy willakunaykipaq, yanapanaykipaq hinaspa chinkasqakunata maskanaykipaq.'
      : 'Accede para colaborar, brindar pistas y consultar casos de personas desaparecidas en el Perú.';
  String get loginWithGoogle => isQuechua ? 'Google nisqawan yaykuy' : 'Continuar con Google';
  String get citizenAccess => isQuechua ? 'Llaqtamasi Yaykuy' : 'Acceso Ciudadano Seguro';
  String get freeService => isQuechua ? 'Manam qullqipaqchu • 24/7 llapanchikpaq' : 'Plataforma Ciudadana Gratuita • 24/7 a Nivel Nacional';

  // --- NAVEGACIÓN Y TABS ---
  String get tabInicio => isQuechua ? 'Qallariy' : 'Inicio';
  String get tabDesaparecidos => isQuechua ? 'Chinkasqakuna' : 'Desaparecidos';
  String get tabUbicados => isQuechua ? 'Tarisqakuna' : 'Ubicados';
  String get tabBuscarComisaria => isQuechua ? 'Kumisariyata Maskay' : 'Buscar Comisaría';
  String get tabReportar => isQuechua ? 'Willakuy' : 'Reportar';
  String get tabVideos => isQuechua ? 'Yachachikuy Videokuna' : 'Videos Educativos';
  String get tabAgendaEmergencia => isQuechua ? 'Llakipi Qayanapaq' : 'Agenda de Emergencia';
  String get drawerTitle => isQuechua ? 'Llaqtamasi Sistema' : 'Menú Ciudadano';

  // --- CASOS Y ESTADOS ---
  String get statusDesaparecido => isQuechua ? 'CHINKASQA' : 'DESAPARECIDO';
  String get statusUbicado => isQuechua ? 'TARISQA' : 'UBICADO';
  String get ageYears => isQuechua ? 'watayuq' : 'años';
  String get searchHint => isQuechua ? 'Sutipi maskay...' : 'Buscar por nombre o DNI...';
  String get allProvinces => isQuechua ? 'Llapantinkuna' : 'Todas las provincias';
  String get filterByProvince => isQuechua ? 'Provinciapi akllay' : 'Filtrar por provincia';
  String get noCasesFound => isQuechua ? 'Manam tarisqachu' : 'No se encontraron registros';
  String get recompensa => isQuechua ? 'Suñay' : 'Recompensa';

  // --- MENÚ LATERAL (DRAWER) Y SECCIONES ---
  String get sectionSearch => isQuechua ? 'MASKAY HINASPA QHAWAY' : 'BÚSQUEDA Y MONITOREO';
  String get sectionAttention => isQuechua ? 'YANAPAKUY HINASPA WILLAKUY' : 'ATENCIÓN Y DENUNCIAS';
  String get sectionCommunity => isQuechua ? 'WILLAYKUNA HINASPA LLAQTA' : 'INFORMACIÓN Y COMUNIDAD';
  String get sectionPreferences => isQuechua ? 'ALLICHAYKUNA' : 'PREFERENCIAS';

  String get menuMissingPersons => isQuechua ? 'Chinkasqa Runakuna' : 'Personas Desaparecidas';
  String get menuFoundPersons => isQuechua ? 'Tarisqa Runakuna' : 'Personas Encontradas';
  String get menuReport => isQuechua ? 'Chinkasqata Willakuy' : 'Reportar Desaparición';
  String get menuFindStation => isQuechua ? 'Kumisariyata Maskay' : 'Buscar Mi Comisaría';
  String get menuStationDirectory => isQuechua ? 'Kumisariyakunapa Chawpin' : 'Agenda de Comisarías';
  String get menuCem => isQuechua ? 'CEM Directoriu (Warmi)' : 'Directorio CEM (Mujer)';
  String get menuSuggestions => isQuechua ? 'Yuyaychaykuna' : 'Sugerencias';
  String get menuGuides => isQuechua ? 'Yachachikuy Videokuna' : 'Guías Educativas';
  String get menuAbout => isQuechua ? 'Kaymanta' : 'Acerca de';
  String get menuLogout => isQuechua ? 'Lluqsiy' : 'Cerrar Sesión';
  String get logoutConfirmTitle => isQuechua ? '¿Chiqaqtachu lluqsiyta munanki?' : '¿Estás seguro de que quieres cerrar sesión?';
  String get logoutConfirmMessage => isQuechua ? 'Kaywanqa qallariymanmi kutinki.' : 'Esto te llevará de vuelta a la pantalla de bienvenida.';
  String get badgeUrgente => isQuechua ? 'UTQAY' : 'URGENTE';
  String get badgeASalvo => isQuechua ? 'ALLINLLA' : 'A SALVO';
  String get lightMode => isQuechua ? 'Kanchay Modo' : 'Modo Claro';
  String get darkMode => isQuechua ? 'Laqha Modo' : 'Modo Oscuro';

  // --- ACCIONES Y MAPA ---
  String get updateGps => isQuechua ? 'GPS Musuqyachiy' : 'Actualizar GPS';
  String get route => isQuechua ? 'Ñan' : 'Ruta';
  String get turns => isQuechua ? 'Giros' : 'Giros';
  String get auto => isQuechua ? 'Carropi' : 'Auto';
  String get aPie => isQuechua ? 'Chakiwan' : 'A pie';
  String get call105 => isQuechua ? '105 Qayay' : 'Llamar 105';
  String get call114 => isQuechua ? '114 Llakipi Qayay' : 'Llamar 114';
  String get share => isQuechua ? 'Aypuy' : 'Compartir';
  String get back => isQuechua ? 'Kutiy' : 'Volver';
  String get cancel => isQuechua ? 'Tatiy' : 'Cancelar';
  String get confirm => isQuechua ? 'Allinmi' : 'Aceptar';
  String get retry => isQuechua ? 'Kutipay' : 'Reintentar';
  String get loading => isQuechua ? 'Suyaykuy...' : 'Cargando...';

  // --- WELCOME SCREEN ---
  String get systemEarlyWarning => isQuechua ? 'LLAPANCHIKPAQ UTQAY ALERTA' : 'PLATAFORMA CIUDADANA DE ALERTA';
  String get welcomeTitle => isQuechua ? 'Chinkasqakuna Alerta' : 'Alerta Desaparecidos';
  String get welcomeSubtitle => isQuechua
      ? 'Perú suyuntinpi chinkasqa runakunata utqaylla maskanapaq willanapaq ima.'
      : 'Red ciudadana y colaborativa de búsqueda y reporte inmediato de personas desaparecidas.';
  String get welcomePolice => isQuechua ? 'Chinkasqa Runakunata Maskay' : 'Búsqueda de Personas Desaparecidas';
  String get enterSystem => isQuechua ? 'Yaykuy Sistemaman' : 'Ingresar a la Plataforma';
  String get institutionalInfo => isQuechua ? 'Sistemamanta Willakuy' : 'Acerca de la Plataforma';
  String get verifyingSession => isQuechua ? 'Sesionta qhawachkan...' : 'Verificando sesión segura...';
  String get emergency114and105 => isQuechua ? '114 Utqay Qayana • 105 Central' : 'Líneas de Ayuda: 114 Desaparecidos • 105 Central PNP';
  String get directionTrata => 'Puente Ciudadano de Búsqueda y Apoyo';

  // --- CITIZEN DASHBOARD ---
  String get activeNationalNetwork => isQuechua ? 'Perú Suyuntin Llikacha' : 'Red Nacional Activa';
  String get welcomeGreeting => isQuechua ? 'Allinllachu,' : 'Bienvenido/a,';
  String get central114Pnp => isQuechua ? 'Central 114 PNP' : 'Central 114 PNP';
  String get emergencyLine114Desc => isQuechua ? 'Utqay qayana hinaspa chinkasqa runakuna' : 'Línea de emergencia y personas desaparecidas';
  String get callAction => isQuechua ? 'Qayay' : 'Llamar';
  String get servicesAndQueries => isQuechua ? 'SERVICIOS Y CONSULTAS' : 'SERVICIOS Y CONSULTAS';
  String get modulesCount => isQuechua ? '8 Módulokuna' : '8 Módulos';

  // --- FILTROS Y ESTADOS VACÍOS ---
  String myRegionLabel(String depto) => isQuechua ? 'Regioniypi ($depto)' : 'Mi Región ($depto)';
  String myDeptoFilter(String depto) => isQuechua ? '📍 Regioniypi ($depto)' : '📍 Mi Depto ($depto)';
  String get noFoundPersonsFound => isQuechua ? 'Manam tarisqachu runakuna kanchu' : 'No se encontraron personas ubicadas';
  String get noRecordsInDept => isQuechua ? 'Manaraqmi kay departamentopi willakuykuna kanchu.' : 'No hay registros en este departamento aún.';
  String get noActiveCasesFound => isQuechua ? 'Manam chinkasqa runakuna kanchu' : 'No se encontraron casos activos';
  String get noActiveCasesFilter => isQuechua ? 'Manaraqmi kaypi willakuykuna kanchu.' : 'No hay registros que coincidan con la búsqueda o filtro seleccionado.';

  // --- DENUNCIA SEGURA (REPORT SCREEN) ---
  String get denunciaSeguraTitle => isQuechua ? 'AMACHASQA WILLAKUY' : 'DENUNCIA SEGURA';
  String get denunciaSeguraDesc => isQuechua
      ? 'Sichus pipas chinkaruptinqa, utqayllam willana. Qatiy kay ñanninchikta allinta willakunaykipaq.'
      : 'Si una persona ha desaparecido, es crucial actuar rápidamente. Sigue nuestra guía paso a paso para reportar de manera efectiva.';
  String get denunciaEmergenciaTitle => isQuechua ? 'Utqay Willakuy' : 'Denuncia de Emergencia';
  String get denunciaEmergenciaDesc => isQuechua ? 'Kunanpacha utqay kaptinqa, kaykunaman qayay:' : 'Si es una emergencia inmediata, contacta directamente:';
  String get linea114Title => isQuechua ? '114 Qayana' : 'Línea 114';
  String get linea114Subtitle => isQuechua ? 'PNP directa qayana' : 'Línea directa PNP';
  String get whatsappTitle => 'WhatsApp';
  String get whatsappSubtitle => isQuechua ? 'Utqay willay' : 'Mensaje rápido';
  String get tutorialStepByStep => isQuechua ? 'Yachay Ñan (Paso a Paso)' : 'Tutorial Paso a Paso';
  String get tutorialStepByStepDesc => isQuechua ? 'Lliw qhaway willakunaykipaq' : 'Guía visual completa para denunciar';
  String get educationalVideosAction => isQuechua ? 'Yachachikuy Videokuna' : 'Ver Videos Educativos';
  String get educationalVideosActionDesc => isQuechua ? 'Videokunawan yachay' : 'Aprende con contenido visual';
  String get pnpPortalTitle => isQuechua ? 'PNP Oficial Portal' : 'Portal Oficial PNP';
  String get pnpPortalSubtitle => isQuechua ? 'Perú Suyupi Chinkasqa Runakunapa Registron' : 'Registro Nacional de Personas Desaparecidas';
  String get pnpPortalDesc => isQuechua
      ? 'Oficial registrota qhaway chinkasqa runakunata maskanapaq según Decreto Legislativo N° 1428.'
      : 'Consulta el registro oficial y accede a herramientas especializadas para la búsqueda de personas desaparecidas según el Decreto Legislativo N° 1428.';
  String get pnpPortalSearchButton => isQuechua ? 'Maskana Portal' : 'Portal de Búsqueda';
  String get securityNotice => isQuechua
      ? 'Willakusqaykiqa amachasqam, manam pimanpas willakunchu'
      : 'Tu información está protegida y será tratada con total confidencialidad';

  // --- TARJETAS Y DETALLES DE PERSONAS (DESAPARECIDAS Y ENCONTRADAS) ---
  String get caseDetailsTitle => isQuechua ? 'Runapa Willakuynin' : 'Detalles del Caso';
  String get disappearanceDateLabel => isQuechua ? 'Chinkasqan P’unchaw' : 'Fecha de desaparición';
  String get lastSeenLocationLabel => isQuechua ? 'Qhipa rikusqa cheqas' : 'Lugar de última vista';
  String get clothingLabel => isQuechua ? 'Pacha churakusqan' : 'Vestimenta';
  String get physicalTraitsLabel => isQuechua ? 'Uya kurku riqsinapaq' : 'Características físicas';
  String get heightLabel => isQuechua ? 'Sayaynin' : 'Estatura';
  String get complexionLabel => isQuechua ? 'Kurkun' : 'Contextura';
  String get eyesLabel => isQuechua ? 'Ñawinkuna' : 'Ojos';
  String get hairLabel => isQuechua ? 'Chukchan' : 'Cabello';
  String get provideClueAction => isQuechua ? 'Pistata quy (Pakasqa)' : 'Aportar Pista Confidencial';
  String get sharePosterAction => isQuechua ? 'Aficheta Aypuy' : 'Compartir Afiche Oficial';
  String get downloadPdfAction => isQuechua ? 'PDF Uraykachiy' : 'Descargar Ficha PDF';
  String get call114FreeAction => isQuechua ? '114-man Qayay (Gratis)' : 'Llamar al 114 (Gratuito)';
  String get confidentialClueTitle => isQuechua ? 'Pakasqa Pista Quy' : 'Aporte de Pista Confidencial';
  String get clueDescriptionHint => isQuechua
      ? 'Qillqay imatachus yachanki (maypi rikurqanki, ima horata)...'
      : 'Escribe cualquier dato que ayude a la ubicación (dónde lo viste, fecha, hora)...';
  String get sendClueAction => isQuechua ? 'Pistata Kachay' : 'Enviar Información Confidencial';
  String get caseResolvedBanner => isQuechua ? 'TARISQAÑA • FAMILIANWANÑA KASHAN' : 'CASO RESUELTO • PERSONA A SALVO';
  String get caseActiveBanner => isQuechua ? 'URGENTE • UTQAYLLA MASKANA' : 'CASO ACTIVO • BÚSQUEDA NACIONAL';
  String get amberAlertBadge => isQuechua ? '🔴 ALERTA AMBER PERÚ' : '🔴 ALERTA AMBER PERÚ';

  // --- BUSCAR MI COMISARÍA, DIRECTORIO SEGURO (PNP & CEM) ---
  String get centralAuxilioTitle => isQuechua ? 'Yanapakuy Huñu 360°' : 'Central de Auxilio 360°';
  String get buscarComisariaTitle => isQuechua ? 'Kumisariya Maskhay' : 'Buscar Mi Comisaría';
  String get buscarComisariaShort => isQuechua ? 'Kumisariya' : 'Comisaría';
  String get directorioSeguroTitle => isQuechua ? 'Kallpachasqa Directorio' : 'Directorio Seguro';
  String get directorioSeguroShort => isQuechua ? 'Directorio' : 'Directorio';
  String get agendaPolicialTitle => isQuechua ? 'Polisiyakuna Agenda' : 'Agenda Policial';
  String get centralAuxilioSubtitle => isQuechua
      ? 'Perú Suyuntinpi Kumisariyakuna, CEM hinaspa Utqay Qayana'
      : 'Directorio Georreferenciado Nacional de Comisarías y Centros de Emergencia';
  String get searchStationPlaceholder => isQuechua ? 'Kumisariyata sutinpi utaq distritopi maskay...' : 'Buscar comisaría por nombre, distrito o calle...';
  String get allDepartmentsFilter => isQuechua ? 'Tukuy Departamintukuna' : 'Todos los departamentos';
  String get guardPhoneLabel => isQuechua ? 'Guardiaq Telefonun' : 'Teléfono de Guardia';
  String get callGuardAction => isQuechua ? 'Guardiaman Qayay' : 'Llamar a Guardia';
  String get viewOnMapAction => isQuechua ? 'Mapapi Qhaway' : 'Ver en Mapa';
  String get howToGetThereAction => isQuechua ? 'Imaynata Chayana' : 'Cómo llegar';
  String get jurisdictionLabel => isQuechua ? 'Jurisdicción Comisaría' : 'Jurisdicción';
  String get cemDirectoryTitle => isQuechua ? 'CEM Directoriu (Warmi Yanapay)' : 'Directorio CEM (Centros Emergencia Mujer)';
  String get cemDescription => isQuechua
      ? 'MIMP nisqapa yanapakuynin warmikunapaq hinaspa ayllukunapaq'
      : 'Atención multidisciplinaria legal y psicológica del MIMP 24/7.';
  String get emergencyHotlinesTitle => isQuechua ? 'Llakipi Utqay Qayanakuna' : 'Líneas Directas de Emergencia';
  String get linea100Title => isQuechua ? 'Línea 100 (Warmipaq)' : 'Línea 100 (Violencia Familiar)';
  String get linea105Title => isQuechua ? '105 PNP Central' : '105 Central de Emergencias PNP';
  String get linea114TitleFull => isQuechua ? '114 Chinkasqakunapaq' : '114 Personas Desaparecidas (Gratis)';

  // --- MI FAMILIA SEGURA (KIT DIGITAL PREVENTIVO) ---
  String get miFamiliaTitle => isQuechua ? 'Ayllu Waqaychay' : 'Mi Familia Segura';
  String get miFamiliaSubtitle => isQuechua
      ? 'Wawanchikkunata, tayta mamanchikkunata amachanapaq kit digital'
      : 'Kit Preventivo Digital para la protección y rápida reacción familiar';
  String get addFamilyMemberAction => isQuechua ? 'Mosoq Aylluta Yapay' : 'Registrar Nuevo Familiar';
  String get noFamilyMembersYet => isQuechua ? 'Manaraqmi aylluykikuna qillqasqachu kachkan.' : 'Aún no has registrado a tus familiares.';
  String get familyMemberFullName => isQuechua ? 'Tukuy Sutin' : 'Nombres y Apellidos';
  String get familyRelationship => isQuechua ? 'Parentesco' : 'Parentesco';
  String get familyAge => isQuechua ? 'Watan (Edad)' : 'Edad';
  String get familyDni => isQuechua ? 'DNI nisqa yupay' : 'Documento de Identidad (DNI)';
  String get familyPhoto => isQuechua ? 'Foton' : 'Fotografía nítida';
  String get familyDistinctiveMarks => isQuechua ? 'Señas particulares (lunares, cicatrices)' : 'Señas particulares';
  String get emergencyQrCard => isQuechua ? 'Utqay QR Carnet' : 'Carnet QR de Seguridad';
  String get saveMemberSuccess => isQuechua ? 'Ayllu allinta waqaychasqa!' : '¡Familiar guardado con éxito!';

  // --- RUTA SEGURA (EN VIVO) ---
  String get rutaSeguraTitle => isQuechua ? 'Ñan Waqaychay' : 'Ruta Segura (En Vivo)';
  String get rutaSeguraSubtitle => isQuechua
      ? 'Kutimunaykikama utaq purinaykipi aylluykiwan kuska puriy'
      : 'Acompañamiento en tiempo real para traslados y retorno seguro al hogar';
  String get startTripAction => isQuechua ? 'Puriyta Qallariy' : 'Iniciar Viaje Seguro';
  String get arrivedSafelyAction => isQuechua ? '¡Allinllam Chayaruni!' : '¡Llegué a Salvo!';
  String get triggerSosAlertAction => isQuechua ? '🚨 SOS UTQAY ALERTA' : '🚨 ENVIAR ALERTA SOS';
  String get destinationLabel => isQuechua ? 'Mayman rinayki' : 'Destino';
  String get shareLiveLocationAction => isQuechua ? 'GPS Maypi kasqaykita Aypuy' : 'Compartir Ubicación en Tiempo Real';
  String get tripInProgressNotice => isQuechua ? 'Puriypi kachkanki... Aylluykim qhawachkan' : 'Viaje activo en monitoreo familiar';

  // --- GUÍAS EDUCATIVAS Y GAMIFICACIÓN ---
  String get exploreGuidesTitle => isQuechua ? 'YACHAY GUÍAKUNA' : 'GUÍAS EDUCATIVAS';
  String get academySubtitle => isQuechua ? 'Ayllu Amachay Yachachikuy' : 'Academia de Prevención y Protección Familiar';
  String get quickQuizButton => isQuechua ? 'Utqay Reto' : 'Reto Express';
  String get medalsButton => isQuechua ? 'Medallakuna' : 'Medallas';
  String get completedLessonsCount => isQuechua ? 'yachasqakuna dominado' : 'temas completados';
  String get civicRankJunior => isQuechua ? 'Qallariq Yanapaq' : 'Protector Inicial';
  String get civicRankIntermediate => isQuechua ? 'Ayllu Amachaq' : 'Guardián Activo';
  String get civicRankMaster => isQuechua ? 'Alerta Hatun Yachachiq' : 'Maestro Protector Alerta';
  String get miniTriviaTitle => isQuechua ? 'Mini-Trivia Yachayninchik' : 'Mini-Trivia Formativa';
  String get verifyAnswerAction => isQuechua ? 'Qhawariy' : 'Verificar Respuesta';
  String get congratulationsLeafWon => isQuechua ? '¡Allin ruwasqa! Mosoq yachayta ganarunki' : '¡Excelente! Has dominado esta lección';

  // --- BANDEJA DE SUGERENCIAS Y ACERCA DE ---
  String get feedbackScreenTitle => isQuechua ? 'Yuyaychaykuna Bandeja' : 'Bandeja de Sugerencias';
  String get feedbackScreenSubtitle => isQuechua
      ? 'Willawayku imaynatataq kay plataformata aswan allinta ruwanchik'
      : 'Ayúdanos a mejorar la plataforma ciudadana con tus comentarios';
  String get feedbackInputHint => isQuechua ? 'Qillqay yuyaychayniykita...' : 'Escribe tu sugerencia o propuesta de mejora...';
  String get sendFeedbackAction => isQuechua ? 'Yuyaychayta Kachay' : 'Enviar Sugerencia';
  String get aboutAppMission => isQuechua
      ? 'Kay plataformaqa Perú suyuntinpi chinkasqa runakunata utqaylla tarinapaqmi kamasqa kashan.'
      : 'Plataforma colaborativa e independiente dedicada a la búsqueda y localización de personas desaparecidas.';
  String get yourVoiceSavesLives => isQuechua ? 'Kunkaykiqa runapa kawsaynintam qispin' : 'Tu voz salva vidas';
  String get coCreationBadge => isQuechua ? 'LLAQTAMASI KUSKA RUWAY PNP' : 'CO-CREACIÓN CIUDADANA PNP';
  String get sendYourIdea => isQuechua
      ? 'Willawayku imatataq allichasunman chinkasqakunata utqaylla tarinapaq.'
      : 'Dinos qué funciona, qué debemos corregir o qué nueva idea tienes para encontrar a nuestros desaparecidos más rápido.';
  String get myContributions => isQuechua ? 'Willakusqaykuna' : 'Mis Aportes';
  String get newContribution => isQuechua ? 'Mosoq Yuyaychay' : 'Nuevo Aporte';
  String get whatWentWell => isQuechua ? 'Allin ruwasqa' : 'Lo que funciona bien';
  String get whatNeedsFix => isQuechua ? 'Sasachakuy / Pantasqa' : 'Lo que está fallando';
  String get ideasAndSuggestions => isQuechua ? 'Mosoq Yuyaychay' : 'Idea o Sugerencia';

  // --- HELPERS GENERALES DE INTERFAZ Y ACCIONES ---
  String get zoomIn => isQuechua ? 'Hatunyachiy' : 'Ampliar';
  String get viewFile => isQuechua ? 'Fichata qhaway' : 'Ver ficha';
  String get viewFullFile => isQuechua ? 'TUKUY FICHATA QHAWAY' : 'VER FICHA COMPLETA';
  String caseIndexCounter(int current, int total) =>
      isQuechua ? '$current kaq ($total-manta)' : 'Caso $current de $total';
  String get fixedFilterPanel => isQuechua ? 'TIKRACHIKUQ AKLLANA' : 'PANEL DE FILTROS FIJO';
  String get swipeDownToSee => isQuechua ? 'Llikachasqata urayman aysay' : 'Desliza para ver fichas';
  String get swipeDownToSeeFound =>
      isQuechua ? 'Urayman aysay tarisqakunata qhawanaykipaq ↓' : 'Desliza para ver localizados ↓';
  String get allOption => isQuechua ? 'Llapantin' : 'Todos';
  String get alertDataTitle => isQuechua ? 'ALERTAMANTA WILLAYKUNA' : 'DATOS DE LA ALERTA';
  String inYourZone(String loc) => isQuechua ? 'LLAQTIYKIPI ($loc)' : 'EN TU ZONA ($loc)';
  String get citizenActionCenter => isQuechua ? 'LLAQTAMASI RURANA CHAWPI' : 'CENTRO DE ACCIÓN CIUDADANA';
  String get collaborateHint => isQuechua ? 'Yanapanaykipaq botonta ñit’iy 💙' : 'Toca cualquiera de los botones para colaborar 💙';
  String get didYouSeeItReport => isQuechua ? '¿RIKURQANKICHU? PAKASQA PISTATA QUY' : '¿LO VISTE? APORTAR PISTA CONFIDENCIAL';
  String get anonymousNotice => isQuechua ? '100% Pakasqa hinaspa Amachasqa • PNP' : '100% Anónimo y Seguro • Protección PNP';
  String get callStationDirect => isQuechua ? 'Kumisariyaman Qayay' : 'Llamar CPNP';
  String get viewMap => isQuechua ? 'Mapapi Qhaway' : 'Ver Mapa';
  String get allDependencies => isQuechua ? 'Llapankuna' : 'Todas';
  String get stations => isQuechua ? 'Kumisariyakuna' : 'Comisarías';
  String get family => isQuechua ? 'Ayllu' : 'Familia';
  String get traffic => isQuechua ? 'Carrokuna' : 'Tránsito';
  String get openSosPanic => isQuechua ? '🚨 SOS UTQAY ALERTA HINASPA GPS KICHAY' : '🚨 ABRIR BOTÓN DE PÁNICO SOS Y GPS';
  String get freeCallsEverywhere => isQuechua
      ? 'Manam qullqipaqchu ima telefonoykimantapas llapanchikpaq.'
      : 'Llamadas gratuitas desde cualquier celular o teléfono público a nivel nacional.';
  String get firefightersTitle => isQuechua ? '116 Nina Rawray Rikukuqkuna (Bomberos)' : 'Cuerpo General de Bomberos Voluntarios';
  String get samuTitle => isQuechua ? '106 SAMU (Hampina Ambulancia)' : 'SAMU (Ambulancia y Atención Médica Móvil)';
  String get destinationPrompt => isQuechua ? '1. ¿Maymantaq rinki?' : '1. ¿Hacia dónde te diriges?';
  String get tripTimePrompt => isQuechua ? '2. Puriypa tiempun:' : '2. Tiempo estimado de viaje:';
  String get transportTypePrompt => isQuechua ? '3. ¿Imapitaq rinkichik?' : '3. Medio de transporte:';
  String get vehiclePlatePrompt => isQuechua ? '4. Placa o carropa sutin (munaspaqa):' : '4. Placa o descripción del vehículo:';
  String get trustedContactPrompt => isQuechua ? '5. Aylluykipa sutin hinaspa celularnin:' : '5. Contacto de confianza a avisar:';
  String get startSafeRoute => isQuechua ? 'PURIYTA QALLARIY HINASPA WILLAY' : 'INICIAR RUTA SEGURA Y AVISAR';
  String get tripUnderwayTo => isQuechua ? 'Puriypi kashanki kayman:' : 'Ruta en curso hacia:';
  String get cancelTrip => isQuechua ? 'PURIYTA TATIY' : 'CANCELAR TRAYECTO';
  String get sosPanicButton => isQuechua ? 'SOS UTQAY ALERTA' : 'BOTÓN DE PÁNICO SOS';
  String get addTrafficTime10 => isQuechua ? '+10 min Sayasqa' : '+10 min Tráfico 🚦';
  String get addTrafficTime20 => isQuechua ? '+20 min Sayasqa' : '+20 min Tráfico 🛑';
  String get routeActiveBadge => isQuechua ? 'QAMWANMI PURICHKANKIKU' : 'ACOMPAÑAMIENTO ACTIVO';
  String get notifyViaWhatsApp => isQuechua ? 'WhatsApp-wan willay' : 'Avisar por WhatsApp';
  String get estimatedArrival => isQuechua ? 'Chayanayki hora' : 'Hora estimada de llegada';
  String get plateHelperText => isQuechua 
      ? 'Plakata qillqay carromanta lluqsinaykipaq, mana allin kaptinqa policia usqhaylla maskananpaq.'
      : 'Registrar la placa permite a la PNP y a tu familia rastrear el vehículo ante cualquier desviación de ruta.';
}

