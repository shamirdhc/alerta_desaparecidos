import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Modelo de datos para Comisaría
class Comisaria {
  final int id;
  final String nombre;
  final String unidad;
  final String telefono;
  final String departamento;
  final String provincia;
  final String distrito;

  Comisaria({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.telefono,
    required this.departamento,
    required this.provincia,
    required this.distrito,
  });
}

class SearchEssaysScreen extends StatefulWidget {
  const SearchEssaysScreen({super.key});

  @override
  State<SearchEssaysScreen> createState() => _SearchEssaysScreenState();
}

class _SearchEssaysScreenState extends State<SearchEssaysScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDepartamento;
  List<Comisaria> _filteredComisarias = [];
  
  // Lista de departamentos ordenados alfabéticamente
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

  // Datos de comisarías de Apurímac (basado en tu Excel)
  final List<Comisaria> _comisariasApurimac = [
    Comisaria(id: 1, nombre: 'UNIDAD DE ROBO DE VEHÍCULOS', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '920020883', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'ANDAHUAYLAS'),
    Comisaria(id: 2, nombre: 'CENTRAL DE OPERACIONES ANDAHUAYLAS', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '967831397', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'ANDAHUAYLAS'),
    Comisaria(id: 3, nombre: 'UNIDAD DE SEGURIDAD VIAL (TRÁNSITO)', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '945277480', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'ANDAHUAYLAS'),
    Comisaria(id: 4, nombre: 'ESCUADRÓN DE EMERGENCIA ANDAHUAYLAS', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980122088', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'ANDAHUAYLAS'),
    Comisaria(id: 5, nombre: 'DEPINCRI ANDAHUAYLAS', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980122444', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'ANDAHUAYLAS'),
    Comisaria(id: 6, nombre: 'COMISARÍA SECTORIAL DE CHINCHEROS', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980122445', departamento: 'APURÍMAC', provincia: 'CHINCHEROS', distrito: 'CHINCHEROS'),
    Comisaria(id: 7, nombre: 'COMISARÍA SECTORIAL DE ANDAHUAYLAS', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980122027', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'ANDAHUAYLAS'),
    Comisaria(id: 8, nombre: 'COMISARÍA DE ANDARAPA', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980122385', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'ANDARAPA'),
    Comisaria(id: 9, nombre: 'COMISARÍA DE FAMILIA', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '957832971', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'ANDAHUAYLAS'),
    Comisaria(id: 10, nombre: 'COMISARÍA DE HUACCANA', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '952877411', departamento: 'APURÍMAC', provincia: 'CHINCHEROS', distrito: 'HUACCANA'),
    Comisaria(id: 11, nombre: 'COMISARÍA DE HUANCARAMA', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '942118991', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'HUANCARAMA'),
    Comisaria(id: 12, nombre: 'COMISARÍA DE KISHUARA', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '957833499', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'KISHUARA'),
    Comisaria(id: 13, nombre: 'COMISARÍA DE OCOBAMBA', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980121607', departamento: 'APURÍMAC', provincia: 'CHINCHEROS', distrito: 'OCOBAMBA'),
    Comisaria(id: 14, nombre: 'COMISARÍA DE ONGOY', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '964609892', departamento: 'APURÍMAC', provincia: 'CHINCHEROS', distrito: 'ONGOY'),
    Comisaria(id: 15, nombre: 'COMISARÍA DE PACUCHA', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '958893584', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'PACUCHA'),
    Comisaria(id: 16, nombre: 'COMISARÍA DE RANRACANCHA', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '957833492', departamento: 'APURÍMAC', provincia: 'CHINCHEROS', distrito: 'RANRACANCHA'),
    Comisaria(id: 17, nombre: 'COMISARÍA DE S.A DE CACHI', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980121091', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'SAN ANTONIO DE CACHI'),
    Comisaria(id: 18, nombre: 'COMISARÍA DE SAN JERÓNIMO', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980122039', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'SAN JERÓNIMO'),
    Comisaria(id: 19, nombre: 'COMISARÍA DE S.M. DE CHICMO', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '943070460', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'SAN MIGUEL DE CHICMO'),
    Comisaria(id: 20, nombre: 'COMISARÍA DE TALAVERA', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980122026', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'TALAVERA'),
    Comisaria(id: 21, nombre: 'COMISARÍA DE URIPA', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980121439', departamento: 'APURÍMAC', provincia: 'CHINCHEROS', distrito: 'URIPA'),
    Comisaria(id: 22, nombre: 'PAP "CHACCRAMPA"', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980122034', departamento: 'APURÍMAC', provincia: 'ANDAHUAYLAS', distrito: 'CHACCRAMPA'),
    Comisaria(id: 23, nombre: 'DIVINCRI PNP ABANCAY', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '949649710', departamento: 'APURÍMAC', provincia: 'ABANCAY', distrito: 'ABANCAY'),
    Comisaria(id: 24, nombre: 'DIVOPUS PNP ABANCAY', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '964603380', departamento: 'APURÍMAC', provincia: 'ABANCAY', distrito: 'ABANCAY'),
    Comisaria(id: 25, nombre: 'TRÁNSITO PNP ABANCAY', unidad: 'REGIÓN POLICIAL APURÍMAC', telefono: '980122443', departamento: 'APURÍMAC', provincia: 'ABANCAY', distrito: 'ABANCAY'),
    // ... continúa con más comisarías de Apurímac según tu Excel
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectDepartamento(String departamento) {
    setState(() {
      _selectedDepartamento = departamento;
      if (departamento == 'APURÍMAC') {
        _filteredComisarias = _comisariasApurimac;
      } else {
        _filteredComisarias = [];
      }
    });
  }

  void _filterComisarias(String query) {
    if (_selectedDepartamento == null) return;
    
    setState(() {
      if (query.isEmpty) {
        if (_selectedDepartamento == 'APURÍMAC') {
          _filteredComisarias = _comisariasApurimac;
        }
      } else {
        _filteredComisarias = _comisariasApurimac.where((comisaria) {
          return comisaria.nombre.toLowerCase().contains(query.toLowerCase()) ||
                 comisaria.distrito.toLowerCase().contains(query.toLowerCase()) ||
                 comisaria.provincia.toLowerCase().contains(query.toLowerCase()) ||
                 comisaria.telefono.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo realizar la llamada')),
        );
      }
    }
  }

  void _showImplementationMessage(String departamento) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$departamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.construction,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'La agenda telefónica de comisarías para $departamento está en implementación.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Próximamente estará disponible.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_police, size: 28, color: Colors.blue),
                      SizedBox(width: 12),
                      Text(
                        'Agenda de Comisarías',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedDepartamento != null) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: _filterComisarias,
                      decoration: InputDecoration(
                        hintText: 'Buscar comisaría...',
                        prefixIcon: const Icon(Icons.search, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _selectedDepartamento == null
                  ? _buildDepartamentosGrid()
                  : _buildComisariasList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartamentosGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona un departamento:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _departamentos.length,
              itemBuilder: (context, index) {
                final departamento = _departamentos[index];
                final isApurimac = departamento == 'APURÍMAC';
                
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (isApurimac) {
                        _selectDepartamento(departamento);
                      } else {
                        _showImplementationMessage(departamento);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: isApurimac
                              ? [Colors.blue.shade400, Colors.blue.shade600]
                              : [Colors.grey.shade300, Colors.grey.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              departamento,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isApurimac ? Colors.white : Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (!isApurimac)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(
                                Icons.construction,
                                size: 16,
                                color: Colors.orange.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComisariasList() {
    return Column(
      children: [
        // Back button and department title
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDepartamento = null;
                    _filteredComisarias = [];
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.arrow_back, color: Colors.blue),
              ),
              Expanded(
                child: Text(
                  _selectedDepartamento!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              Text(
                '${_filteredComisarias.length} comisarías',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        
        // Comisarías list
        Expanded(
          child: _filteredComisarias.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No se encontraron comisarías',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredComisarias.length,
                  itemBuilder: (context, index) {
                    final comisaria = _filteredComisarias[index];
                    return _buildComisariaCard(comisaria);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildComisariaCard(Comisaria comisaria) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre de la comisaría
            Text(
              comisaria.nombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            // Ubicación
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${comisaria.distrito}, ${comisaria.provincia}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // Unidad
            Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    comisaria.unidad,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Teléfono y botón de llamada
            Row(
              children: [
                const Icon(Icons.phone, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comisaria.telefono,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(comisaria.telefono),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Llamar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}