import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/agenda_policial_service.dart';
import '../../../data/models/comisaria_model.dart';
import 'citizen_home_screen.dart';

class SearchEssaysScreen extends StatefulWidget {
  const SearchEssaysScreen({super.key});

  @override
  State<SearchEssaysScreen> createState() => _SearchEssaysScreenState();
}

class _SearchEssaysScreenState extends State<SearchEssaysScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late AnimationController _pulseController;

  List<String> _departamentosDisponibles = [];
  List<ComisariaModel> _comisarias = [];
  List<ComisariaModel> _comisariasFiltradas = [];

  String? _departamentoSeleccionado;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isInitialized = false;
  String _mensaje = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isInitialized = false;
      _mensaje = 'Conectando con base de datos PNP...';
      _errorMessage = null;
    });

    try {
      await AgendaPolicialService.inicializarSincronizacion();
      await _cargarDepartamentos();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _animationController.forward();
      }
    } catch (e) {
      print('Error en inicialización: $e');
      if (mounted) {
        setState(() {
          _mensaje = 'Error al conectar con el sistema';
          _errorMessage = e.toString();
          _isInitialized = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cargarDepartamentos() async {
    if (!mounted) return;

    try {
      final departamentos =
          await AgendaPolicialService.getDepartamentosDisponibles();

      if (mounted) {
        setState(() {
          _departamentosDisponibles = departamentos;
          if (departamentos.isNotEmpty) {
            _mensaje =
                '${departamentos.length} regiones policiales disponibles';
          } else {
            _mensaje = 'No se encontraron regiones';
          }
        });
      }
    } catch (e) {
      print('Error al cargar departamentos: $e');
      if (mounted) {
        setState(() {
          _mensaje = 'Error al cargar regiones policiales';
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _seleccionarDepartamento(String departamento) async {
    if (!mounted) return;

    setState(() {
      _departamentoSeleccionado = departamento;
      _isLoading = true;
      _mensaje = 'Localizando comisarías en $departamento...';
      _comisarias.clear();
      _comisariasFiltradas.clear();
      _searchController.clear();
      _errorMessage = null;
    });

    try {
      final comisarias =
          await AgendaPolicialService.cargarComisariasDepartamento(
            departamento,
          );

      if (mounted) {
        setState(() {
          _comisarias = comisarias;
          _comisariasFiltradas = comisarias;
          _mensaje = '${comisarias.length} unidades policiales activas';
        });
      }
    } catch (e) {
      print('Error al cargar comisarías: $e');
      if (mounted) {
        setState(() {
          _mensaje = 'Error al localizar unidades';
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (_departamentoSeleccionado == null || !mounted) return;

    if (query.isEmpty) {
      setState(() {
        _comisariasFiltradas = _comisarias;
        _isSearching = false;
      });
    } else {
      setState(() {
        _isSearching = true;
      });
      _buscarComisarias(query);
    }
  }

  Future<void> _buscarComisarias(String query) async {
    if (_departamentoSeleccionado == null || !mounted) return;

    try {
      final resultados = await AgendaPolicialService.buscarComisarias(
        _departamentoSeleccionado!,
        query,
      );

      if (mounted) {
        setState(() {
          _comisariasFiltradas = resultados;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error en búsqueda: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _realizarLlamada(String telefono) async {
    final Uri launchUri = Uri(scheme: 'tel', path: telefono);

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se puede realizar la llamada a $telefono'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al intentar llamar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildModernAppBar() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1565C0),
            const Color(0xFF1976D2),
            const Color(0xFF1E88E5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const CitizenHomeScreen(),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: FaIcon(
                        FontAwesomeIcons.arrowLeft,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'AGENDA POLICIAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Directorio de comisarías PNP',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.buildingShield,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: -1, duration: 800.ms).fadeIn();
  }

  Widget _buildDepartmentSelector() {
    if (!_isInitialized || _departamentosDisponibles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 70,
        borderRadius: 15,
        blur: 15,
        alignment: Alignment.center,
        border: 1,
        linearGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.mapLocationDot,
                  color: Color(0xFF1565C0),
                  size: 16,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _departamentoSeleccionado,
                    hint: Text(
                      'Seleccionar región policial',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    isExpanded: true,
                    icon: const FaIcon(
                      FontAwesomeIcons.chevronDown,
                      size: 14,
                      color: Color(0xFF1565C0),
                    ),
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    items:
                        _departamentosDisponibles.map((departamento) {
                          return DropdownMenuItem<String>(
                            value: departamento,
                            child: Row(
                              children: [
                                const FaIcon(
                                  FontAwesomeIcons.building,
                                  size: 14,
                                  color: Color(0xFF1565C0),
                                ),
                                const SizedBox(width: 10),
                                Text(departamento),
                              ],
                            ),
                          );
                        }).toList(),
                    onChanged: (String? value) {
                      if (value != null && mounted) {
                        _seleccionarDepartamento(value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: -0.5, duration: 800.ms).fadeIn();
  }

  Widget _buildSearchBar() {
    if (!_isInitialized || _departamentoSeleccionado == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 60,
        borderRadius: 15,
        blur: 15,
        alignment: Alignment.center,
        border: 1,
        linearGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    _isSearching
                        ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF1565C0),
                            ),
                          ),
                        )
                        : const FaIcon(
                          FontAwesomeIcons.magnifyingGlass,
                          color: Color(0xFF1565C0),
                          size: 16,
                        ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar comisaría...',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: -0.5, duration: 1000.ms).fadeIn();
  }

  Widget _buildComisariaCard(ComisariaModel comisaria, int index) {
    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: GlassmorphicContainer(
            width: double.infinity,
            height: 240,
            borderRadius: 20,
            blur: 20,
            alignment: Alignment.center,
            border: 3,
            linearGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1565C0).withOpacity(0.8),
                const Color(0xFF1976D2).withOpacity(0.6),
                const Color(0xFF1E88E5).withOpacity(0.4),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.2),
                    blurRadius: 25,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con nombre de la comisaría
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1565C0),
                                const Color(0xFF1976D2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1565C0).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const FaIcon(
                            FontAwesomeIcons.buildingShield,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comisaria.nombre,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF1565C0).withOpacity(0.2),
                                      const Color(0xFF1976D2).withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF1565C0,
                                    ).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'COMISARÍA PNP',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1565C0),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Información de ubicación
                    if (comisaria.provincia.isNotEmpty ||
                        comisaria.distrito.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE3F2FD),
                              const Color(0xFFBBDEFB),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF90CAF9),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF1565C0),
                                    const Color(0xFF1976D2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF1565C0,
                                    ).withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.locationDot,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${comisaria.provincia}${comisaria.provincia.isNotEmpty && comisaria.distrito.isNotEmpty ? ' - ' : ''}${comisaria.distrito}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D47A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Botón de llamada
                    if (comisaria.telefono.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4CAF50),
                              const Color(0xFF66BB6A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () => _realizarLlamada(comisaria.telefono),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const FaIcon(
                                    FontAwesomeIcons.phone,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    comisaria.telefono,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'LLAMAR',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 30 * index))
        .slideX(begin: 1, duration: 300.ms)
        .fadeIn();
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[300]!, Colors.grey[200]!],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: FaIcon(icon, size: 50, color: Colors.grey[600]),
              ).animate().scale(duration: 400.ms),

              const SizedBox(height: 25),

              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ).animate().fadeIn(delay: 150.ms),

              const SizedBox(height: 10),

              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ).animate().fadeIn(delay: 250.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: GlassmorphicContainer(
          width: double.infinity,
          height: 300,
          borderRadius: 25,
          blur: 20,
          alignment: Alignment.center,
          border: 2,
          linearGradient: LinearGradient(
            colors: [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)],
          ),
          borderGradient: LinearGradient(
            colors: [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.1)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.triangleExclamation,
                    size: 40,
                    color: Colors.red[700],
                  ),
                ).animate().scale(duration: 300.ms),

                const SizedBox(height: 20),

                Text(
                  'ERROR DE CONEXIÓN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                    letterSpacing: 1,
                  ),
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 10),

                Text(
                  _errorMessage ?? 'Error desconocido del sistema',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 25),

                Container(
                  width: double.infinity,
                  height: 45,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red[600]!, Colors.red[500]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _initializeService,
                      child: const Center(
                        child: Text(
                          'RECONECTAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate().slideY(begin: 0.5, delay: 350.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildModernAppBar(),

          // Filtros fijos en la parte superior (sin _buildStatusCard)
          if (_isInitialized && _departamentosDisponibles.isNotEmpty)
            Column(
              children: [
                _buildDepartmentSelector(),
                if (_departamentoSeleccionado != null) _buildSearchBar(),
              ],
            ),

          Expanded(
            child:
                _errorMessage != null && !_isLoading
                    ? _buildErrorWidget()
                    : _isLoading
                    ? Container(
                      height: 300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color(0xFF1565C0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Procesando solicitud...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : !_isInitialized
                    ? Container(
                      height: 300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Inicializando sistema...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : _departamentoSeleccionado == null
                    ? _buildEmptyState(
                      'SELECCIONA UNA REGIÓN',
                      'Elige una región policial para\nver las comisarías disponibles',
                      FontAwesomeIcons.mapLocationDot,
                    )
                    : _comisariasFiltradas.isEmpty
                    ? _buildEmptyState(
                      'SIN RESULTADOS',
                      'No se encontraron comisarías\nque coincidan con tu búsqueda',
                      FontAwesomeIcons.magnifyingGlass,
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 30),
                      itemCount: _comisariasFiltradas.length,
                      itemBuilder: (context, index) {
                        return _buildComisariaCard(
                          _comisariasFiltradas[index],
                          index,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
