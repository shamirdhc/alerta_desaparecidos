import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:geolocator/geolocator.dart'; // Importar geolocator
import 'package:visibility_detector/visibility_detector.dart'; // Importar visibility_detector

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
  bool _isWebViewVisible = true; // Track visibility
  final String _initialUrl =
      'https://aplicaciones.mininter.gob.pe/ubicatucomisaria/';

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
            if (progress == 100 && _isWebViewVisible) {
              if (_isLoading) {
                setState(() {
                  _isLoading = false;
                });
              }
            }
          },
          onPageStarted: (String url) {
            if (_isWebViewVisible) {
              setState(() {
                _isLoading = true;
                _loadingMessage = 'Cargando comisaría...';
                _isReadyToInteract = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (url != 'about:blank' && _isWebViewVisible) {
              _webViewController.runJavaScript('''
                (function() {
                  var maxAttempts = 120; 
                  var attempts = 0;
                  var intervalId = setInterval(function() {
                    attempts++;
                    var distritoSelect = document.getElementById('distrito');
                    var btnTrazar = document.getElementById('btntrazar');
                    var formPanel = document.getElementById('viewreportes');

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

                    if (distritoSelect && btnTrazar && formPanel && distritoSelect.value !== 'SELECCIONE') {
                      console.log('Dropdown de Distrito seleccionado. Página lista para interactuar.');
                      onPageReady.postMessage('true');
                      clearInterval(intervalId);
                    } else if (attempts >= maxAttempts) {
                      console.log('Tiempo de espera agotado.');
                      onPageReady.postMessage('false');
                      clearInterval(intervalId);
                    } else {
                      console.log('Esperando autoselección de distrito. Intento: ' + attempts + '/' + maxAttempts);
                    }
                  }, 500); 
                })();
              ''');
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (_isWebViewVisible) {
              setState(() {
                _isLoading = false;
                _isReadyToInteract = false;
                _loadingMessage =
                    'Error al cargar la página: ${error.description}';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'onPageReady',
        onMessageReceived: (JavaScriptMessage message) {
          if (_isWebViewVisible) {
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
          }
        },
      )
      ..addJavaScriptChannel(
        'hideFormPanelChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _webViewController.runJavaScript(
            "document.getElementById('viewreportes').style.display = 'none';",
          );
          print('Panel de formulario ocultado por solicitud de Flutter.');
        },
      );
    // ..loadRequest( // We will load the request based on visibility
    //   Uri.parse(_initialUrl),
    // );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setGeolocationPermissionsPromptCallbacks(
            onShowPrompt: (origin) async {
              print('Geolocation permission prompt for origin: $origin');
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

  void _handleVisibilityChange(VisibilityInfo info) {
    if (info.visibleFraction == 0 && _isWebViewVisible) {
      // WebView is no longer visible
      setState(() {
        _isWebViewVisible = false;
      });
      _webViewController.loadRequest(Uri.parse('about:blank'));
      print('WebView hidden, loading about:blank');
    } else if (info.visibleFraction > 0 && !_isWebViewVisible) {
      // WebView became visible
      setState(() {
        _isWebViewVisible = true;
        _isLoading = true; // Show loading indicator while reloading
        _loadingMessage = 'Recargando comisaría...';
      });
      _webViewController.loadRequest(Uri.parse(_initialUrl));
      print('WebView visible, loading initial URL');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VisibilityDetector(
        key: const Key('comisarias_webview_visibility_detector'),
        onVisibilityChanged: _handleVisibilityChange,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFADD8E6), // Azul Suave
                Color(0xFF90EE90), // Verde Esperanza
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              if (_isWebViewVisible ||
                  !_isLoading) // Conditionally build WebViewWidget
                WebViewWidget(controller: _webViewController),
              if (_isLoading &&
                  _isWebViewVisible) // Show loading only when visible and loading
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          _loadingMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
