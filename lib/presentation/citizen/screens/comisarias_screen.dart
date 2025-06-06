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
            // No es necesario si no tienes una barra de progreso
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _loadingMessage = 'Cargando comisaría...';
              _isReadyToInteract = false;
            });
          },
          onPageFinished: (String url) {
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
                    window.flutter_inappwebview.callHandler('onPageReady', true);
                    clearInterval(intervalId);
                  } else if (attempts >= maxAttempts) {
                    console.log('Tiempo de espera agotado. No se encontraron todos los elementos o el distrito no se autoseleccionó.');
                    window.flutter_inappwebview.callHandler('onPageReady', false);
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

  // Función para verificar y solicitar permisos de ubicación
  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Los servicios de ubicación no están habilitados, no se puede continuar.
      // Considerar mostrar un diálogo al usuario para que active el GPS.
      print('Los servicios de ubicación están deshabilitados.');
      // Opcional: Abrir la configuración de ubicación para que el usuario la active
      await Geolocator.openLocationSettings();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permisos denegados, no se puede continuar.
        print('Los permisos de ubicación fueron denegados.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permisos denegados permanentemente, no se puede solicitar de nuevo.
      print(
        'Los permisos de ubicación fueron denegados permanentemente. Por favor, habilítelos desde la configuración de la aplicación.',
      );
      // Opcional: Abrir la configuración de la aplicación para que el usuario cambie los permisos
      await Geolocator.openAppSettings();
      return;
    }

    // Permisos concedidos, se puede acceder a la ubicación.
    print('Permisos de ubicación concedidos.');
  }

  void _injectCustomJavaScript() async {
    final String javascriptCode = r'''
javascript:(function() {
    function hideFormPanel() {
        const traceButton = document.getElementById('btntrazar');
        const formPanel = document.getElementById('viewreportes');

        if (traceButton && formPanel) {
            traceButton.addEventListener('click', function() {
                formPanel.style.display = 'none';
                console.log('Panel del formulario (viewreportes) ocultado.');
            });
            console.log('Evento de click añadido al botón "Trazar ruta".');
        } else if (!traceButton) {
            console.log('Botón "Trazar ruta" no encontrado. Reintentando en 500ms...');
            setTimeout(hideFormPanel, 500);
        } else if (!formPanel) {
             console.log('Panel del formulario (viewreportes) no encontrado. Reintentando en 500ms...');
            setTimeout(hideFormPanel, 500);
        }
    }

    if (document.readyState === 'complete' || document.readyState === 'interactive') {
        hideFormPanel();
    } else {
        window.addEventListener('DOMContentLoaded', hideFormPanel);
    }
})();
    ''';
    await _webViewController.runJavaScript(javascriptCode);
    print('JavaScript de ocultación de formulario inyectado.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Comisaría'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading) // Mostrar indicador de carga y mensaje
            Container(
              color: Colors.black54, // Fondo semitransparente
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          // Botón para trazar ruta, visible solo cuando la página está lista
          if (_isReadyToInteract)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    // Simular clic en el botón 'btntrazar' en la WebView
                    _webViewController.runJavaScript("""
                      document.getElementById('btntrazar').click();
                      // Ocultar el formulario directamente
                      var formPanel = document.getElementById('viewreportes');
                      if (formPanel) {
                        formPanel.style.display = 'none';
                      }
                      // Ocultar y deshabilitar interacción con los iconos innecesarios
                      var iconsToHide = [
                        '.esri-icon-pause',
                        '.esri-icon-legend',
                        '.esri-icon-layers',
                        '.esri-icon-search'
                      ];
                      iconsToHide.forEach(function(selector) {
                        var element = document.querySelector(selector);
                        if (element) {
                          element.style.display = 'none';
                          element.style.pointerEvents = 'none'; // Deshabilitar interacción
                        }
                      });
                    """);
                  },
                  child: const Text('Trazar ruta'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
