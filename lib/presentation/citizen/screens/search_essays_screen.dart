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
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.search, size: 30, color: Colors.green),
                      SizedBox(width: 12),
                      Text(
                        'Buscar Ensayos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: _filterEssays,
                    decoration: InputDecoration(
                      hintText: 'Buscar por título, autor o categoría...',
                      prefixIcon: const Icon(Icons.search, color: Colors.green),
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
              ),
            ),
            
            // Essays List
            Expanded(
              child: _filteredEssays.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 80, color: Colors.grey),
                          SizedBox(height: 20),
                          Text(
                            'No se encontraron ensayos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Intenta con otros términos de búsqueda',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
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
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _showEssayDetails(essay);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  essay['category'],
                  style: const TextStyle(
                    fontSize: 12,
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