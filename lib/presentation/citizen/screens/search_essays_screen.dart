import 'package:flutter/material.dart';

class SearchEssaysScreen extends StatefulWidget {
  const SearchEssaysScreen({super.key});

  @override
  State<SearchEssaysScreen> createState() => _SearchEssaysScreenState();
}

class _SearchEssaysScreenState extends State<SearchEssaysScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _essays = [
    {
      'title': 'Protocolo de Búsqueda de Personas Desaparecidas',
      'author': 'PNP - División de Investigación',
      'date': '2024-01-15',
      'category': 'Protocolo',
      'description': 'Guía completa sobre los procedimientos estándar para la búsqueda de personas desaparecidas.',
    },
    {
      'title': 'Estadísticas de Desapariciones en Perú 2023',
      'author': 'Instituto Nacional de Estadística',
      'date': '2024-01-10',
      'category': 'Estadística',
      'description': 'Análisis detallado de los casos de desaparición reportados durante el año 2023.',
    },
    {
      'title': 'Tecnología en la Búsqueda de Personas',
      'author': 'Centro de Innovación Policial',
      'date': '2024-01-05',
      'category': 'Tecnología',
      'description': 'Nuevas herramientas tecnológicas aplicadas en la localización de personas desaparecidas.',
    },
  ];
  
  List<Map<String, dynamic>> _filteredEssays = [];

  @override
  void initState() {
    super.initState();
    _filteredEssays = _essays;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterEssays(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredEssays = _essays;
      } else {
        _filteredEssays = _essays.where((essay) {
          return essay['title'].toLowerCase().contains(query.toLowerCase()) ||
                 essay['author'].toLowerCase().contains(query.toLowerCase()) ||
                 essay['category'].toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header - más compacto
            Container(
              padding: const EdgeInsets.all(12), // Reducido de 16 a 12
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16), // Reducido de 20 a 16
                  bottomRight: Radius.circular(16), // Reducido de 20 a 16
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.search, size: 24, color: Colors.green), // Reducido de 30 a 24
                      SizedBox(width: 10), // Reducido de 12 a 10
                      Text(
                        'Buscar Ensayos',
                        style: TextStyle(
                          fontSize: 18, // Reducido de 20 a 18
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12), // Reducido de 16 a 12
                  // Search Bar - más compacto
                  TextField(
                    controller: _searchController,
                    onChanged: _filterEssays,
                    decoration: InputDecoration(
                      hintText: 'Buscar por título, autor o categoría...',
                      hintStyle: TextStyle(fontSize: 13), // Reducido tamaño de hint
                      prefixIcon: const Icon(Icons.search, color: Colors.green, size: 20), // Reducido tamaño
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20), // Reducido de 25 a 20
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, // Reducido de 20 a 16
                        vertical: 8, // Reducido de 10 a 8
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Essays List
            Expanded(
              child: _filteredEssays.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey), // Reducido de 80 a 60
                          SizedBox(height: 16), // Reducido de 20 a 16
                          Text(
                            'No se encontraron ensayos',
                            style: TextStyle(
                              fontSize: 16, // Reducido de 18 a 16
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8), // Reducido de 10 a 8
                          Text(
                            'Intenta con otros términos de búsqueda',
                            style: TextStyle(
                              fontSize: 12, // Reducido de 14 a 12
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12), // Reducido de 16 a 12
                      itemCount: _filteredEssays.length,
                      itemBuilder: (context, index) {
                        final essay = _filteredEssays[index];
                        return _buildEssayCard(essay);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEssayCard(Map<String, dynamic> essay) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12), // Reducido de 16 a 12
      elevation: 3, // Reducido de 4 a 3
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // Reducido de 12 a 10
      ),
      child: InkWell(
        onTap: () {
          _showEssayDetails(essay);
        },
        borderRadius: BorderRadius.circular(10), // Reducido de 12 a 10
        child: Padding(
          padding: const EdgeInsets.all(12), // Reducido de 16 a 12
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Badge - más compacto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reducido de 8,4 a 6,3
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10), // Reducido de 12 a 10
                ),
                child: Text(
                  essay['category'],
                  style: const TextStyle(
                    fontSize: 10, // Reducido de 12 a 10
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Title
              Text(
                essay['title'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              
              // Description
              Text(
                essay['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              
              // Author and Date
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      essay['author'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    essay['date'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEssayDetails(Map<String, dynamic> essay) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(essay['title']),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Autor: ${essay['author']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fecha: ${essay['date']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Categoría: ${essay['category']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(essay['description']),
                const SizedBox(height: 16),
                const Text(
                  'Este es un contenido de ejemplo. En una implementación real, aquí se mostraría el contenido completo del ensayo.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Función de descarga próximamente disponible'),
                  ),
                );
              },
              child: const Text('Descargar'),
            ),
          ],
        );
      },
    );
  }
}