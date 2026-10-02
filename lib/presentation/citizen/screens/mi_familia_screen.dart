import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/mi_familia_service.dart';
import '../../../services/mi_familia_pdf_service.dart';
import '../../../services/gps_location_service.dart';
import '../../common_widgets/glass_container.dart';
import '../../../core/services/analytics_telemetry_service.dart';
import '../widgets/carnet_visual_preview_widget.dart';
import '../widgets/afiche_visual_preview_widget.dart';
import '../../../common/localization/app_strings.dart';

class MiFamiliaScreen extends StatefulWidget {
  const MiFamiliaScreen({super.key});

  @override
  State<MiFamiliaScreen> createState() => _MiFamiliaScreenState();
}

class _MiFamiliaScreenState extends State<MiFamiliaScreen> {
  final MiFamiliaService _familiaService = MiFamiliaService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    AnalyticsTelemetryService().logModuleUsage('Mi Familia');
    _familiaService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _familiaService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<String?> _tomarOSeleccionarFoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 75,
      );
      if (image == null) return null;
      final bytes = await image.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error al capturar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar la foto: $e')),
        );
      }
      return null;
    }
  }

  void _mostrarOpcionesOrigenFoto(BuildContext context, Function(ImageSource) onSourceSelected) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 14),
              const Text('Seleccionar Foto del Familiar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Es obligatorio adjuntar una foto para emitir el carnet preventivo y el afiche.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Color(0xFFF59E0B)),
                ),
                title: const Text('Tomar Foto con Cámara', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Foto en vivo ahora mismo'),
                onTap: () {
                  Navigator.pop(ctx);
                  onSourceSelected(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF1E40AF).withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library, color: Color(0xFF1E40AF)),
                ),
                title: const Text('Elegir de Galería', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Seleccionar una foto guardada en tu dispositivo'),
                onTap: () {
                  Navigator.pop(ctx);
                  onSourceSelected(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEditDialog({FamiliarProfile? existing}) {
    final nombreCtrl = TextEditingController(text: existing?.nombreCompleto ?? '');
    final edadCtrl = TextEditingController(text: existing != null && existing.edad > 0 ? existing.edad.toString() : '');
    final dniCtrl = TextEditingController(text: existing?.dni ?? '');
    final estaturaCtrl = TextEditingController(text: existing?.estatura ?? '');
    final senasCtrl = TextEditingController(text: existing?.senasParticulares ?? '');
    final datosMedicosCtrl = TextEditingController(text: existing?.datosMedicos ?? '');
    final ropaCtrl = TextEditingController(text: existing?.ropaDelDia ?? '');
    final telefonoCtrl = TextEditingController(text: existing?.telefonoContacto ?? '');

    final parentescos = ['Hijo/a', 'Padre / Madre', 'Abuelo/a', 'Hermano/a', 'Pareja', 'Mascota / Otro'];
    String selectedParentesco = existing?.parentesco ?? 'Hijo/a';
    if (!parentescos.contains(selectedParentesco)) selectedParentesco = 'Hijo/a';

    final tiposSangre = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'No especificado'];
    String selectedTipoSangre = existing?.tipoSangre ?? 'O+';
    if (!tiposSangre.contains(selectedTipoSangre)) selectedTipoSangre = 'O+';

    // Opciones rápidas de rasgos
    final contexturas = ['Delgada', 'Regular', 'Robusta', 'Atlética'];
    String selectedContextura = existing?.contextura ?? 'Regular';
    if (!contexturas.contains(selectedContextura)) selectedContextura = 'Regular';

    final coloresPiel = ['Clara', 'Trigueña', 'Morena', 'Oscura'];
    String selectedColorPiel = existing?.colorPiel ?? 'Trigueña';
    if (!coloresPiel.contains(selectedColorPiel)) selectedColorPiel = 'Trigueña';

    final coloresCabello = ['Negro', 'Castaño oscuro', 'Castaño claro', 'Rubio', 'Canoso'];
    String selectedColorCabello = existing?.colorCabello ?? 'Negro';
    if (!coloresCabello.contains(selectedColorCabello)) selectedColorCabello = 'Negro';

    final condiciones = [
      'Ninguna',
      'Alzheimer / Pérdida de memoria',
      'Autismo / TEA',
      'Discapacidad auditiva/motriz',
      'Alergias severas',
      'Usa lentes / Dificultad visual',
      'Requiere medicación diaria'
    ];
    String selectedCondicion = existing?.condicionEspecial ?? 'Ninguna';
    if (!condiciones.contains(selectedCondicion)) selectedCondicion = 'Ninguna';

    String selectedEstiloCarnet = existing?.estiloCarnet ?? 'auto';

    String? fotoBase64 = existing?.fotoBase64;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.family_restroom_rounded, color: Color(0xFFF59E0B), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          existing == null ? 'Registrar Familiar Seguro' : 'Editar Ficha Familiar',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // FOTO DESTACADA (OBLIGATORIA)
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _mostrarOpcionesOrigenFoto(context, (source) async {
                              final base64Result = await _tomarOSeleccionarFoto(source);
                              if (base64Result != null) {
                                setModalState(() {
                                  fotoBase64 = base64Result;
                                });
                              }
                            });
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 108,
                                height: 108,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: fotoBase64 != null && fotoBase64!.isNotEmpty
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    width: 3.5,
                                  ),
                                  color: fotoBase64 != null && fotoBase64!.isNotEmpty
                                      ? const Color(0xFF10B981).withOpacity(0.08)
                                      : const Color(0xFFEF4444).withOpacity(0.08),
                                ),
                                child: ClipOval(
                                  child: fotoBase64 != null && fotoBase64!.isNotEmpty
                                      ? Image.memory(base64Decode(fotoBase64!), fit: BoxFit.cover)
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.add_a_photo_rounded, size: 36, color: Color(0xFFEF4444)),
                                            SizedBox(height: 2),
                                            Text(
                                              'FOTO\nOBLIGATORIA',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: fotoBase64 != null && fotoBase64!.isNotEmpty
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (fotoBase64 != null && fotoBase64!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                                SizedBox(width: 4),
                                Text(
                                  'Foto lista para Carnet SOS y Afiche',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                                SizedBox(width: 4),
                                Text(
                                  '* Foto Obligatoria (Toca para agregar)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Nombre
                  TextField(
                    controller: nombreCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre Completo / Apodo *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Parentesco, Edad y DNI
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: selectedParentesco,
                          decoration: InputDecoration(
                            labelText: 'Parentesco',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: parentescos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (v) => setModalState(() => selectedParentesco = v ?? 'Hijo/a'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: edadCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Edad',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.cake, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: dniCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          decoration: InputDecoration(
                            counterText: '',
                            labelText: 'DNI (opcional)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Selector de Estilo de Carnet Cadete
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.badge_rounded, size: 16, color: Color(0xFF1E40AF)),
                            SizedBox(width: 6),
                            Text(
                              'Diseño del Carnet Escudo SOS:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => selectedEstiloCarnet = 'nino'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: selectedEstiloCarnet == 'nino' ? const Color(0xFF00E5FF).withOpacity(0.18) : (isDark ? const Color(0xFF0F172A) : Colors.white),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedEstiloCarnet == 'nino' ? const Color(0xFF00E5FF) : Colors.grey.shade300,
                                      width: selectedEstiloCarnet == 'nino' ? 2 : 1,
                                    ),
                                  ),
                                  child: const Text(
                                    '👦 Cadete Niño\n(Neón Cian)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => selectedEstiloCarnet = 'nina'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: selectedEstiloCarnet == 'nina' ? const Color(0xFFF43F5E).withOpacity(0.18) : (isDark ? const Color(0xFF0F172A) : Colors.white),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedEstiloCarnet == 'nina' ? const Color(0xFFF43F5E) : Colors.grey.shade300,
                                      width: selectedEstiloCarnet == 'nina' ? 2 : 1,
                                    ),
                                  ),
                                  child: const Text(
                                    '👧 Cadete Niña\n(Rose Gold)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => selectedEstiloCarnet = 'auto'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: selectedEstiloCarnet == 'auto' ? const Color(0xFF3B82F6).withOpacity(0.18) : (isDark ? const Color(0xFF0F172A) : Colors.white),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedEstiloCarnet == 'auto' ? const Color(0xFF3B82F6) : Colors.grey.shade300,
                                      width: selectedEstiloCarnet == 'auto' ? 2 : 1,
                                    ),
                                  ),
                                  child: const Text(
                                    '🤖 Detección\nAutomática',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Teléfono de contacto de emergencia
                  TextField(
                    controller: telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Teléfono de Contacto Familiar *',
                      hintText: 'Número directo para recibir avisos (ej: 948269740)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.phone_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SECCIÓN: RASGOS FÍSICOS SELECCIONABLES (Rápido y Fácil)
                  const Text(
                    'Rasgos Físicos Rápidos',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(height: 8),

                  // Fila 1: Contextura y Color de Piel
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedContextura,
                          decoration: InputDecoration(
                            labelText: 'Contextura',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: contexturas.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setModalState(() => selectedContextura = v ?? 'Regular'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedColorPiel,
                          decoration: InputDecoration(
                            labelText: 'Color de Piel',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: coloresPiel.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setModalState(() => selectedColorPiel = v ?? 'Trigueña'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fila 2: Cabello y Estatura
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedColorCabello,
                          decoration: InputDecoration(
                            labelText: 'Color de Cabello',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: coloresCabello.map((cb) => DropdownMenuItem(value: cb, child: Text(cb, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setModalState(() => selectedColorCabello = v ?? 'Negro'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: estaturaCtrl,
                          decoration: InputDecoration(
                            labelText: 'Estatura',
                            hintText: 'Ej: 1.25 m, 1.68 m',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Grupo Sanguíneo y Condición Especial
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: selectedTipoSangre,
                          decoration: InputDecoration(
                            labelText: 'Sangre',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.bloodtype_rounded, color: Colors.redAccent, size: 20),
                          ),
                          items: tiposSangre.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setModalState(() => selectedTipoSangre = v ?? 'O+'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: selectedCondicion,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Condición Especial',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: condiciones.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setModalState(() => selectedCondicion = v ?? 'Ninguna'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Ropa del día
                  TextField(
                    controller: ropaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Vestimenta de hoy (Ropa al salir)',
                      hintText: 'Ej: Casaca azul, pantalón plomo y zapatillas blancas',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.checkroom_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Señas particulares
                  TextField(
                    controller: senasCtrl,
                    decoration: InputDecoration(
                      labelText: 'Señas particulares (opcional)',
                      hintText: 'Lunares, cicatriz, tatuaje, brackets, usa lentes...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.visibility_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Alergias / Medicación
                  TextField(
                    controller: datosMedicosCtrl,
                    decoration: InputDecoration(
                      labelText: 'Alergias o medicación obligatoria (opcional)',
                      hintText: 'Alergia al polen, insulina diaria...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.medical_services_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón Guardar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final nombre = nombreCtrl.text.trim();
                        if (nombre.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor ingresa el nombre de tu familiar')),
                          );
                          return;
                        }

                        if (fotoBase64 == null || fotoBase64!.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFFEF4444),
                              behavior: SnackBarBehavior.floating,
                              content: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.white),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '⚠️ La foto es obligatoria para emitir el Carnet SOS y el Afiche Oficial.',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          return;
                        }

                        final edad = int.tryParse(edadCtrl.text.trim()) ?? 0;
                        final newProfile = FamiliarProfile(
                          id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          nombreCompleto: nombre,
                          parentesco: selectedParentesco,
                          edad: edad,
                          dni: dniCtrl.text.trim(),
                          fotoBase64: fotoBase64,
                          fechaActualizacionFoto: fotoBase64 != existing?.fotoBase64 ? DateTime.now() : existing?.fechaActualizacionFoto,
                          estatura: estaturaCtrl.text.trim(),
                          contextura: selectedContextura,
                          colorPiel: selectedColorPiel,
                          colorCabello: selectedColorCabello,
                          senasParticulares: senasCtrl.text.trim(),
                          telefonoContacto: telefonoCtrl.text.trim(),
                          tipoSangre: selectedTipoSangre,
                          condicionEspecial: selectedCondicion,
                          datosMedicos: datosMedicosCtrl.text.trim(),
                          ropaDelDia: ropaCtrl.text.trim(),
                          estiloCarnet: selectedEstiloCarnet,
                        );
                        await _familiaService.saveFamiliar(newProfile);
                        if (ctx.mounted) Navigator.pop(ctx);

                        // Auto-generación y apertura inmediata del Carnet SOS adaptado según edad
                        if (mounted) {
                          final String estiloMsg = newProfile.edad < 12
                              ? (newProfile.esFemenino ? 'Cadete Escudo SOS (Niña - Rose Gold)' : 'Cadete Escudo SOS (Niño - Neón Cian)')
                              : (newProfile.edad < 18 ? 'Juvenil ("ID Moderno")' : 'Adulto ("Credencial SOS")');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF1E40AF),
                              behavior: SnackBarBehavior.floating,
                              content: Row(
                                children: [
                                  const Icon(Icons.badge_rounded, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '¡Ficha guardada! Mostrando Carnet SOS $estiloMsg...',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          MiFamiliaPdfService.abrirCarnetPdf(context, newProfile);
                        }
                      },
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text('Guardar Ficha Preventiva', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showActualizarFotoModal(FamiliarProfile familiar) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 14),
            Text(
              'Actualizar Foto: ${familiar.nombreCompleto}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mantener una foto actual es vital para una búsqueda inmediata efectiva.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Color(0xFFF59E0B)),
              ),
              title: const Text('Tomar Foto con la Cámara', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Foto en vivo ahora mismo'),
              onTap: () async {
                Navigator.pop(ctx);
                final base64Str = await _tomarOSeleccionarFoto(ImageSource.camera);
                if (base64Str != null) {
                  await _familiaService.updateFoto(familiar.id, base64Str);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Foto actualizada exitosamente')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.photo_library, color: Colors.teal),
              ),
              title: const Text('Elegir de la Galería', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Seleccionar una foto guardada reciente'),
              onTap: () async {
                Navigator.pop(ctx);
                final base64Str = await _tomarOSeleccionarFoto(ImageSource.gallery);
                if (base64Str != null) {
                  await _familiaService.updateFoto(familiar.id, base64Str);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Foto actualizada exitosamente')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showUpdateRopaDialog(FamiliarProfile familiar) {
    final ropaCtrl = TextEditingController(text: familiar.ropaDelDia);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.checkroom_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Ropa de Hoy: ${familiar.nombreCompleto}', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ropaCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '¿Qué ropa lleva puesta hoy?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('Uniforme Escolar', style: TextStyle(fontSize: 11)),
                  onPressed: () => ropaCtrl.text = 'Uniforme escolar completo con mochila',
                ),
                ActionChip(
                  label: const Text('Buzo Deportivo', style: TextStyle(fontSize: 11)),
                  onPressed: () => ropaCtrl.text = 'Buzo deportivo y zapatillas',
                ),
                ActionChip(
                  label: const Text('Casaca y Jean', style: TextStyle(fontSize: 11)),
                  onPressed: () => ropaCtrl.text = 'Casaca abrigadora, pantalón jean y zapatillas',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _familiaService.updateRopaDelDia(familiar.id, ropaCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            child: const Text('Actualizar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _dispararAlertaExtravio(FamiliarProfile f) async {
    HapticFeedback.heavyImpact();
    String ubicacion = '';
    try {
      final loc = await GpsLocationService.getCurrentLocation();
      if (loc != null) {
        ubicacion = '${loc.departamento}, ${loc.provincia} (GPS: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})';
      }
    } catch (_) {}

    final texto = _familiaService.generarTextoAlertaInmediata(f, ubicacionActual: ubicacion);

    // Si tiene foto, compartir como archivo de imagen + texto
    if (f.fotoBase64 != null && f.fotoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(f.fotoBase64!);
        final xFile = XFile.fromData(
          bytes,
          mimeType: 'image/jpeg',
          name: 'alerta_extravio_${f.nombreCompleto.replaceAll(' ', '_')}.jpg',
        );
        await Share.shareXFiles(
          [xFile],
          text: texto,
          subject: '🚨 ALERTA DE EXTRAVÍO: ${f.nombreCompleto}',
        );
        return;
      } catch (e) {
        debugPrint('Aviso al compartir imagen con shareXFiles: $e');
      }
    }

    // Fallback a texto
    await Share.share(texto, subject: '🚨 ALERTA DE EXTRAVÍO: ${f.nombreCompleto}');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final familiares = _familiaService.familiares;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Banner explicativo y motivador
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: GlassContainer(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.all(16),
                customColor: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_rounded, color: Color(0xFFF59E0B), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.miFamiliaTitle,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            strings.miFamiliaSubtitle,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Botón agregar y Guía
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddEditDialog(),
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
                      label: Text(
                        strings.addFamilyMemberAction,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () => _mostrarGuiaProteccionFamiliar(context),
                      icon: const Icon(Icons.help_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                      label: Text(
                        strings.isQuechua ? 'Imaynatam yanapan?' : '¿Cómo ayuda?',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lista de familiares o vacío
          if (familiares.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.family_restroom_rounded, size: 72, color: Colors.grey.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text(
                        strings.noFamilyMembersYet,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.isQuechua
                            ? 'Willaykunapas fotokunapas celularkillaypimi kashan. Pipas chinkaptinqa PDF aficheta ruwaspa usqhaylla Polisiyata willayta atinki.'
                            : 'Tus datos y fotos se guardan exclusivamente en tu celular. En caso de extravío, podrás generar un afiche en PDF y alertar a la Policía en segundos.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final f = familiares[index];
                    return _buildFamiliarCard(f, isDark);
                  },
                  childCount: familiares.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFamiliarCard(FamiliarProfile f, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de tarjeta con FOTO MÁS GRANDE Y CLARA
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FOTO GRANDE
                GestureDetector(
                  onTap: () => _showActualizarFotoModal(f),
                  child: Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF59E0B), width: 2.5),
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                        ),
                        child: ClipOval(
                          child: f.fotoBase64 != null && f.fotoBase64!.isNotEmpty
                              ? Image.memory(base64Decode(f.fotoBase64!), fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    f.nombreCompleto.isNotEmpty ? f.nombreCompleto[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.nombreCompleto,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${f.parentesco} • ${f.edad > 0 ? '${f.edad} años' : 'Edad no especificada'} • Sangre: ${f.tipoSangre}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      // Rasgos rápidos en cápsulas
                      Text(
                        f.resumenRasgosFisicos,
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (f.condicionEspecial.isNotEmpty && f.condicionEspecial != 'Ninguna')
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '⚠️ ${f.condicionEspecial}',
                            style: const TextStyle(fontSize: 11.5, color: Colors.amber, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'carnet') MiFamiliaPdfService.abrirCarnetPdf(context, f);
                    if (val == 'foto') _showActualizarFotoModal(f);
                    if (val == 'edit') _showAddEditDialog(existing: f);
                    if (val == 'delete') _familiaService.deleteFamiliar(f.id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'carnet',
                      child: Row(children: [Icon(Icons.badge_rounded, size: 18, color: Color(0xFF1E40AF)), SizedBox(width: 8), Text('Carnet SOS / Fotocheck')]),
                    ),
                    const PopupMenuItem(
                      value: 'foto',
                      child: Row(children: [Icon(Icons.camera_alt, size: 18, color: Color(0xFFF59E0B)), SizedBox(width: 8), Text('Actualizar Foto')]),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar Ficha')]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bloque de ropa del día (con botón rápido)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.checkroom_rounded, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ropa de hoy (Vestimenta al salir):',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                      ),
                      Text(
                        f.ropaDelDia.isNotEmpty ? f.ropaDelDia : 'Toca para registrar qué ropa lleva puesta hoy',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: f.ropaDelDia.isEmpty ? FontStyle.italic : FontStyle.normal,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showUpdateRopaDialog(f),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFF59E0B)),
                  tooltip: 'Actualizar ropa de hoy',
                ),
              ],
            ),
          ),

          // Datos médicos
          if (f.datosMedicos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text('🩺 ${f.datosMedicos}', style: const TextStyle(fontSize: 11.5, color: Colors.amber)),
            ),

          const SizedBox(height: 12),

          // Acciones en 2 filas organizadas y cómodas
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                // Fila 1: Documentos Preventivos e Impresos
                Row(
                  children: [
                    // Botón 1: Carnet SOS / Fotocheck
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _mostrarOpcionesCarnet(context, f),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E40AF).withOpacity(0.08),
                              border: Border.all(color: const Color(0xFF1E40AF), width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.badge_rounded, size: 16, color: Color(0xFF1E40AF)),
                                SizedBox(width: 5),
                                Text(
                                  'Carnet SOS',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF1E40AF)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón 2: Afiche PDF
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _mostrarOpcionesAfiche(context, f),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withOpacity(0.08),
                              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFDC2626)),
                                SizedBox(width: 5),
                                Text(
                                  'Afiche PDF',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFFDC2626)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Fila 2: Foto y Alerta Inmediata
                Row(
                  children: [
                    // Botón 3: Actualizar Foto
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showActualizarFotoModal(f),
                        icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFFF59E0B)),
                        label: const Text(
                          'Actualizar Foto',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón 4: Alerta SOS con Foto + GPS
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _dispararAlertaExtravio(f),
                        icon: const Icon(Icons.emergency_share_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'Alerta SOS',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarOpcionesCarnet(BuildContext context, FamiliarProfile f) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header with Police Round Logo
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1E40AF),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: ClipOval(
                        child: Image.asset('assets/icons/icon_police.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Carnet Preventivo SOS',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            f.nombreCompleto,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Option 1: Ver Carnet SOS
                _buildActionTile(
                  icon: Icons.visibility_rounded,
                  iconColor: const Color(0xFF1E40AF),
                  bgColor: const Color(0xFF1E40AF).withOpacity(0.08),
                  title: 'Ver Carnet SOS',
                  subtitle: 'Visor interactivo con diseño adaptado a su edad y zoom',
                  onTap: () {
                    Navigator.pop(ctx);
                    MiFamiliaPdfService.abrirCarnetPdf(context, f);
                  },
                ),
                const SizedBox(height: 10),

                // Option 2: Compartir
                _buildActionTile(
                  icon: Icons.share_rounded,
                  iconColor: const Color(0xFF25D366),
                  bgColor: const Color(0xFF25D366).withOpacity(0.1),
                  title: 'Compartir Carnet PDF',
                  subtitle: 'Enviar por WhatsApp o descargar el archivo oficial',
                  onTap: () {
                    Navigator.pop(ctx);
                    MiFamiliaPdfService.compartirCarnetPdf(context, f);
                  },
                ),
                const SizedBox(height: 10),

                // Option 3: Guía práctica
                _buildActionTile(
                  icon: Icons.lightbulb_rounded,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFD97706).withOpacity(0.1),
                  title: '¿Cómo funciona el Carnet Adaptativo?',
                  subtitle: 'Diseños infantil, juvenil y adulto con QR de auxilio',
                  onTap: () {
                    Navigator.pop(ctx);
                    _mostrarGuiaCarnetDialog(context, f);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarOpcionesAfiche(BuildContext context, FamiliarProfile f) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header with Police Round Logo
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFDC2626),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: ClipOval(
                        child: Image.asset('assets/icons/icon_police.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Afiche de Búsqueda Urgente',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            f.nombreCompleto,
                            style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Option 1: Ver Afiche Oficial
                _buildActionTile(
                  icon: Icons.visibility_rounded,
                  iconColor: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFDC2626).withOpacity(0.08),
                  title: 'Ver Afiche Oficial',
                  subtitle: 'Formato A4 de alta resolución con foto y código QR policial',
                  onTap: () {
                    Navigator.pop(ctx);
                    MiFamiliaPdfService.abrirAfichePdf(context, f);
                  },
                ),
                const SizedBox(height: 10),

                // Option 2: Compartir
                _buildActionTile(
                  icon: Icons.share_rounded,
                  iconColor: const Color(0xFF25D366),
                  bgColor: const Color(0xFF25D366).withOpacity(0.1),
                  title: 'Compartir Afiche PDF',
                  subtitle: 'Difundir en grupos de WhatsApp, redes sociales y descargar',
                  onTap: () {
                    Navigator.pop(ctx);
                    MiFamiliaPdfService.compartirAfichePdf(context, f);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: iconColor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: iconColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _mostrarGuiaCarnetDialog(BuildContext context, FamiliarProfile f) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.badge_rounded, color: Color(0xFF1E40AF), size: 26),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Carnet Preventivo SOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(f.nombreCompleto, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Cómo funciona este carnet para proteger a tu familiar?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
              ),
              const SizedBox(height: 10),
              _buildGuiaPunto(
                icon: Icons.auto_awesome_rounded,
                color: Colors.blue,
                titulo: '1. Diseño Adaptativo según la Edad',
                texto: '• Niños (0-11 años): Diseño "Pequeño Protegido", tierno y protector.\n• Adolescentes (12-17 años): Estilo "ID Juvenil Moderno" tecnológico que no da vergüenza portar.\n• Adultos/Seniors (18+ años): Formato formal con datos médicos y contactos de auxilio.',
              ),
              const SizedBox(height: 8),
              _buildGuiaPunto(
                icon: Icons.qr_code_scanner_rounded,
                color: Colors.green,
                titulo: '2. Código QR Inteligente de WhatsApp',
                texto: 'Cualquier policía, serenazgo o ciudadano que escanee el código QR abrirá WhatsApp de inmediato con un mensaje de auxilio preconfigurado dirigido a ti.',
              ),
              const SizedBox(height: 8),
              _buildGuiaPunto(
                icon: Icons.camera_alt_rounded,
                color: Colors.amber,
                titulo: '3. Foto Actualizada Obligatoria',
                texto: 'Garantiza que la credencial cuente con la foto más nítida y reciente para una identificación certera por parte de la Policía o serenazgo.',
              ),
              const SizedBox(height: 8),
              _buildGuiaPunto(
                icon: Icons.share_rounded,
                color: Colors.teal,
                titulo: '4. Visualización y Compartición Inmediata',
                texto: 'Puedes ver el carnet en pantalla con zoom de alta resolución o compartirlo por WhatsApp a otros familiares, cuidadores o profesores.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              MiFamiliaPdfService.abrirCarnetPdf(context, f);
            },
            icon: const Icon(Icons.visibility_rounded, size: 16, color: Colors.white),
            label: const Text('Ver Carnet SOS', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuiaPunto({
    required IconData icon,
    required Color color,
    required String titulo,
    required String texto,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(texto, style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  void _mostrarGuiaProteccionFamiliar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guía de Protección Familiar',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '¿Por qué este kit es indispensable para tu hogar?',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= HERO BANNER: DEMOSTRACIÓN DEL KIT COMPLETO =================
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFFBBF24),
                                ),
                                child: const Icon(Icons.stars_rounded, color: Color(0xFF0F172A), size: 24),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '¿CÓMO SE VE EL PRODUCTO FINAL?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'Muestra real del Kit para Niño, Adolescente y Adulto',
                                      style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Descubre el resultado exacto que obtendrás al registrar a tu ser querido: Credencial Horizontal (billetera), Portafotocheck Vertical (cuello) y Afiche Oficial de Búsqueda A4.',
                            style: TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _mostrarDemostracionKitModal(context);
                              },
                              icon: const Icon(Icons.remove_red_eye_rounded, size: 18, color: Color(0xFF0F172A)),
                              label: const Text(
                                'VER MUESTRA DEL KIT COMPLETO',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  fontSize: 12.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFBBF24),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildGuiaCard(
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xFF1E40AF),
                      title: '1. Diseños Adaptativos según la Edad',
                      description:
                          '• Niños (0-11 años): Diseño "Pequeño Protegido", tierno y protector.\n• Jóvenes y Adolescentes (12-17 años): Estilo "ID Juvenil / Tecnológico" moderno y discreto para que no les dé vergüenza portarlo en su mochila o billetera.\n• Adultos / Adultos Mayores (18+ años): Formato formal con datos médicos, tipo de sangre y contactos destacados.',
                    ),
                    const SizedBox(height: 12),
                    _buildGuiaCard(
                      icon: Icons.camera_alt_outlined,
                      color: const Color(0xFFEF4444),
                      title: '2. Foto Obligatoria para Búsqueda Inmediata',
                      description:
                          '• Una búsqueda es infructuosa sin una fotografía nítida y reciente.\n• La aplicación exige foto para garantizar que tanto el Carnet SOS como el Afiche Policial tengan validez visual inmediata ante las autoridades.',
                    ),
                    const SizedBox(height: 12),
                    _buildGuiaCard(
                      icon: Icons.flash_on_rounded,
                      color: Colors.amber.shade700,
                      title: '3. Generación Automática al Guardar',
                      description:
                          '• No tienes que configurar nada complejo: ni bien completas y guardas la ficha preventiva, el carnet adaptado a su edad se crea de forma automática y se abre en pantalla.',
                    ),
                    const SizedBox(height: 12),
                    _buildGuiaCard(
                      icon: Icons.qr_code_scanner_rounded,
                      color: Colors.green.shade700,
                      title: '4. Código QR Inteligente de WhatsApp',
                      description:
                          '• Quien auxilie a tu familiar extraviado (policía, serenazgo o ciudadano) solo debe escanear el QR con la cámara de su teléfono para enviarte un mensaje directo con la ubicación.',
                    ),
                    const SizedBox(height: 12),
                    _buildGuiaCard(
                      icon: Icons.share_rounded,
                      color: Colors.teal.shade700,
                      title: '5. Visualización y Compartición 100% Digital',
                      description:
                          '• Puedes ver el documento interactivo en pantalla con zoom de alta fidelidad o compartirlo en segundos por WhatsApp con profesores, cuidadores o brigadas de búsqueda.',
                    ),
                    const SizedBox(height: 12),
                    _buildGuiaCard(
                      icon: Icons.lock_outline_rounded,
                      color: Colors.blueAccent,
                      title: '6. Privacidad 100% Garantizada (Offline-First)',
                      description:
                          '• Las fotos y datos de tus seres queridos se guardan ÚNICAMENTE en la memoria interna de tu dispositivo.\n• Nada se sube a internet ni a bases de datos públicas a menos que tú decidas compartir voluntariamente.',
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.volunteer_activism_rounded, color: Color(0xFFF59E0B), size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Un padre o madre prevenido vale por dos. ¡Recomienda este kit a tus familiares y vecinos para que juntos protejamos a quienes más amamos!',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _mostrarDemostracionKitModal(context);
                    },
                    icon: const Icon(Icons.remove_red_eye_rounded, size: 16, color: Color(0xFF1E3A8A)),
                    label: const Text('Ver Muestra del Kit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('¡Entendido!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra una demostración interactiva con casos reales preconfigurados (Niño, Adolescente, Adulto)
  /// para que la familia vea cómo queda el producto final una vez completado el formulario y se anime a probarlo
  void _mostrarDemostracionKitModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<FamiliarProfile> ejemplos = [
      FamiliarProfile(
        id: 'demo_nino',
        nombreCompleto: 'Lucas Gael Quispe Torres',
        parentesco: 'Hijo/a',
        edad: 8,
        dni: '73928104',
        telefonoContacto: '948269740',
        tipoSangre: 'O+',
        condicionEspecial: 'Ninguna',
        estatura: '1.25 m',
        contextura: 'Delgada',
        colorPiel: 'Trigueña',
        colorCabello: 'Negro',
        senasParticulares: 'Pecosas en la nariz y lunar en mejilla izquierda',
        datosMedicos: 'Alérgico a la penicilina y picaduras',
        ropaDelDia: 'Buzo escolar azul marino con zapatillas negras',
      ),
      FamiliarProfile(
        id: 'demo_joven',
        nombreCompleto: 'Mateo Alejandro Flores Vega',
        parentesco: 'Hijo/a',
        edad: 15,
        dni: '71829402',
        telefonoContacto: '987654321',
        tipoSangre: 'A+',
        condicionEspecial: 'Usa lentes / Dificultad visual',
        estatura: '1.68 m',
        contextura: 'Atlética',
        colorPiel: 'Clara',
        colorCabello: 'Castaño oscuro',
        senasParticulares: 'Cicatriz pequeña en ceja izquierda',
        datosMedicos: 'Miopía leve (usa anteojos de marco negro)',
        ropaDelDia: 'Casaca deportiva negra, jean azul y zapatillas blancas',
      ),
      FamiliarProfile(
        id: 'demo_adulto',
        nombreCompleto: 'Alberto Mendoza Huamán',
        parentesco: 'Abuelo/a',
        edad: 68,
        dni: '09817264',
        telefonoContacto: '948269740',
        tipoSangre: 'B+',
        condicionEspecial: 'Alzheimer / Pérdida de memoria',
        estatura: '1.65 m',
        contextura: 'Regular',
        colorPiel: 'Morena',
        colorCabello: 'Canoso',
        senasParticulares: 'Bigote canoso y lunar en cuello',
        datosMedicos: 'Hipertensión arterial - Requiere Losartán 50mg cada mañana',
        ropaDelDia: 'Chompa de lana gris, pantalón de vestir marrón y gorra azul',
      ),
    ];

    int personaIndex = 0;
    int tipoProducto = 0; // 0: Vertical (Cuello), 1: Horizontal (Billetera), 2: Afiche Oficial A4

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDemoState) {
          final perfilActual = ejemplos[personaIndex];

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.90,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cabecera del Showcase
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1E40AF),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(child: Image.asset('assets/icons/icon_police.png', fit: BoxFit.contain)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Muestra del Producto Final (Kit Familiar)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Así es exactamente como se verá tu familiar tras llenar el formulario:',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Selector de Persona de Ejemplo (Niño, Adolescente, Adulto)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPersonaChip(
                        label: '🧒 Niño (8 años) - Lucas',
                        sublabel: 'Pequeño Protegido',
                        active: personaIndex == 0,
                        activeColor: const Color(0xFF0284C7),
                        onTap: () => setDemoState(() => personaIndex = 0),
                      ),
                      const SizedBox(width: 8),
                      _buildPersonaChip(
                        label: '🧑 Adolescente (15 años) - Mateo',
                        sublabel: 'ID Estudiantil Tech',
                        active: personaIndex == 1,
                        activeColor: const Color(0xFF4F46E5),
                        onTap: () => setDemoState(() => personaIndex = 1),
                      ),
                      const SizedBox(width: 8),
                      _buildPersonaChip(
                        label: '👴 Adulto Mayor (68 años) - Don Alberto',
                        sublabel: 'Credencial Médica SOS',
                        active: personaIndex == 2,
                        activeColor: const Color(0xFF1E3A8A),
                        onTap: () => setDemoState(() => personaIndex = 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Selector de Formato del Kit (Vertical Cuello, Horizontal Billetera, Afiche)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFormatoPill(
                          label: '📿 Cuello (Vertical)',
                          active: tipoProducto == 0,
                          onTap: () => setDemoState(() => tipoProducto = 0),
                        ),
                      ),
                      Expanded(
                        child: _buildFormatoPill(
                          label: '💳 Billetera (Horizontal)',
                          active: tipoProducto == 1,
                          onTap: () => setDemoState(() => tipoProducto = 1),
                        ),
                      ),
                      Expanded(
                        child: _buildFormatoPill(
                          label: '📢 Afiche Oficial A4',
                          active: tipoProducto == 2,
                          onTap: () => setDemoState(() => tipoProducto = 2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Visor del Producto Seleccionado
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: tipoProducto == 0
                          ? CarnetVisualPreviewWidget(
                              familiar: perfilActual,
                              inicialOrientacion: CarnetOrientacion.vertical,
                            )
                          : (tipoProducto == 1
                              ? CarnetVisualPreviewWidget(
                                  familiar: perfilActual,
                                  inicialOrientacion: CarnetOrientacion.horizontal,
                                )
                              : AficheVisualPreviewWidget(
                                  familiar: perfilActual,
                                  ultimaUbicacion: 'Lima, Perú',
                                )),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Botón Call to Action para motivar a probar con su propio familiar
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddEditDialog();
                    },
                    icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      '¡ME ANIMO! CREAR KIT PARA MI FAMILIAR AHORA',
                      style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPersonaChip({
    required String label,
    required String sublabel,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? activeColor : Colors.grey.shade300, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 9.5,
                color: active ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatoPill({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 3, offset: const Offset(0, 1)),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w900 : FontWeight.w500,
            color: active ? const Color(0xFF1E40AF) : Colors.grey.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildGuiaCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

