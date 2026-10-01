import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/session_service.dart';
import '../../../services/gps_location_service.dart';
import '../../../common/constants/peru_locations.dart';
import '../../common_widgets/scale_on_tap.dart';
import '../../common_widgets/tactile_surface_container.dart';

/// Panel de Perfil de Usuario Ciudadano estilo AlToque.
/// Permite visualizar y modificar ÚNICAMENTE los 4 campos solicitados:
/// 1. Nombre Completo
/// 2. Celular
/// 3. Departamento
/// 4. Provincia
/// Incluye detección automática de ubicación por GPS y sincronización con Firestore y SharedPreferences.
class CitizenProfilePanel extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String? initialDepartamento;
  final String? initialProvincia;
  final Function(String fullName, String celular, String departamento, String provincia)? onUserUpdated;

  const CitizenProfilePanel({
    super.key,
    required this.initialName,
    this.initialPhone = '',
    this.initialDepartamento,
    this.initialProvincia,
    this.onUserUpdated,
  });

  /// Muestra el panel modal en la parte inferior con esquinas redondeadas y estilo táctil 3D
  static Future<void> show(
    BuildContext context, {
    required String initialName,
    String initialPhone = '',
    String? initialDepartamento,
    String? initialProvincia,
    String? initialDni, // Mantenido para retrocompatibilidad pero ignorado
    Function(String fullName, String departamento, String provincia)? onUserUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CitizenProfilePanel(
        initialName: initialName,
        initialPhone: initialPhone,
        initialDepartamento: initialDepartamento,
        initialProvincia: initialProvincia,
        onUserUpdated: (name, phone, dept, prov) {
          if (onUserUpdated != null) {
            onUserUpdated(name, dept, prov);
          }
        },
      ),
    );
  }

  @override
  State<CitizenProfilePanel> createState() => _CitizenProfilePanelState();
}

