import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../view_models/manage_found_view_model.dart';
import '../../../domain/entities/desaparecido.dart';
import 'found_details_screen.dart';
import '../../../common/state_enum.dart';

class ManageFoundScreen extends StatefulWidget {
  const ManageFoundScreen({super.key});

  @override
  State<ManageFoundScreen> createState() => _ManageFoundScreenState();
}

class _ManageFoundScreenState extends State<ManageFoundScreen>
    with TickerProviderStateMixin {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _fadeController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<ManageFoundViewModel>(
        context,
        listen: false,
      );
      if (viewModel.state != RequestState.Loaded &&
          viewModel.state != RequestState.Loading) {
        viewModel.getFoundPeople(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    Provider.of<ManageFoundViewModel>(
      context,
      listen: false,
    ).searchFoundPeople(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ManageFoundViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              _buildStatsHeader(viewModel),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildFoundList(viewModel),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.arrowLeft,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GESTIÓN DE ENCONTRADOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Text(
                      'Casos resueltos exitosamente',
                      style: TextStyle(
                        color: Color(0xFF27AE60),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isSearching)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.magnifyingGlass,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          
          if (_isSearching) ...[
            const SizedBox(height: 15),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o DNI...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF27AE60),
                  ),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                        Provider.of<ManageFoundViewModel>(
                          context,
                          listen: false,
                        ).searchFoundPeople('');
                      });
                    },
                    child: const Icon(
                      Icons.clear,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsHeader(ManageFoundViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF27AE60).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const FaIcon(
              FontAwesomeIcons.userCheck,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${viewModel.encontrados.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'PERSONAS ENCONTRADAS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Casos resueltos con éxito',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ACTIVO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundList(ManageFoundViewModel viewModel) {
    if (viewModel.state == RequestState.Loading && viewModel.encontrados.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF27AE60)),
            ),
            SizedBox(height: 16),
            Text(
              'Cargando personas encontradas...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (viewModel.state == RequestState.Error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.exclamationTriangle,
              color: Color(0xFFE74C3C),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: ${viewModel.message}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (viewModel.state == RequestState.Empty || viewModel.encontrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.userCheck,
              color: Color(0xFF27AE60),
              size: 64,
            ),
            const SizedBox(height: 20),
            const Text(
              'No hay personas encontradas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los casos resueltos aparecerán aquí',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final displayList = _searchController.text.isNotEmpty
        ? viewModel.searchedEncontrados
        : viewModel.encontrados;

    if (displayList.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              color: Color(0xFF778DA9),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron resultados',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otros términos de búsqueda',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
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
          viewModel.loadMoreFoundPeople();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: displayList.length + (viewModel.hasMoreData && viewModel.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= displayList.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF27AE60)),
                ),
              ),
            );
          }

          final encontrado = displayList[index];
          return _buildFoundCard(encontrado);
        },
      ),
    );
  }

  Widget _buildFoundCard(Desaparecido encontrado) {
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
        border: Border.all(
          color: const Color(0xFF27AE60).withOpacity(0.3),
          width: 1,
        ),
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
          onTap: () => _navigateToDetails(encontrado),
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
                        border: Border.all(
                          color: const Color(0xFF27AE60),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: encontrado.fotoUrl != null && encontrado.fotoUrl!.isNotEmpty
                            ? Image.network(
                                encontrado.fotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(0xFF27AE60).withOpacity(0.2),
                                    child: const Icon(
                                      Icons.person,
                                      color: Color(0xFF27AE60),
                                      size: 40,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: const Color(0xFF27AE60).withOpacity(0.2),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF27AE60),
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
                        decoration: const BoxDecoration(
                          color: Color(0xFF27AE60),
                          shape: BoxShape.circle,
                        ),
                        child: const FaIcon(
                          FontAwesomeIcons.check,
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
                        '${encontrado.nombres} ${encontrado.apellidos}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      if (encontrado.dni != null)
                        _buildInfoRow(
                          FontAwesomeIcons.idCard,
                          'DNI: ${encontrado.dni}',
                        ),
                      
                      if (encontrado.fechaEncontrado != null)
                        _buildInfoRow(
                          FontAwesomeIcons.calendar,
                          'Encontrado: ${DateFormat('dd/MM/yyyy').format(encontrado.fechaEncontrado!)}',
                        ),
                      
                      if (encontrado.departamento != null)
                        _buildInfoRow(
                          FontAwesomeIcons.locationDot,
                          encontrado.departamento!,
                        ),
                      
                      const SizedBox(height: 8),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ENCONTRADO',
                          style: TextStyle(
                            color: Color(0xFF27AE60),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const FaIcon(
                  FontAwesomeIcons.chevronRight,
                  color: Color(0xFF27AE60),
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
          FaIcon(
            icon,
            color: const Color(0xFF778DA9),
            size: 12,
          ),
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
          colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF27AE60).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          Provider.of<ManageFoundViewModel>(context, listen: false).refresh();
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const FaIcon(
          FontAwesomeIcons.arrowsRotate,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  void _navigateToDetails(Desaparecido encontrado) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoundDetailsScreen(encontrado: encontrado),
      ),
    );
  }
}