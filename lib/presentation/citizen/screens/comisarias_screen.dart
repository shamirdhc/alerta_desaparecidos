import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:geolocator/geolocator.dart'; // Importar geolocator

class ComisariasScreen extends StatefulWidget {
  const ComisariasScreen({Key? key}) : super(key: key);

  @override
  State<ComisariasScreen> createState() => _ComisariasScreenState();
}

class _ComisariasScreenState extends State<ComisariasScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  String _loadingMessage = 'Cargando comisaría...';
  bool _isReadyToInteract = false;

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocationPermission();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Puedes usar esto para una barra de progreso más fina
            if (progress == 100) {
              // Si el progreso llega al 100%, asumimos que la página base cargó
              // y podemos ocultar el indicador de carga inicial.
              // La lógica de JavaScript determinará si la página está lista para interactuar.
              if (_isLoading) {
                setState(() {
                  _isLoading = false;
                });
              }
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _loadingMessage = 'Cargando comisaría...';
              _isReadyToInteract = false;
            });
          },
          onPageFinished: (String url) {
            // Inyectar el JavaScript para verificar la interactividad de la página
            _webViewController.runJavaScript('''
              (function() {
                var maxAttempts = 120; // Aumentado para dar más tiempo
                var attempts = 0;
                var intervalId = setInterval(function() {
                  attempts++;
                  var distritoSelect = document.getElementById('distrito');
                  var btnTrazar = document.getElementById('btntrazar');
                  var formPanel = document.getElementById('viewreportes');

                  // Ocultar iconos innecesarios
                  var iconsToHide = [
                    document.querySelector('.esri-icon.esri-icon-pause'),
                    document.querySelector('.esri-collapse__icon.esri-icon-layer-list'),
                    document.querySelector('.esri-collapse__icon.esri-icon-layers'),
                    document.querySelector('.esri-collapse__icon.esri-icon-search')
                  ];

                  iconsToHide.forEach(function(icon) {
                    if (icon) {
                      icon.style.display = 'none';
                    }
                  });

                  // Condición para considerar que la página está lista para interactuar:
                  // - Dropdown 'distrito' presente y con una opción seleccionada que NO sea 'SELECCIONE'
                  // - Botón 'btntrazar' y panel 'viewreportes' presentes
                  if (distritoSelect && btnTrazar && formPanel && distritoSelect.value !== 'SELECCIONE') {
                    console.log('Dropdown de Distrito seleccionado. Página lista para interactuar.');
                    // Comunicar a Flutter que la página está lista
                    onPageReady.postMessage('true');
                    clearInterval(intervalId);
                  } else if (attempts >= maxAttempts) {
                    console.log('Tiempo de espera agotado. No se encontraron todos los elementos o el distrito no se autoseleccionó.');
                    onPageReady.postMessage('false');
                    clearInterval(intervalId);
                  } else {
                    console.log('Esperando autoselección de distrito. Intento: ' + attempts + '/' + maxAttempts);
                  }
                }, 500); // Verificar cada 0.5 segundos
              })();
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _isReadyToInteract = false; // Asegurarse de que no está listo para interactuar
              _loadingMessage =
                  'Error al cargar la página: ${error.description}';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'onPageReady',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'true') {
            setState(() {
              _isLoading = false;
              _isReadyToInteract = true;
              _loadingMessage = 'Página lista. Puede trazar la ruta.';
            });
          } else {
            setState(() {
              _isLoading = false;
              _isReadyToInteract = false;
              _loadingMessage =
                  'No se pudo cargar la página o el distrito no se autoseleccionó.';
            });
          }
        },
      )
      ..addJavaScriptChannel(
        'hideFormPanelChannel',
        onMessageReceived: (JavaScriptMessage message) {
          // Este canal se usará para ocultar el formulario desde Flutter
          _webViewController.runJavaScript(
            "document.getElementById('viewreportes').style.display = 'none';",
          );
          print('Panel de formulario ocultado por solicitud de Flutter.');
        },
      )
      ..loadRequest(
        Uri.parse('https://aplicaciones.mininter.gob.pe/ubicatucomisaria/'),
      );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setGeolocationPermissionsPromptCallbacks(
            onShowPrompt: (origin) async {
              print('Geolocation permission prompt for origin: \$origin');
              return Future.value(
                GeolocationPermissionsResponse(allow: true, retain: false),
              );
            },
            onHidePrompt: () {
              print('Geolocation permission prompt hidden');
            },
          );
    }

    _webViewController = controller;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cuando la pantalla vuelve a estar activa, podemos verificar el estado de carga
    // y si la página ya está lista, ocultar el indicador de carga.
    if (!_isLoading && _isReadyToInteract) {
      setState(() {
        _loadingMessage = 'Página lista. Puede trazar la ruta.';
      });
    }
  }

  @override
  void dispose() {
    // Es importante disponer del controlador cuando el widget se elimina
    // para liberar recursos.
    // No hay un método dispose directo en WebViewController, pero el garbage collector
    // debería manejarlo si no hay referencias fuertes.
    super.dispose();
  }

  // Función para verificar y solicitar permisos de ubicación
  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Los servicios de ubicación están deshabilitados.');
      await Geolocator.openLocationSettings();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Los permisos de ubicación fueron denegados.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print(
        'Los permisos de ubicación fueron denegados permanentemente. Por favor, habilítelos desde la configuración de la aplicación.',
      );
      await Geolocator.openAppSettings();
      return;
    }

    print('Permisos de ubicación concedidos.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('Ubicación de Comisarías'), // Elimina o comenta esta línea
        backgroundColor: Colors.red,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
