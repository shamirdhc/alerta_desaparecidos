import 'package:flutter/material.dart';

class SearchMissingScreen extends StatelessWidget {
  const SearchMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar Desaparecidos')),
      body: const Center(
        child: Text('Pantalla para buscar personas desaparecidas'),
      ),
    );
  }
}
