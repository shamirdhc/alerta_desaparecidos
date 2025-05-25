import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Necesario para formatear la fecha
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart'; // Asegúrate que RequestState esté aquí o en domain/enums
import 'package:alerta_desaparecidos/presentation/citizen/screens/citizen_missing_details_screen.dart';
import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:flutter/services.dart';
// --- NUEVOS IMPORTS PARA GPS ---
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
// --- FIN NUEVOS IMPORTS ---
import 'package:alerta_desaparecidos/common/styles/custom_input_decoration.dart'; // Asegúrate que la ruta sea correcta

class ViewMissingScreen extends StatefulWidget {
  const ViewMissingScreen({super.key});

  @override
  State<ViewMissingScreen> createState() => _ViewMissingScreenState();
}

class _ViewMissingScreenState extends State<ViewMissingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDepartamento;
  List<Map<String, dynamic>> _departamentosData = [];
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Asegúrate que _selectedStatus solo esté definido aquí y no se redeclare después
  String _selectedStatus = 'DESAPARECIDOS'; // Valor inicial ya existente
  final List<String> _statusOptions = ['DESAPARECIDOS', 'ENCONTRADOS'];
  // Declarar _statusDropdownColor aquí
  late Color _statusDropdownColor;

  // --- ASEGÚRATE QUE ESTA LISTA DE COLORES ESTÉ PRESENTE ---
  final List<Color> _departmentColors = [
    const Color(0xFFE3F2FD), // Light Blue
    const Color(0xFFEDE7F6), // Light Purple
    const Color(0xFFE8F5E9), // Light Green
    const Color(0xFFFFEBEE), // Light Red
    const Color(0xFFE0F2F1), // Light Teal
    const Color(0xFFFCE4EC), // Light Pink
    const Color(0xFFFFFDE7), // Light Yellow
    const Color(0xFFFFF3E0), // Light Orange
  ];
  // --- FIN LISTA DE COLORES ---

  @override
  void initState() {
    super.initState();
    // Inicializar _statusDropdownColor basado en el _selectedStatus inicial
    _updateStatusDropdownColor();
    _initializeScreen();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  // --- NUEVO MÉTODO: Para orquestar la carga inicial ---
  Future<void> _initializeScreen() async {
    await _loadDepartamentos(); // Cargar departamentos primero
    if (mounted) {
      // Verificar si el widget sigue montado
      await _determineInitialDepartamento(); // Luego determinar el departamento inicial
    }
  }
  // --- FIN NUEVO MÉTODO ---

  // --- NUEVO MÉTODO: Para determinar el departamento usando GPS o fallback ---
  Future<void> _determineInitialDepartamento() async {
    String? departamentoDetectadoPorGps;

    try {
      // 1. Verificar y solicitar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('[GPS] PERMISO DE UBICACIÓN DENEGADO.');
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // 2. Obtener posición actual
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          // Podrías añadir un timeLimit si la obtención de GPS tarda mucho
          // timeLimit: const Duration(seconds: 10),
        );

        // 3. Geocodificación inversa para obtener detalles del lugar
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          // 'administrativeArea' usualmente es el estado/departamento.
          // Puede necesitar ajustes para Perú si devuelve otro campo.
          String? gpsDeptName = place.administrativeArea;
          if (gpsDeptName != null && gpsDeptName.isNotEmpty) {
            departamentoDetectadoPorGps = gpsDeptName.toUpperCase();
            // Imprimir el departamento detectado por GPS en mayúsculas
            print(
              '[GPS] DEPARTAMENTO DETECTADO POR GPS: $departamentoDetectadoPorGps',
            );
          } else {
            print(
              '[GPS] NO SE PUDO DETERMINAR EL DEPARTAMENTO DESDE GPS (administrativeArea NULO O VACÍO).',
            );
          }
        } else {
          print(
            '[GPS] NO SE PUDIERON OBTENER DETALLES DE LA UBICACIÓN (PLACEMARKS VACÍO).',
          );
        }
      }
    } catch (e) {
      print('[GPS] ERROR AL OBTENER UBICACIÓN/DEPARTAMENTO GPS: $e');
    }

    if (!mounted) return; // Salir si el widget ya no está montado

    bool departamentoFueEstablecido = false;

    // 4. Intentar establecer el departamento usando el resultado del GPS
    if (departamentoDetectadoPorGps != null && _departamentosData.isNotEmpty) {
      final match = _departamentosData.firstWhere(
        (d) =>
            (d['name'] as String?)?.toUpperCase() ==
            departamentoDetectadoPorGps,
        orElse:
            () =>
                <
                  String,
                  dynamic
                >{}, // Devuelve mapa vacío si no hay coincidencia
      );

      if (match.isNotEmpty && match['name'] != null) {
        setState(() {
          _selectedDepartamento = match['name'] as String;
        });
        departamentoFueEstablecido = true;
        print(
          '[GPS] DEPARTAMENTO SELECCIONADO AUTOMÁTICAMENTE (POR GPS): $_selectedDepartamento',
        );
      } else {
        print(
          '[GPS] DEPARTAMENTO GPS "$departamentoDetectadoPorGps" NO ENCONTRADO EN LA LISTA LOCAL.',
        );
      }
    }

    // 5. Fallback: Si el GPS falló o no hubo coincidencia, seleccionar el primer departamento de la lista
    if (!departamentoFueEstablecido && _departamentosData.isNotEmpty) {
      setState(() {
        _selectedDepartamento = _departamentosData.first['name'] as String?;
      });
      if (_selectedDepartamento != null) {
        departamentoFueEstablecido = true;
        print(
          '[GPS] DEPARTAMENTO SELECCIONADO AUTOMÁTICAMENTE (PRIMERO DE LA LISTA): $_selectedDepartamento',
        );
      }
    }

    // 6. Cargar datos iniciales basados en el departamento seleccionado y el estado actual
    // --- MODIFICADO: Incluir _selectedStatus en la carga inicial ---
    if (_selectedDepartamento != null) {
      _fetchDataWithCurrentFilters();
    } else {
      print(
        '[GPS] NO SE PUDO SELECCIONAR NINGÚN DEPARTAMENTO. CARGANDO TODOS PARA EL ESTADO ACTUAL.',
      );
      Provider.of<ViewMissingViewModel>(
        context,
        listen: false,
      ).getMissingPeople(
        forceRefresh: true,
        // Asumiendo que getMissingPeople también podría tomar un status, o filtrar internamente
        // Si no, searchMissingPeople se llamará después de que el departamento se establezca
        // y _selectedStatus ya tendrá su valor por defecto.
        // Por ahora, la lógica de _fetchDataWithCurrentFilters se encargará.
      );
      _fetchDataWithCurrentFilters(); // Asegura que se llame con el estado por defecto
    }
  }
  // --- FIN NUEVO MÉTODO ---

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // --- CAMBIO: Llamar a loadMoreMissingPeople sin parámetros ---
      // (ViewModel deberá usar los filtros actuales internamente)
      Provider.of<ViewMissingViewModel>(
        context,
        listen: false,
      ).loadMoreMissingPeople();
      // --- FIN CAMBIO ---
    }
  }

  // --- NUEVO MÉTODO: Para centralizar la llamada de búsqueda/filtrado ---
  void _fetchDataWithCurrentFilters() {
    final departamentoParaFiltrar = _selectedDepartamento?.toUpperCase();
    final statusParaFiltrar =
        _selectedStatus == 'DESAPARECIDOS' ? 'activo' : 'encontrado';

    Provider.of<ViewMissingViewModel>(
      context,
      listen: false,
    ).searchMissingPeople(
      _searchController.text.trim(),
      departamento: departamentoParaFiltrar,
      status: statusParaFiltrar, // Pasar el estado correspondiente
    );
  }
  // --- FIN NUEVO MÉTODO ---

  void _onSearchChanged() {
    // --- CAMBIO AQUÍ: Usar el método centralizado ---
    _fetchDataWithCurrentFilters();
    // --- FIN CAMBIO ---
  }

  Future<void> _loadDepartamentos() async {
    try {
      final data = await _dbHelper.getDepartamentos();
      if (mounted) {
        setState(() {
          _departamentosData = data;
          // ELIMINAR DEBUG PRINT: print('Departamentos cargados: $_departamentosData');
        });
      }
    } catch (e) {
      // Este print es un error real, es bueno mantenerlo.
      print('Error al cargar departamentos: $e');
      if (mounted) {
        setState(() {
          _departamentosData = [];
        });
      }
    }
  }

  void _onDepartamentoChanged(String? newValue) {
    setState(() {
      _selectedDepartamento = newValue;
    });
    // --- CAMBIO AQUÍ: Usar el método centralizado ---
    _fetchDataWithCurrentFilters();
    // --- FIN CAMBIO ---
  }

  // --- NUEVO MÉTODO: Handler para el cambio de estado (desaparecido/encontrado) ---
  void _onStatusChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _selectedStatus = newValue;
      _updateStatusDropdownColor(); // Actualizar color al cambiar estado
    });
    _fetchDataWithCurrentFilters();
  }

  // Método para actualizar el color del dropdown de estado
  void _updateStatusDropdownColor() {
    // No es necesario llamar a setState aquí si _updateStatusDropdownColor
    // se llama desde initState o desde un setState existente como en _onStatusChanged.
    // Si se llamara desde otro lugar que no reconstruye el widget, setState sería necesario.
    if (_selectedStatus == 'DESAPARECIDOS') {
      _statusDropdownColor = Colors.red.withOpacity(0.3);
    } else if (_selectedStatus == 'ENCONTRADOS') {
      _statusDropdownColor = Colors.green.withOpacity(0.3);
    } else {
      // Color por defecto o transparente si es necesario, aunque con valor inicial no debería llegar aquí.
      _statusDropdownColor = Colors.transparent;
    }
    // Si esta función se llama fuera de un setState y necesita provocar una reconstrucción:
    // if (mounted) { setState(() {}); }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ViewMissingViewModel>(context);
    final bool isDarkTheme =
        Theme.of(context).brightness ==
        Brightness.dark; // Para el icono y ahora para el borde

    return Column(
      children: [
        // --- Fila de Filtros ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // --- Filtro de Departamento (Existente) ---
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: getCustomDropdownDecoration(
                    context: context,
                    labelText: 'Departamento',
                  ),
                  hint: Center(
                    child: Text(
                      'DEPARTAMENTO',
                      style: TextStyle(
                        color: Colors.grey, // CAMBIO: Color del hint a gris
                        fontWeight: FontWeight.bold, // CAMBIO: Hint en negrita
                        fontSize: 14,
                      ),
                    ),
                  ),
                  value: _selectedDepartamento,
                  isExpanded: true,
                  items:
                      _departamentosData
                          .asMap()
                          .entries
                          .map<DropdownMenuItem<String>>((entry) {
                            int index = entry.key;
                            Map<String, dynamic> depto = entry.value;
                            final String? deptoName = depto['name'] as String?;
                            Color itemBackgroundColor =
                                _departmentColors[index %
                                    _departmentColors.length];
                            Color itemTextColor =
                                ThemeData.estimateBrightnessForColor(
                                          itemBackgroundColor,
                                        ) ==
                                        Brightness.dark
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.black.withOpacity(0.7);

                            return DropdownMenuItem<String>(
                              value: deptoName,
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 10.0,
                                ),
                                decoration: BoxDecoration(
                                  color: itemBackgroundColor,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  deptoName?.toUpperCase() ?? 'N/A',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: itemTextColor,
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          })
                          .toList(),
                  selectedItemBuilder: (BuildContext context) {
                    return _departamentosData.map<Widget>((
                      Map<String, dynamic> item,
                    ) {
                      final String? deptoName = item['name'] as String?;
                      int index = _departamentosData.indexWhere(
                        (d) => d['name'] == deptoName,
                      );

                      Color selectedBgColor = Colors.grey.shade200;
                      if (index != -1) {
                        selectedBgColor =
                            _departmentColors[index % _departmentColors.length];
                      }
                      Color selectedTextColor =
                          ThemeData.estimateBrightnessForColor(
                                    selectedBgColor,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white.withOpacity(0.9)
                              : Colors.black.withOpacity(0.7);

                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selectedBgColor,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 8.0,
                        ),
                        child: Text(
                          deptoName?.toUpperCase() ?? 'N/A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selectedTextColor,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList();
                  },
                  onChanged: _onDepartamentoChanged,
                  // --- MODIFICACIÓN: Añadir un poco de espacio si hay dos dropdowns ---
                  // style: const TextStyle(fontSize: 15), // Ajustar según sea necesario
                ),
              ),
              const SizedBox(width: 8.0), // Espacio entre los dropdowns
              // --- NUEVO: Filtro de Estado (Desaparecidos/Encontrados) ---
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: getCustomDropdownDecoration(
                    context: context,
                    customFillColor:
                        _statusDropdownColor, // CAMBIO AQUÍ: Pasar el color dinámico
                  ),
                  // MODIFICACIÓN: Eliminar COMPLETAMENTE el hint para el dropdown de estado
                  value: _selectedStatus,
                  isExpanded: true,
                  items:
                      _statusOptions.map<DropdownMenuItem<String>>((
                        String value,
                      ) {
                        // Usar colores simples para este dropdown o definir una nueva paleta
                        Color itemBackgroundColor =
                            (value == 'DESAPARECIDOS')
                                ? Colors.orange.shade100
                                : Colors.green.shade100;
                        Color itemTextColor =
                            ThemeData.estimateBrightnessForColor(
                                      itemBackgroundColor,
                                    ) ==
                                    Brightness.dark
                                ? Colors.white.withOpacity(0.9)
                                : Colors.black.withOpacity(0.7);

                        return DropdownMenuItem<String>(
                          value: value,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 10.0,
                            ),
                            decoration: BoxDecoration(
                              color: itemBackgroundColor,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              value,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: itemTextColor,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }).toList(),
                  selectedItemBuilder: (BuildContext context) {
                    return _statusOptions.map<Widget>((String item) {
                      // El color del item seleccionado ya no necesita cambiar el fondo del dropdown aquí,
                      // ya que se maneja con _statusDropdownColor en la decoration.
                      // Mantenemos la lógica para el color del texto del item si es necesario.
                      Color selectedItemTextColor;
                      if (item == 'DESAPARECIDOS') {
                        selectedItemTextColor = Colors.red[700]!;
                      } else {
                        selectedItemTextColor = Colors.green[700]!;
                      }

                      return Container(
                        alignment: Alignment.center,
                        // Quitar la decoración de fondo aquí si se maneja globalmente
                        // decoration: BoxDecoration(
                        //   color: selectedBgColor, // Esto se maneja ahora por fillColor
                        //   borderRadius: BorderRadius.circular(8.0),
                        // ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 8.0,
                          ),
                          child: Text(
                            item,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  selectedItemTextColor, // Usar el color de texto definido
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  onChanged: _onStatusChanged,
                ),
              ),
            ],
          ),
        ),
        // --- Fin Fila de Filtros ---

        // --- Fila 2: Campo de Búsqueda (Existente) ---
        Padding(
          padding: const EdgeInsets.fromLTRB(
            16.0,
            0,
            16.0,
            8.0,
          ), // Ajustar padding si es necesario
          child: TextField(
            controller: _searchController,
            inputFormatters: [UpperCaseTextFormatter()],
            decoration: InputDecoration(
              hintText: 'Buscar por nombre y/o apellidos...',
              prefixIcon: const Icon(Icons.search),
              // --- CAMBIO: Borde contrastante ---
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color:
                      isDarkTheme
                          ? Colors.white54
                          : Colors.black54, // Color contrastante
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color:
                      isDarkTheme
                          ? Colors.white70
                          : Colors
                              .black87, // Color contrastante más fuerte al enfocar
                  width: 2.0,
                ),
              ),
              // --- FIN CAMBIO ---
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
            ),
          ),
        ),

        // --- Fila 3: Título Dinámico y Logo ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              // Título Dinámico
              Text(
                _selectedStatus == 'DESAPARECIDOS'
                    ? 'PERSONAS DESAPARECIDAS'
                    : 'PERSONAS ENCONTRADAS',
                style: TextStyle(
                  fontSize: 26, // Aumentado el tamaño de la fuente
                  fontWeight: FontWeight.bold,
                  color:
                      _selectedStatus == 'DESAPARECIDOS'
                          ? Colors.red
                          : Colors.green,
                  // decoration: TextDecoration.underline, // Subrayado eliminado
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8), // Espacio entre el título y la imagen
              // Imagen "Te estamos buscando"
              Image.asset(
                'assets/icons/te_estamos_buscando.png', // Ruta de tu imagen
                height:
                    40, // Ajusta la altura según necesites (un poco menos para dar espacio al título)
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),

        // --- Lista de Desaparecidos ---
        Expanded(
          child: Consumer<ViewMissingViewModel>(
            builder: (context, vm, child) {
              if (vm.state == RequestState.Loading &&
                  vm.desaparecidos.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (vm.state == RequestState.Error) {
                return Center(child: Text('Error: ${vm.message}'));
              }
              // --- CAMBIO: Usar vm.desaparecidos directamente ---
              if (vm.state != RequestState.Loading &&
                  vm.desaparecidos.isEmpty) {
                // --- CAMBIO: Actualizar texto de "sin resultados" ---
                String emptyMessage = 'NO HAY CASOS ACTIVOS REGISTRADOS.';
                if (_searchController.text.isNotEmpty &&
                    _selectedDepartamento != null) {
                  emptyMessage =
                      'NO SE ENCONTRARON RESULTADOS PARA "${_searchController.text}" EN EL DEPARTAMENTO SELECCIONADO.';
                } else if (_searchController.text.isNotEmpty) {
                  emptyMessage =
                      'NO SE ENCONTRARON RESULTADOS PARA "${_searchController.text}".';
                } else if (_selectedDepartamento != null) {
                  emptyMessage =
                      'NO HAY CASOS ACTIVOS REGISTRADOS EN ESTE DEPARTAMENTO.';
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ),
                );
                // --- FIN CAMBIO ---
              }

              // Si hay datos para mostrar
              return ListView.builder(
                controller: _scrollController,
                itemCount: vm.desaparecidos.length + (vm.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == vm.desaparecidos.length) {
                    return vm.isLoadingMore
                        ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                        : const SizedBox.shrink();
                  }

                  if (index < vm.desaparecidos.length) {
                    final desaparecido = vm.desaparecidos[index];
                    final bool isLastItem =
                        index == vm.desaparecidos.length - 1;

                    // --- CAMBIO: Añadir Divider entre cards ---
                    final theme = Theme.of(context);
                    final dividerColor =
                        theme.brightness == Brightness.dark
                            ? Colors
                                .white30 // Color claro para tema oscuro
                            : Colors.black26; // Color oscuro para tema claro

                    return Column(
                      children: [
                        _buildMissingPersonCard(
                          desaparecido,
                          index + 1,
                          vm.desaparecidos.length,
                        ),
                        if (!isLastItem &&
                            vm.desaparecidos.length >
                                1) // No añadir divider después del último item o si solo hay uno
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ), // Para alinear con el margen de la card
                            child: Divider(
                              color: dividerColor,
                              thickness: 1.0, // Grosor delgado
                              height:
                                  20.0, // Aumentar un poco la altura para que el padding del divider tenga efecto si es necesario
                            ),
                          ),
                      ],
                    );
                    // --- FIN CAMBIO ---
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Cierre del método build anterior

  // --- Widget para construir la tarjeta de una persona desaparecida ---
  Widget _buildMissingPersonCard(
    Desaparecido desaparecido,
    int currentIndex,
    int totalCount,
  ) {
    // Función interna para calcular la edad
    int? calcularEdad(DateTime? fechaNacimiento) {
      if (fechaNacimiento == null) {
        return null;
      }
      final hoy = DateTime.now();
      int edad = hoy.year - fechaNacimiento.year;
      if (hoy.month < fechaNacimiento.month ||
          (hoy.month == fechaNacimiento.month &&
              hoy.day < fechaNacimiento.day)) {
        edad--;
      }
      return edad;
    }

    final int? edadCalculada = calcularEdad(desaparecido.fechaNacimiento);

    final String nombreCompleto =
        '${desaparecido.nombres}, ${desaparecido.apellidos}'.toUpperCase();

    const double nombreFontSize = 20.0;
    const double infoLabelFontSize = 15.0;
    const double infoValueFontSize = 15.0;
    const double contadorFontSize = 14.0;

    final theme = Theme.of(context); // Mover la obtención del tema aquí arriba

    // --- CAMBIOS DE COLOR ---
    final Color colorFondoBoton =
        Colors.green[100] ?? Colors.green.withOpacity(0.3);
    final Color colorBordeImagen = Colors.black;
    const Color colorIconoFlecha = Colors.black;

    // --- CAMBIO: Colores de texto dinámicos basados en el tema ---
    final Color colorTextoNombreCompleto =
        theme.brightness == Brightness.dark
            ? Colors
                .white // Texto claro para tema oscuro
            : Colors.green[700] ??
                Colors.green; // Texto oscuro (verde) para tema claro

    final Color colorTextoInfo =
        theme.brightness == Brightness.dark
            ? Colors
                .white70 // Texto claro para tema oscuro
            : Colors.black87; // Texto oscuro para tema claro
    // --- FIN CAMBIO ---

    // MODIFICACIÓN: Determinar color de borde y sombra de la tarjeta dinámicamente
    Color cardBorderColor;
    Color cardShadowColor;

    if (_selectedStatus == 'DESAPARECIDOS') {
      cardBorderColor = Colors.red[900]!; // Rojo sangre
      cardShadowColor = Colors.red[900]!.withOpacity(0.5); // Sombra roja sangre
    } else if (_selectedStatus == 'ENCONTRADOS') {
      cardBorderColor = Colors.green[700]!; // Verde
      cardShadowColor = Colors.green[700]!.withOpacity(0.5); // Sombra verde
    } else {
      // Fallback por si acaso, aunque _selectedStatus siempre debería tener un valor
      cardBorderColor =
          theme.brightness == Brightness.dark ? Colors.white60 : Colors.black54;
      cardShadowColor = Colors.black.withOpacity(0.2);
    }

    // Helper widget para las filas de información
    Widget buildInfoRow(String label, String? value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  // Quitar const para usar colorTextoInfo dinámico
                  fontSize: infoLabelFontSize,
                  fontWeight: FontWeight.bold,
                  color: colorTextoInfo, // Usar color de texto dinámico
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (value ?? 'DESCONOCIDO').toUpperCase(),
                style: TextStyle(
                  // Quitar const
                  fontSize: infoValueFontSize,
                  color: colorTextoInfo, // Usar color de texto dinámico
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      elevation: 8.0,
      // MODIFICACIÓN: Aplicar borde y sombra dinámicos
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cardBorderColor,
          width: 2.0,
        ), // Borde más grueso y dinámico
      ),
      shadowColor: cardShadowColor, // Aplicar color de sombra dinámico
      // Para que la sombra sea más pronunciada, podrías necesitar envolver la Card
      // en un Container con BoxDecoration y boxShadow, ya que `shadowColor` en Card
      // a veces es sutil. Por ahora, probemos con `shadowColor`.
      // Si se necesita más control, se puede usar:
      // decoration: BoxDecoration(
      //   borderRadius: BorderRadius.circular(12),
      //   boxShadow: [
      //     BoxShadow(
      //       color: cardShadowColor,
      //       blurRadius: 10.0, // Ajusta el desenfoque
      //       spreadRadius: 2.0, // Ajusta la extensión de la sombra
      //     ),
      //   ],
      // ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Parte Izquierda: Imagen e Información
            Expanded(
              child: Padding(
                // Añadir Padding alrededor de la columna izquierda
                padding: const EdgeInsets.all(
                  12.0,
                ), // Espaciado general para la parte izquierda
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Imagen
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: colorBordeImagen, width: 2.5),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      // Quitar márgenes individuales de la imagen, se manejan con el Padding padre
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7.5),
                        child:
                            (desaparecido.fotoUrl != null &&
                                    desaparecido.fotoUrl!.isNotEmpty)
                                ? AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: Image.network(
                                    desaparecido.fotoUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.grey[600],
                                            size: 50,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                                : AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: Container(
                                    color: Colors.grey[300],
                                    child: Center(
                                      child: Icon(
                                        Icons.person_outline,
                                        color: Colors.grey[600],
                                        size: 80,
                                      ),
                                    ),
                                  ),
                                ),
                      ),
                    ),

                    const SizedBox(height: 10), // Espacio entre imagen y nombre
                    // --- CAMBIO: Sin fondo, color de texto dinámico para Nombre Completo ---
                    Text(
                      nombreCompleto,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        // Quitar const
                        fontSize: nombreFontSize,
                        fontWeight: FontWeight.bold,
                        color:
                            colorTextoNombreCompleto, // Usar color de texto dinámico
                      ),
                    ),

                    // --- FIN CAMBIO ---
                    const SizedBox(
                      height: 10,
                    ), // Espacio entre nombre e información
                    // --- CAMBIO: Sin fondo para la sección de Información ---
                    Column(
                      children: [
                        buildInfoRow(
                          'EDAD:',
                          edadCalculada != null
                              ? '$edadCalculada AÑOS'
                              : 'DESCONOCIDA',
                        ),
                        buildInfoRow(
                          'DEPARTAMENTO:',
                          desaparecido.departamento,
                        ),
                        buildInfoRow('PROVINCIA:', desaparecido.provincia),
                        buildInfoRow('DISTRITO:', desaparecido.distrito),
                        if (desaparecido.fechaDesaparicion != null)
                          buildInfoRow(
                            'FECHA DESAP.:',
                            DateFormat(
                              'dd/MM/yyyy',
                            ).format(desaparecido.fechaDesaparicion!),
                          )
                        else
                          buildInfoRow('FECHA DESAP.:', 'DESCONOCIDA'),
                      ],
                    ),
                    // --- FIN CAMBIO ---
                    const Spacer(),
                  ],
                ),
              ),
            ),

            // Parte Derecha: Botón Vertical
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => CitizenMissingDetailsScreen(
                          desaparecido: desaparecido,
                        ),
                  ),
                );
              },
              child: Container(
                width: 70,
                color: colorFondoBoton,
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 4.0,
                ),
                child: Column(
                  // --- CAMBIO: Centrar elementos verticalmente y luego la flecha ---
                  mainAxisAlignment:
                      MainAxisAlignment.start, // Alinea el contador arriba
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      // Contador
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black54, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$currentIndex/$totalCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: contadorFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black.withOpacity(0.8),
                        ),
                      ),
                    ),
                    Expanded(
                      // Hace que el Icono ocupe el espacio restante
                      child: Center(
                        // Centra el Icono en el espacio de Expanded
                        child: Icon(
                          Icons.chevron_right,
                          size: 35,
                          color: colorIconoFlecha,
                        ),
                      ),
                    ),
                  ],
                  // --- FIN CAMBIO ---
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} // Cierre de la clase _ViewMissingScreenState

// Coloca esto al final del archivo, fuera de cualquier otra clase:
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