class _CitizenProfilePanelState extends State<CitizenProfilePanel> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDetectingGps = false;

  late TextEditingController _nombreCompletoController;
  late TextEditingController _celularController;
  String? _selectedDepartamento;
  String? _selectedProvincia;

  final List<String> _departamentosPeru = PeruLocations.departamentos;

  @override
  void initState() {
    super.initState();
    _nombreCompletoController = TextEditingController(text: widget.initialName.trim());
    _celularController = TextEditingController(text: widget.initialPhone.trim());
    final initialDept = widget.initialDepartamento ?? 'LIMA';
    final matchedDept = PeruLocations.departamentos.firstWhere(
      (d) => PeruLocations.normalize(d) == PeruLocations.normalize(initialDept),
      orElse: () => 'LIMA',
    );
    _selectedDepartamento = matchedDept;
    _selectedProvincia = PeruLocations.matchProvincia(matchedDept, widget.initialProvincia);

    _loadExistingUserData();
  }

  Future<void> _loadExistingUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('ciudadanos').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          if (data != null) {
            setState(() {
              final nombres = data['nombres']?.toString() ?? '';
              final apellidos = data['apellidos']?.toString() ?? '';
              final full = data['nombre_completo']?.toString() ?? '$nombres $apellidos'.trim();
              if (full.isNotEmpty) {
                _nombreCompletoController.text = full.toUpperCase();
              } else if (user.displayName != null && user.displayName!.isNotEmpty) {
                _nombreCompletoController.text = user.displayName!.toUpperCase();
              }

              final tel = data['telefono']?.toString() ?? data['celular']?.toString() ?? '';
              if (tel.isNotEmpty) {
                _celularController.text = tel;
              }

              final dept = data['departamento']?.toString();
              if (dept != null && dept.isNotEmpty) {
                final matchedDept = PeruLocations.departamentos.firstWhere(
                  (d) => PeruLocations.normalize(d) == PeruLocations.normalize(dept),
                  orElse: () => _selectedDepartamento ?? 'LIMA',
                );
                _selectedDepartamento = matchedDept;
              }

              final prov = data['provincia']?.toString();
              if (prov != null && prov.isNotEmpty) {
                _selectedProvincia = PeruLocations.matchProvincia(_selectedDepartamento ?? 'LIMA', prov);
              }
            });
          }
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final storedDept = prefs.getString('user_departamento') ?? prefs.getString('user_department');
        final storedProv = prefs.getString('user_provincia');
        final storedPhone = prefs.getString('last_phone_number');
        if (mounted) {
          setState(() {
            if (storedDept != null && storedDept.isNotEmpty) {
              final matchedDept = PeruLocations.departamentos.firstWhere(
                (d) => PeruLocations.normalize(d) == PeruLocations.normalize(storedDept),
                orElse: () => _selectedDepartamento ?? 'LIMA',
              );
              _selectedDepartamento = matchedDept;
            }
            if (storedProv != null && storedProv.isNotEmpty) {
              _selectedProvincia = PeruLocations.matchProvincia(_selectedDepartamento ?? 'LIMA', storedProv);
            }
            if (storedPhone != null && storedPhone.isNotEmpty) {
              _celularController.text = storedPhone;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[PROFILE] Error al cargar datos: $e');
    }
  }

  @override
  void dispose() {
    _nombreCompletoController.dispose();
    _celularController.dispose();
    super.dispose();
  }

  /// Detecta automáticamente departamento y provincia por GPS
  Future<void> _detectLocationWithGps() async {
    setState(() => _isDetectingGps = true);
    HapticFeedback.lightImpact();

    try {
      final result = await GpsLocationService.getCurrentLocation(requestPermission: true);
      if (result != null && mounted) {
        setState(() {
          _selectedDepartamento = result.departamento;
          _selectedProvincia = result.provincia;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0284C7),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GPS detectado: ${result.provincia}, ${result.departamento}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[PROFILE] Error detectando GPS: $e');
    } finally {
      if (mounted) {
        setState(() => _isDetectingGps = false);
      }
    }
  }

  Future<void> _saveProfileChanges() async {
    final nombreCompleto = _nombreCompletoController.text.trim().toUpperCase();
    final celular = _celularController.text.trim();
    final rawDept = _selectedDepartamento ?? 'LIMA';
    final departamento = PeruLocations.departamentos.firstWhere(
      (d) => PeruLocations.normalize(d) == PeruLocations.normalize(rawDept),
      orElse: () => 'LIMA',
    );
    final provincia = PeruLocations.matchProvincia(departamento, _selectedProvincia);

    if (nombreCompleto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa tu nombre completo.')),
      );
      return;
    }

    if (celular.isNotEmpty && celular.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El número celular debe tener 9 dígitos.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance.collection('ciudadanos').doc(user.uid).set({
          'nombre_completo': nombreCompleto,
          'nombres': nombreCompleto,
          'apellidos': '',
          'telefono': celular,
          'celular': celular,
          'departamento': departamento,
          'provincia': provincia,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        try {
          await user.updateDisplayName(nombreCompleto);
        } catch (_) {}
      }

      await GpsLocationService.saveLocation(departamento, provincia);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_departamento', departamento);
      await prefs.setString('user_department', departamento);
      await prefs.setString('user_provincia', provincia);
      if (celular.isNotEmpty) {
        await prefs.setString('last_phone_number', celular);
      }

      await SessionService.saveUserSession(
        userId: user?.uid ?? 'demo_citizen',
        phoneNumber: celular,
        userRole: 'citizen',
        userName: nombreCompleto,
        departamento: departamento,
        provincia: provincia,
      );

      if (widget.onUserUpdated != null) {
        widget.onUserUpdated!(nombreCompleto, celular, departamento, provincia);
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Datos del ciudadano actualizados correctamente!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Error al guardar cambios: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final displayName = _nombreCompletoController.text.trim().isNotEmpty
        ? _nombreCompletoController.text.trim()
        : 'Ciudadano Registrado';
    final initialLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';

    final deptKey = PeruLocations.departamentos.firstWhere(
      (d) => PeruLocations.normalize(d) == PeruLocations.normalize(_selectedDepartamento ?? 'LIMA'),
      orElse: () => 'LIMA',
    );
    final provinciasDisponibles = PeruLocations.getProvincias(deptKey);
    if (_selectedProvincia != null) {
      _selectedProvincia = PeruLocations.matchProvincia(deptKey, _selectedProvincia);
    }
    if (_selectedProvincia == null && provinciasDisponibles.isNotEmpty) {
      _selectedProvincia = provinciasDisponibles.first;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: TactileSurfaceContainer(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.2,
            ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de agarre superior
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Cabecera del Panel con Título y Botón Cerrar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Editar Datos del Ciudadano' : 'Mi Perfil Ciudadano',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          'Alerta Desaparecidos PNP',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tarjeta Avatar estilo AlToque
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.22),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFF59E0B),
                            Color(0xFF10B981),
                            Color(0xFF06B6D4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            initialLetter,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Chip de Estado Activo y Ubicación
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.40),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF10B981),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ciudadano Activo • ${_selectedProvincia ?? 'Lima'}, ${_selectedDepartamento ?? 'LIMA'}',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Vista de Información o Formulario de Edición (SOLO 4 CAMPOS)
              if (!_isEditing) ...[
                // =============================================================
                // MODO VISTA: SOLO 4 CAMPOS
                // =============================================================
                _buildInfoTile(
                  icon: Icons.person_rounded,
                  label: 'NOMBRE COMPLETO',
                  value: displayName,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildInfoTile(
                  icon: Icons.phone_iphone_rounded,
                  label: 'NÚMERO DE CELULAR',
                  value: _celularController.text.isNotEmpty
                      ? _celularController.text
                      : 'No registrado',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildInfoTile(
                  icon: Icons.map_rounded,
                  label: 'DEPARTAMENTO',
                  value: _selectedDepartamento ?? 'LIMA',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildInfoTile(
                  icon: Icons.location_city_rounded,
                  label: 'PROVINCIA',
                  value: _selectedProvincia ?? 'Lima',
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                // Botón Editar Datos
                ScaleOnTap(
                  onTap: () => setState(() => _isEditing = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Editar Datos',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // =============================================================
                // MODO EDICIÓN: SOLO 4 CAMPOS + DETECCIÓN GPS
                // =============================================================
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Solo se edita tu Nombre, Celular, Departamento y Provincia para ubicar las alertas cercanas.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 1. Nombre Completo
                _buildInputField(
                  controller: _nombreCompletoController,
                  label: 'Nombre Completo',
                  icon: Icons.person_rounded,
                  isDark: isDark,
                  keyboardType: TextInputType.name,
                ),

                const SizedBox(height: 12),

                // 2. Celular
                _buildInputField(
                  controller: _celularController,
                  label: 'Número de Celular',
                  icon: Icons.phone_iphone_rounded,
                  isDark: isDark,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                ),

                const SizedBox(height: 12),

                // Botón para detectar ubicación por GPS
                ScaleOnTap(
                  onTap: _isDetectingGps ? null : _detectLocationWithGps,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: isDark ? 0.20 : 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.40),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isDetectingGps
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _isDetectingGps ? 'Detectando por GPS...' : 'Usar mi ubicación GPS actual',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 3. Selector de Departamento
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Departamento',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          width: 1.2,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _departamentosPeru.contains(_selectedDepartamento)
                              ? _selectedDepartamento
                              : 'LIMA',
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          items: _departamentosPeru.map((dept) {
                            return DropdownMenuItem<String>(
                              value: dept,
                              child: Text(
                                dept,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedDepartamento = val;
                                final provs = PeruLocations.getProvincias(val);
                                _selectedProvincia = provs.isNotEmpty ? provs.first : null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 4. Selector de Provincia
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provincia',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          width: 1.2,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: provinciasDisponibles.contains(_selectedProvincia)
                              ? _selectedProvincia
                              : (provinciasDisponibles.isNotEmpty ? provinciasDisponibles.first : null),
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          items: provinciasDisponibles.map((prov) {
                            return DropdownMenuItem<String>(
                              value: prov,
                              child: Text(
                                prov,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedProvincia = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Botones Cancelar y Guardar
                Row(
                  children: [
                    Expanded(
                      child: ScaleOnTap(
                        onTap: () => setState(() => _isEditing = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ScaleOnTap(
                        onTap: _isSaving ? null : _saveProfileChanges,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF047857)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF059669).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Guardar Cambios',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            prefixIcon: Icon(icon, size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF10B981),
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
