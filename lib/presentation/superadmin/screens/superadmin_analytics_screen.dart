import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../common/widgets/branded_loading_dialog.dart';
import '../../common/widgets/pdf_viewer_modal.dart';
import 'superadmin_sync_monitor_screen.dart';

/// Pantalla exclusiva para el SuperAdmin para visualizar KPIs de adopción,
/// estadísticas de uso por módulo, concentración geográfica e imprimir informes oficiales en PDF.
class SuperAdminAnalyticsScreen extends StatefulWidget {
  const SuperAdminAnalyticsScreen({super.key});

  @override
  State<SuperAdminAnalyticsScreen> createState() => _SuperAdminAnalyticsScreenState();
}

class _SuperAdminAnalyticsScreenState extends State<SuperAdminAnalyticsScreen> {
  bool _isLoading = true;
  int _totalInstalaciones = 0;
  int _totalSesiones = 0;
  Map<String, int> _modulosUso = {};
  Map<String, int> _regionesUso = {};
  final Map<String, int> _plataformas = {};
  final List<Map<String, dynamic>> _ultimasInstalaciones = [];

  String _filtroMes = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filtroMes = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _cargarMetricas();
  }

  Future<void> _cargarMetricas() async {
    setState(() => _isLoading = true);
    try {
      // 1. Obtener conteo de instalaciones totales
      final instSnap = await FirebaseFirestore.instance
          .collection('instalaciones_dispositivos')
          .orderBy('first_open', descending: true)
          .limit(50)
          .get();

      _totalInstalaciones = instSnap.docs.length;
      _ultimasInstalaciones.clear();
      _plataformas.clear();

      for (var doc in instSnap.docs) {
        final data = doc.data();
        _ultimasInstalaciones.add(data);
        final plat = data['platform']?.toString() ?? 'Otro';
        _plataformas[plat] = (_plataformas[plat] ?? 0) + 1;
      }

      // 2. Obtener métricas agregadas del mes actual
      final metricDoc = await FirebaseFirestore.instance
          .collection('metricas_resumen')
          .doc(_filtroMes)
          .get();

      if (metricDoc.exists) {
        final data = metricDoc.data() ?? {};
        _totalSesiones = (data['total_sesiones'] as num?)?.toInt() ?? 0;

        final rawModulos = data['modulos'] as Map<String, dynamic>? ?? {};
        _modulosUso = rawModulos.map((k, v) => MapEntry(k, (v as num).toInt()));

        final rawRegiones = data['regiones'] as Map<String, dynamic>? ?? {};
        _regionesUso = rawRegiones.map((k, v) => MapEntry(k, (v as num).toInt()));
      } else {
        _totalSesiones = 0;
        _modulosUso = {};
        _regionesUso = {};
      }
    } catch (e) {
      debugPrint('⚠️ [SuperAdminAnalytics] Error al cargar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generarReportePdf() async {
    final pdf = pw.Document();
    final fontTitle = await PdfGoogleFonts.robotoBold();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final nowFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Cabecera Oficial
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal800, width: 2)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ALERTA DESAPARECIDOS PERÚ',
                        style: pw.TextStyle(font: fontTitle, fontSize: 16, color: PdfColors.teal900),
                      ),
                      pw.Text(
                        'INFORME EJECUTIVO DE IMPACTO Y ADOPCIÓN TECNOLÓGICA',
                        style: pw.TextStyle(font: fontTitle, fontSize: 11, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Periodo: $_filtroMes', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                      pw.Text('Generado: $nowFormatted', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Resumen Ejecutivo
            pw.Text('1. RESUMEN EJECUTIVO', style: pw.TextStyle(font: fontTitle, fontSize: 13, color: PdfColors.teal800)),
            pw.SizedBox(height: 6),
            pw.Text(
              'El presente informe detalla las métricas de penetración, retención y nivel de servicio de la plataforma preventiva y ciudadana "Alerta Desaparecidos Perú". Todos los datos han sido recolectados de manera anónima mediante telemetría en tiempo real.',
              style: pw.TextStyle(font: fontRegular, fontSize: 10),
            ),
            pw.SizedBox(height: 12),

            // Tabla de KPIs
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Indicador Clave (KPI)', style: pw.TextStyle(font: fontTitle, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Valor Registrado', style: pw.TextStyle(font: fontTitle, fontSize: 10)),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Dispositivos e Instalaciones Registradas', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$_totalInstalaciones equipos', style: pw.TextStyle(font: fontTitle, fontSize: 10))),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Sesiones de Uso en el Periodo', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$_totalSesiones aperturas', style: pw.TextStyle(font: fontTitle, fontSize: 10))),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Módulo Más Solicitado', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_modulosUso.isEmpty ? 'Central de Auxilio' : _modulosUso.entries.first.key, style: pw.TextStyle(font: fontTitle, fontSize: 10, color: PdfColors.teal700)),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Detalle de Uso por Módulos
            pw.Text('2. HERRAMIENTAS Y MÓDULOS MÁS UTILIZADOS', style: pw.TextStyle(font: fontTitle, fontSize: 13, color: PdfColors.teal800)),
            pw.SizedBox(height: 6),
            if (_modulosUso.isEmpty)
              pw.Text('No se registran eventos agregados en este periodo.', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600))
            else
              pw.Column(
                children: _modulosUso.entries.map((entry) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 2),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(entry.key, style: pw.TextStyle(font: fontTitle, fontSize: 10)),
                        pw.Text('${entry.value} interacciones', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),

            pw.SizedBox(height: 16),

            // Distribución de Dispositivos
            pw.Text('3. PLATAFORMAS DE ACCESO CIUDADANO', style: pw.TextStyle(font: fontTitle, fontSize: 13, color: PdfColors.teal800)),
            pw.SizedBox(height: 6),
            pw.Row(
              children: _plataformas.entries.map((entry) {
                return pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(right: 8),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(entry.key, style: pw.TextStyle(font: fontTitle, fontSize: 11, color: PdfColors.teal900)),
                        pw.SizedBox(height: 4),
                        pw.Text('${entry.value} dispositivos', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Desarrollado de forma independiente por S2 PNP Shamir D. Huerta Ccarhuas', style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Página 1 de 1', style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();
    if (mounted) {
      await PdfViewerModal.mostrar(
        context,
        title: 'Informe de Inteligencia y Métricas - $_filtroMes',
        pdfBytes: pdfBytes,
        filename: 'Informe_Impacto_Alerta_Desaparecidos_$_filtroMes.pdf',
        icon: Icons.analytics_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Inteligencia y Métricas SuperAdmin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: Colors.amberAccent),
            tooltip: 'Sincronizar Casos Ahora (PNP)',
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const PnpSyncProgressDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync_alt_rounded, color: Colors.cyanAccent),
            tooltip: 'Centro de Sincronización PNP',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SuperAdminSyncMonitorScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Actualizar Datos',
            onPressed: _cargarMetricas,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.tealAccent),
            tooltip: 'Exportar / Imprimir PDF',
            onPressed: _generarReportePdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: BrandedLoadingWidget(message: 'Cargando métricas y análisis de adopción...', size: 62))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner de Monitoreo de Sincronización PNP (Acceso Rápido)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SuperAdminSyncMonitorScreen()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.sync_rounded, color: Colors.cyanAccent, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Centro de Sincronización PNP',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                      ),
                                      child: const Text('EN VIVO', style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w900)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Ver cada actualización: casos nuevos, ubicados, transiciones y salud del motor.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (_) => const PnpSyncProgressDialog(),
                                        );
                                      },
                                      icon: const Icon(Icons.bolt_rounded, color: Colors.black87, size: 16),
                                      label: const Text(
                                        '⚡ Sincronizar Ahora',
                                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.cyanAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.cyanAccent, size: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Banner de estado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.cyan.shade900.withOpacity(0.5), Colors.blueGrey.shade900.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insights, color: Colors.cyanAccent, size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Centro de Adopción Tecnológica',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Monitoreo anónimo y silencioso de impacto social en Perú.',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _generarReportePdf,
                          icon: const Icon(Icons.print, size: 16, color: Colors.black87),
                          label: const Text('Exportar PDF', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tarjetas de KPIs Principales
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Instalaciones Totales',
                          value: '$_totalInstalaciones',
                          icon: Icons.install_mobile,
                          color: Colors.tealAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Sesiones Activas ($_filtroMes)',
                          value: '$_totalSesiones',
                          icon: Icons.touch_app,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Módulos Más Utilizados
                  const Text(
                    'Uso de Módulos y Herramientas',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_modulosUso.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'Aún no hay interacciones registradas en este periodo. Los datos se actualizarán en tiempo real a medida que los ciudadanos utilicen las herramientas.',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._modulosUso.entries.map((entry) => _buildModuleRow(entry.key, entry.value)),

                  const SizedBox(height: 24),

                  // Regiones y Concentración Geográfica
                  const Text(
                    'Acogida por Regiones / Departamentos',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_regionesUso.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Sin registros de geolocalización regional aún en este mes.', style: TextStyle(color: Colors.white60, fontSize: 12.5)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _regionesUso.entries.map((r) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade900.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                          ),
                          child: Text(
                            '${r.key}: ${r.value} usuarios',
                            style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),

                  // Plataformas
                  const Text(
                    'Plataformas de Acceso (Web vs Móvil)',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: _plataformas.entries.map((e) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.key, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('${e.value} equipos', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Últimos Equipos Conectados (Anónimo)
                  const Text(
                    'Últimos Equipos que Instalaron el App',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _ultimasInstalaciones.take(8).length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _ultimasInstalaciones[index];
                      final plat = item['platform'] ?? 'Desconocido';
                      final model = item['device_model'] ?? 'Dispositivo';
                      final depto = item['departamento'] ?? 'Perú';
                      final sessions = item['total_sessions'] ?? 1;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(plat == 'Web' ? Icons.language : Icons.phone_android, color: Colors.tealAccent, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(model, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text('Región: $depto • $sessions sesión(es)', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.5)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(plat, style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildKpiCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildModuleRow(String moduleName, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(moduleName, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500)),
          Text('$count usos', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13.5)),
        ],
      ),
    );
  }
}
