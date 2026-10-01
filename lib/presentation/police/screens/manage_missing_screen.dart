import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../domain/enums.dart';
import '../../../common/state_enum.dart';
import '../view_models/manage_missing_view_model.dart';
import 'report_desaparecido_screen.dart';
import 'missing_details_screen.dart';

class ManageMissingScreen extends StatefulWidget {
  const ManageMissingScreen({super.key});

  @override
  State<ManageMissingScreen> createState() => _ManageMissingScreenState();
}

class _ManageMissingScreenState extends State<ManageMissingScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ManageMissingViewModel>(
        context,
        listen: false,
      ).getMissingPeople();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    Provider.of<ManageMissingViewModel>(
      context,
      listen: false,
    ).searchMissingPeople(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ManageMissingViewModel>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        elevation: 0,
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => _onSearchChanged(),
                )
                : const Text(
                  'Lista de Desaparecidos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        actions: <Widget>[
          if (!_isSearching)
            IconButton(
              icon: const FaIcon(
                FontAwesomeIcons.magnifyingGlass,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          if (_isSearching)
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.xmark, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  Provider.of<ManageMissingViewModel>(
                    context,
                    listen: false,
                  ).searchMissingPeople('');
                });
              },
            ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF415A77).withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF778DA9).withOpacity(0.3),
              ),
            ),
            child: DropdownButton<MissingFilter>(
              value: viewModel.currentFilter,
              dropdownColor: const Color(0xFF1B263B),
              underline: Container(),
              icon: const FaIcon(
                FontAwesomeIcons.chevronDown,
                color: Colors.white,
                size: 12,
              ),
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(
                  value: MissingFilter.active,
                  child: Text('Activos', style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (MissingFilter? newValue) {
                if (newValue != null && newValue != viewModel.currentFilter) {
                  viewModel.currentFilter = newValue;
                  viewModel.getMissingPeople(forceRefresh: true);
                }
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: _buildBody(viewModel),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody(ManageMissingViewModel viewModel) {
    if (viewModel.state == RequestState.Loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF415A77)),
        ),
      );
    }

    if (viewModel.state == RequestState.Error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.triangleExclamation,
              color: Color(0xFFE63946),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              viewModel.message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (viewModel.state == RequestState.Empty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.userSlash,
              color: Color(0xFF778DA9),
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No hay datos disponibles.',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    final displayList =
        _searchController.text.isNotEmpty
            ? viewModel.searchedDesaparecidos
            : viewModel.desaparecidos;

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              _searchController.text.isNotEmpty
                  ? FontAwesomeIcons.magnifyingGlass
                  : FontAwesomeIcons.userSlash,
              color: const Color(0xFF778DA9),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No se encontraron resultados para la búsqueda.'
                  : 'No hay casos de desaparecidos registrados con este filtro.',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollEndNotification &&
            !viewModel.isLoadingMore &&
            viewModel.hasMoreData &&
            notification.metrics.extentAfter < 300) {
          viewModel.loadMoreMissingPeople();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: displayList.length + (viewModel.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= displayList.length) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF415A77)),
                ),
              ),
            );
          }

          final desaparecido = displayList[index];
          return _buildMissingPersonCard(desaparecido);
        },
      ),
    );
  }

  Widget _buildMissingPersonCard(desaparecido) {
    // Calcular edad
    int? calcularEdad(DateTime? fechaNacimiento) {
      if (fechaNacimiento == null) return null;
      final hoy = DateTime.now();
      int edad = hoy.year - fechaNacimiento.year;
      if (hoy.month < fechaNacimiento.month ||
          (hoy.month == fechaNacimiento.month &&
              hoy.day < fechaNacimiento.day)) {
        edad--;
      }
      return edad;
    }

    final edad = calcularEdad(desaparecido.fechaNacimiento);
    final isMinor = edad != null && edad < 18;

    // Calcular días desaparecido
    int? diasDesaparecido;
    if (desaparecido.fechaDesaparicion != null) {
      diasDesaparecido =
          DateTime.now().difference(desaparecido.fechaDesaparicion!).inDays;
    }

    // Determinar prioridad
    Color priorityColor = const Color(0xFF415A77);
    IconData priorityIcon = FontAwesomeIcons.clock;
    String priorityText = 'Normal';

    if (isMinor) {
      priorityColor = const Color(0xFFE63946);
      priorityIcon = FontAwesomeIcons.child;
      priorityText = 'MENOR DE EDAD';
    } else if (diasDesaparecido != null && diasDesaparecido > 30) {
      priorityColor = const Color(0xFFFF8500);
      priorityIcon = FontAwesomeIcons.triangleExclamation;
      priorityText = 'ALTA PRIORIDAD';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: priorityColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _navigateToDetails(desaparecido),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Foto y estado
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: priorityColor, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child:
                            desaparecido.fotoUrl != null &&
                                    desaparecido.fotoUrl!.isNotEmpty
                                ? Image.network(
                                  desaparecido.fotoUrl!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: priorityColor.withOpacity(0.2),
                                      child: Icon(
                                        Icons.person,
                                        color: priorityColor,
                                        size: 40,
                                      ),
                                    );
                                  },
                                )
                                : Container(
                                  color: priorityColor.withOpacity(0.2),
                                  child: Icon(
                                    Icons.person,
                                    color: priorityColor,
                                    size: 40,
                                  ),
                                ),
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: priorityColor,
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          priorityIcon,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // Información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${desaparecido.nombres} ${desaparecido.apellidos}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),

                      if (desaparecido.dni != null)
                        _buildInfoRow(
                          FontAwesomeIcons.idCard,
                          'DNI: ${desaparecido.dni}',
                        ),

                      if (edad != null)
                        _buildInfoRow(
                          FontAwesomeIcons.cakeCandles,
                          'Edad: $edad años',
                        ),

                      if (desaparecido.fechaDesaparicion != null)
                        _buildInfoRow(
                          FontAwesomeIcons.calendar,
                          'Desaparecido: ${DateFormat('dd/MM/yyyy').format(desaparecido.fechaDesaparicion!)}',
                        ),

                      if (diasDesaparecido != null)
                        _buildInfoRow(
                          FontAwesomeIcons.clock,
                          'Hace $diasDesaparecido días',
                        ),

                      if (desaparecido.departamento != null)
                        _buildInfoRow(
                          FontAwesomeIcons.locationDot,
                          desaparecido.departamento!,
                        ),

                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          priorityText,
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                FaIcon(
                  FontAwesomeIcons.chevronRight,
                  color: priorityColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          FaIcon(icon, color: const Color(0xFF778DA9), size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF415A77), Color(0xFF778DA9)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF415A77).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton(
        tooltip: 'Registrar Desaparecido',
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const ReportDesaparecidoScreen()),
          );

          if (result == true && mounted) {
            Provider.of<ManageMissingViewModel>(
              context,
              listen: false,
            ).getMissingPeople(forceRefresh: true);
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(
          Icons.person_add_alt_1_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  void _navigateToDetails(desaparecido) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MissingDetailsScreen(desaparecido: desaparecido),
      ),
    );
  }
}
