import 'package:flutter/material.dart';

class FullScreenImageScreen extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageScreen({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro para la pantalla completa
      appBar: AppBar(
        backgroundColor: Colors.transparent, // AppBar transparente
        elevation: 0, // Sin sombra
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white), // Icono de cerrar blanco
          onPressed: () {
            Navigator.pop(context); // Cierra la pantalla actual
          },
        ),
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain, // Ajusta la imagen para que quepa en la pantalla
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Icon(Icons.error, color: Colors.white)),
        ),
      ),
    );
  }
}