import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../citizen/screens/citizen_home_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'welcome_screen.dart'; // Añadir esta importación

class CitizenRegistrationFormScreen extends StatefulWidget {
  final String uid;
  final String phoneNumber;

  const CitizenRegistrationFormScreen({
    super.key,
    required this.uid,
    required this.phoneNumber,
  });

  @override
  State<CitizenRegistrationFormScreen> createState() =>
      _CitizenRegistrationFormScreenState();
}

class _CitizenRegistrationFormScreenState
    extends State<CitizenRegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombresController = TextEditingController();
  final TextEditingController _apellidosController = TextEditingController();
  String? _selectedDepartamento;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Lista de departamentos del Perú
  final List<Map<String, String>> _departamentos = [
    {'id': '01', 'name': 'AMAZONAS'},
    {'id': '02', 'name': 'ÁNCASH'},
    {'id': '03', 'name': 'APURÍMAC'},
    {'id': '04', 'name': 'AREQUIPA'},
    {'id': '05', 'name': 'AYACUCHO'},
    {'id': '06', 'name': 'CAJAMARCA'},
    {'id': '07', 'name': 'CALLAO'},
    {'id': '08', 'name': 'CUSCO'},
    {'id': '09', 'name': 'HUANCAVELICA'},
    {'id': '10', 'name': 'HUÁNUCO'},
    {'id': '11', 'name': 'ICA'},
    {'id': '12', 'name': 'JUNÍN'},
    {'id': '13', 'name': 'LA LIBERTAD'},
    {'id': '14', 'name': 'LAMBAYEQUE'},
    {'id': '15', 'name': 'LIMA'},
    {'id': '16', 'name': 'LORETO'},
    {'id': '17', 'name': 'MADRE DE DIOS'},
    {'id': '18', 'name': 'MOQUEGUA'},
    {'id': '19', 'name': 'PASCO'},
    {'id': '20', 'name': 'PIURA'},
    {'id': '21', 'name': 'PUNO'},
    {'id': '22', 'name': 'SAN MARTÍN'},
    {'id': '23', 'name': 'TACNA'},
    {'id': '24', 'name': 'TUMBES'},
    {'id': '25', 'name': 'UCAYALI'},
  ];

  bool get _isFormValid {
    return _nombresController.text.trim().isNotEmpty &&
        _apellidosController.text.trim().isNotEmpty &&
        _selectedDepartamento != null;
  }

  void _validateForm() {
    setState(() {});
  }

  // Añadir estas funciones de validación después del método _validateForm()
  String? _validarNombres(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor, ingrese los nombres.';
    }
    final names = value.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (names.length > 3) {
      return 'Máximo 3 nombres permitidos.';
    }
    return null;
  }

  String? _validarApellidos(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor, ingrese los apellidos.';
    }
    final surnames = value.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (surnames.length != 2) {
      return 'Se requieren exactamente 2 apellidos.';
    }
    return null;
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool isRequired = true,
  }) {
    bool isValid = controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color:
            isValid
                ? Colors.green.withOpacity(0.1)
                : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green : Colors.white.withOpacity(0.3),
          width: isValid ? 2 : 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: TextStyle(color: isValid ? Colors.green : Colors.white),
        textCapitalization: TextCapitalization.characters, // Convertir a mayúsculas mientras escribe
        inputFormatters: [
          // Solo permitir letras, acentos, ñ y espacios
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]')),
        ],
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
          labelStyle: TextStyle(
            color: isValid ? Colors.green : Colors.white.withOpacity(0.8),
          ),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: Icon(
            icon,
            color: isValid ? Colors.green : Colors.white.withOpacity(0.7),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          errorStyle: const TextStyle(color: Colors.orange),
        ),
        onChanged: (_) => _validateForm(),
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }

  Widget _buildModernDropdown() {
    bool isValid = _selectedDepartamento != null;

    return Container(
      decoration: BoxDecoration(
        color:
            isValid
                ? Colors.green.withOpacity(0.1)
                : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green : Colors.white.withOpacity(0.3),
          width: isValid ? 2 : 1,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedDepartamento,
        items:
            _departamentos.map((dept) {
              return DropdownMenuItem<String>(
                value: dept['name'],
                child: Text(dept['name']!),
              );
            }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedDepartamento = value;
          });
          _validateForm();
        },
        style: TextStyle(color: isValid ? Colors.green : Colors.white),
        dropdownColor: const Color(0xFF1A237E),
        decoration: InputDecoration(
          labelText: 'Departamento *',
          labelStyle: TextStyle(
            color: isValid ? Colors.green : Colors.white.withOpacity(0.8),
          ),
          prefixIcon: Icon(
            Icons.location_on,
            color: isValid ? Colors.green : Colors.white.withOpacity(0.7),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator:
            (value) => value == null ? 'Seleccione su departamento' : null,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Crear el documento en Firestore con la estructura solicitada
      final now = DateTime.now();
      final formatter = DateFormat(
        'd \'de\' MMMM \'de\' y, h:mm:ss a \'UTC-5\'',
        'es',
      );

      await FirebaseFirestore.instance
          .collection('ciudadanos')
          .doc(widget.uid)
          .set({
            'apellidos': _apellidosController.text.trim().toUpperCase(),
            'departamento': _selectedDepartamento!,
            'fecha_registro': formatter.format(now),
            'nombres': _nombresController.text.trim().toUpperCase(),
            'rol': 'ciudadano',
            'telefono': widget.phoneNumber,
            'vetado': false, // Campo vetado siempre en false para nuevos registros
          });

      // Guardar el rol en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', 'citizen');

      // Navegar a la pantalla principal del ciudadano
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CitizenHomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al registrar usuario: $e';
        _isSubmitting = false;
      });
    }
  }

  // Función para manejar cancelación o botón atrás
  Future<bool> _onWillPop() async {
    return await _showCancelDialog() ?? false;
  }

  Future<bool?> _showCancelDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade600,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cancelar Registro',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Estás seguro de que deseas cancelar el registro? Se perderán todos los datos ingresados.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Continuar Registro',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                _navigateToWelcome();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sí, Cancelar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToWelcome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1A237E), // Azul marino profundo
                Color(0xFF3949AB), // Azul índigo
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      // Encabezado con botón cancelar
                      Row(
                        children: [
                          // Botón Cancelar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () => _showCancelDialog(),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Registro',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48), // Para balancear el botón cancelar
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Encabezado principal
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_add,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Completar Registro',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Por favor, complete sus datos personales',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // Formulario
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Datos Personales',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Campo Nombres
                            _buildModernTextField(
                              controller: _nombresController,
                              label: 'Nombres',
                              hint: 'Ingrese sus nombres (máx. 3)',
                              icon: Icons.person,
                              validator: _validarNombres,
                            ),

                            const SizedBox(height: 16),

                            // Campo Apellidos
                            _buildModernTextField(
                              controller: _apellidosController,
                              label: 'Apellidos',
                              hint: 'Ingrese sus dos apellidos',
                              icon: Icons.person_outline,
                              validator: _validarApellidos,
                            ),

                            const SizedBox(height: 16),

                            // Dropdown Departamento
                            _buildModernDropdown(),

                            const SizedBox(height: 24),

                            // Mensaje de términos de uso
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,  // Cambiado a un icono de advertencia
                                        color: Colors.amber,
                                        size: 24,  // Tamaño aumentado
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'TÉRMINOS DE USO IMPORTANTES',
                                          style: TextStyle(
                                            color: Colors.amber.shade300,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'Al registrarte, te comprometes a: ',
                                        ),
                                        TextSpan(
                                          text: 'USAR ESTA APLICACIÓN ÚNICAMENTE PARA REPORTAR CASOS REALES',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade300,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: ' de personas desaparecidas. ',
                                        ),
                                        TextSpan(
                                          text: 'EL USO INDEBIDO RESULTARÁ EN RESTRICCIÓN DE ACCESO',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade300,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: ' y en casos graves ',
                                        ),
                                        TextSpan(
                                          text: 'SE TOMARÁN ACCIONES LEGALES',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade300,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: '.',
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.justify,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Información del teléfono
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Teléfono registrado:',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          widget.phoneNumber,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Mensaje de error
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Botón de envío
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              _isSubmitting || !_isFormValid ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isFormValid ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: _isFormValid ? 8 : 2,
                          ),
                          child:
                              _isSubmitting
                                  ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Registrando...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                  : const Text(
                                    'Completar Registro',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    super.dispose();
  }
}
