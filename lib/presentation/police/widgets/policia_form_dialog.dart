import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/policia.dart';
import '../view_models/policia_management_view_model.dart';

class PoliciaFormDialog extends StatefulWidget {
  final Policia? policia;
  final PoliciaManagementViewModel viewModel;

  const PoliciaFormDialog({super.key, this.policia, required this.viewModel});

  @override
  State<PoliciaFormDialog> createState() => _PoliciaFormDialogState();
}

class _PoliciaFormDialogState extends State<PoliciaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _departamentoController = TextEditingController();
  final _unidadController = TextEditingController();
  final _rangoController = TextEditingController();
  final _cipController = TextEditingController();

  String _selectedRol = 'policia';
  bool _isAdmin = false;
  bool _isEditing = false;

  final List<String> _departamentos = [
    'AMAZONAS',
    'ÁNCASH',
    'APURÍMAC',
    'AREQUIPA',
    'AYACUCHO',
    'CAJAMARCA',
    'CALLAO',
    'CUSCO',
    'HUANCAVELICA',
    'HUÁNUCO',
    'ICA',
    'JUNÍN',
    'LA LIBERTAD',
    'LAMBAYEQUE',
    'LIMA',
    'LORETO',
    'MADRE DE DIOS',
    'MOQUEGUA',
    'PASCO',
    'PIURA',
    'PUNO',
    'SAN MARTÍN',
    'TACNA',
    'TUMBES',
    'UCAYALI',
  ];

  final List<String> _rangos = [
    // Suboficiales (menor rango)
    'S3 PNP',
    'S2 PNP',
    'S1 PNP',

    // Suboficiales Técnicos
    'ST3 PNP',
    'ST2 PNP',
    'ST1 PNP',

    // Suboficiales Superiores
    'SB PNP',
    'SS PNP',

    // Oficiales
    'ALFRZ PNP',
    'TNTE PNP',
    'CAP PNP',

    // Oficiales Superiores
    'MAY PNP',
    'CMDTE PNP',
    'CRNL PNP',

    // General (mayor rango)
    'GNRAL PNP',
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.policia != null;

    if (_isEditing) {
      _nombreController.text = widget.policia!.nombre;
      _apellidoController.text = widget.policia!.apellido;
      // Extraer solo los 9 dígitos del teléfono (sin el +51)
      final telefono = widget.policia!.telefono;
      if (telefono.startsWith('+51') && telefono.length == 12) {
        _telefonoController.text = telefono.substring(3);
      } else {
        _telefonoController.text = telefono;
      }
      _departamentoController.text = widget.policia!.departamento;
      _unidadController.text = widget.policia!.unidad;
      _rangoController.text = widget.policia!.rango;
      _cipController.text = widget.policia!.numeroCip;
      _selectedRol = widget.policia!.rol;
      _isAdmin = widget.policia!.admin;
    } else {
      // Para nuevos usuarios, dejar el campo vacío (solo mostrarán los 9 dígitos)
      _telefonoController.text = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PoliciaManagementViewModel>.value(
      value: widget.viewModel,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildPersonalInfoSection(),
                        const SizedBox(height: 20),
                        _buildContactInfoSection(),
                        const SizedBox(height: 20),
                        _buildProfessionalInfoSection(),
                        const SizedBox(height: 20),
                        _buildPermissionsSection(),
                      ],
                    ),
                  ),
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isEditing ? Icons.edit : Icons.person_add,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Editar Policía' : 'Nuevo Policía',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _isEditing
                      ? 'Modificar información'
                      : 'Registrar nueva cuenta',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection('Información Personal', Icons.person, [
      _buildTextField(
        controller: _nombreController,
        label: 'Nombres',
        icon: Icons.person_outline,
        validator: (value) {
          if (value?.trim().isEmpty ?? true) {
            return 'Los nombres son requeridos';
          }
          return null;
        },
        onChanged: (value) {
          final cursorPosition = _nombreController.selection.start;
          final upperValue = value.toUpperCase();
          _nombreController.value = _nombreController.value.copyWith(
            text: upperValue,
            selection: TextSelection.collapsed(offset: cursorPosition),
          );
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _apellidoController,
        label: 'Apellidos',
        icon: Icons.person_outline,
        validator: (value) {
          if (value?.trim().isEmpty ?? true) {
            return 'Los apellidos son requeridos';
          }
          return null;
        },
        onChanged: (value) {
          final cursorPosition = _apellidoController.selection.start;
          final upperValue = value.toUpperCase();
          _apellidoController.value = _apellidoController.value.copyWith(
            text: upperValue,
            selection: TextSelection.collapsed(offset: cursorPosition),
          );
        },
      ),
    ]);
  }

  Widget _buildContactInfoSection() {
    return _buildSection('Información de Contacto', Icons.contact_phone, [
      _buildPhoneNumberField(),
    ]);
  }

  Widget _buildProfessionalInfoSection() {
    return _buildSection('Información Profesional', Icons.work, [
      _buildDropdownField(
        value:
            _departamentoController.text.isEmpty
                ? null
                : _departamentoController.text,
        label: 'Departamento',
        icon: Icons.location_on,
        items: _departamentos,
        onChanged: (value) {
          _departamentoController.text = value ?? '';
        },
        validator: (value) {
          if (value?.trim().isEmpty ?? true) {
            return 'El departamento es requerido';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _unidadController,
        label: 'Unidad',
        icon: Icons.business,
        validator: (value) {
          if (value?.trim().isEmpty ?? true) {
            return 'La unidad es requerida';
          }
          return null;
        },
        onChanged: (value) {
          final cursorPosition = _unidadController.selection.start;
          final upperValue = value.toUpperCase();
          _unidadController.value = _unidadController.value.copyWith(
            text: upperValue,
            selection: TextSelection.collapsed(offset: cursorPosition),
          );
        },
      ),
      const SizedBox(height: 16),
      _buildDropdownField(
        value: _rangoController.text.isEmpty ? null : _rangoController.text,
        label: 'Rango',
        icon: Icons.military_tech,
        items: _rangos,
        onChanged: (value) {
          _rangoController.text = value ?? '';
        },
        validator: (value) {
          if (value?.trim().isEmpty ?? true) {
            return 'El rango es requerido';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _cipController,
        label: 'Número CIP',
        icon: Icons.badge,
        validator: (value) {
          if (value?.trim().isEmpty ?? true) {
            return 'El CIP es requerido';
          }
          return null;
        },
        onChanged: (value) {
          final cursorPosition = _cipController.selection.start;
          final upperValue = value.toUpperCase();
          _cipController.value = _cipController.value.copyWith(
            text: upperValue,
            selection: TextSelection.collapsed(offset: cursorPosition),
          );
        },
      ),
    ]);
  }

  Widget _buildPermissionsSection() {
    return _buildSection('Permisos y Rol', Icons.admin_panel_settings, [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[50]!, Colors.grey[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header elegante
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      _isAdmin
                          ? [Colors.orange.shade400, Colors.orange.shade600]
                          : [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isAdmin ? Icons.admin_panel_settings : Icons.security,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nivel de Acceso',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isAdmin ? 'ADMIN' : 'BASICO',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Contenido de selección
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Opciones de privilegio
                  Row(
                    children: [
                      Expanded(
                        child: _buildPrivilegeOption(
                          title: 'BASICO',
                          subtitle: '',
                          icon: Icons.person_outline,
                          isSelected: !_isAdmin,
                          onTap: () => setState(() => _isAdmin = false),
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPrivilegeOption(
                          title: 'ADMIN',
                          subtitle: '',
                          icon: Icons.admin_panel_settings_outlined,
                          isSelected: _isAdmin,
                          onTap: () => setState(() => _isAdmin = true),
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildPrivilegeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    // Definir colores específicos basados en el color base
    final Color darkColor =
        color == Colors.orange ? Colors.orange.shade700 : Colors.blue.shade700;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : [],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? darkColor : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SELECCIONADO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1565C0), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
      items:
          items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: AnimatedBuilder(
        animation: widget.viewModel,
        builder: (context, child) {
          final isLoading =
              _isEditing
                  ? widget.viewModel.updateState == RequestState.Loading
                  : widget.viewModel.createState == RequestState.Loading;

          return Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(_isEditing ? 'Actualizar' : 'Crear Policía'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Usar directamente el viewModel pasado como parámetro
    final viewModel = widget.viewModel;

    // Construir el número completo con +51
    final telefonoCompleto = '+51${_telefonoController.text.trim()}';

    final policia = Policia(
      uid: _isEditing ? widget.policia!.uid : '',
      nombre: _nombreController.text.trim(),
      apellido: _apellidoController.text.trim(),
      telefono: telefonoCompleto,
      departamento: _departamentoController.text.trim(),
      unidad: _unidadController.text.trim(),
      rango: _rangoController.text.trim(),
      numeroCip: _cipController.text.trim(),
      rol: _selectedRol,
      admin: _isAdmin,
      fechaRegistro:
          _isEditing ? widget.policia!.fechaRegistro : DateTime.now(),
    );

    try {
      if (_isEditing) {
        await viewModel.updatePolicia(policia);
      } else {
        await viewModel.createPolicia(policia);
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessMessage(viewModel.successMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage(viewModel.errorMessage);
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _departamentoController.dispose();
    _unidadController.dispose();
    _rangoController.dispose();
    _cipController.dispose();
    super.dispose();
  }

  Widget _buildPhoneNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teléfono',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Prefijo fijo +51
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  border: Border(right: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '+51',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              // Campo para los 9 dígitos
              Expanded(
                child: TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.number,
                  maxLength: 9,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  decoration: const InputDecoration(
                    hintText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    counterText: '', // Ocultar el contador de caracteres
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'El teléfono es requerido';
                    }
                    if (value!.length != 9) {
                      return 'Debe tener exactamente 9 dígitos';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ingrese los 9 dígitos de su número celular',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
