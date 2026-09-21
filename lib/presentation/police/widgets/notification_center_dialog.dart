import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../../services/notification_history_service.dart';
import '../../../services/police_notification_service.dart';
import '../screens/police_comments_management_screen.dart';

class NotificationCenterDialog extends StatefulWidget {
  const NotificationCenterDialog({super.key});

  @override
  State<NotificationCenterDialog> createState() => _NotificationCenterDialogState();
}

class _NotificationCenterDialogState extends State<NotificationCenterDialog> {
  final NotificationHistoryService _historyService = NotificationHistoryService();
  final PoliceNotificationService _notificationService = PoliceNotificationService();
  Map<String, List<NotificationHistoryItem>> _groupedNotifications = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() => _isLoading = true);

      // Obtener el departamento del policía actual
      final policeService = PoliceNotificationService();
      await policeService.initialize();
      
      // Obtener todas las notificaciones agrupadas por fecha
      final allGrouped = _historyService.getNotificationsGroupedByDate();
      
      // Filtrar solo las notificaciones del departamento del policía
      final filtered = <String, List<NotificationHistoryItem>>{};
      
      for (final entry in allGrouped.entries) {
        final departmentFiltered = entry.value.where((notification) {
          // Aquí puedes agregar lógica adicional de filtrado si es necesario
          return true; // Por ahora, mostrar todas las notificaciones del historial
        }).toList();
        
        if (departmentFiltered.isNotEmpty) {
          filtered[entry.key] = departmentFiltered;
        }
      }

      if (!mounted) return;
      setState(() {
        _groupedNotifications = filtered;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error al cargar notificaciones: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToComments(NotificationHistoryItem notification) async {
    try {
      // Marcar la notificación como leída
      await _historyService.markAsRead(notification.id);
      
      // Obtener los datos actualizados del desaparecido
      final desaparecido = await _historyService.getDesaparecidoData(notification.desaparecidoId);
      
      if (desaparecido != null && mounted) {
        // Cerrar el diálogo actual
        Navigator.of(context).pop();
        
        // Navegar a la pantalla de gestión de comentarios
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PoliceCommentsManagementScreen(
              desaparecido: desaparecido,
            ),
          ),
        );
        
        // Proporcionar feedback háptico
        HapticFeedback.lightImpact();
      } else {
        _showErrorSnackBar('No se pudo cargar la información del caso');
      }
    } catch (e) {
      print('❌ Error al navegar a comentarios: $e');
      _showErrorSnackBar('Error al abrir el caso');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _historyService.markAllAsRead();
      await _notificationService.counterService?.markAllAsRead();
      await _loadNotifications(); // Recargar para actualizar la UI
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas las notificaciones marcadas como leídas'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Error al marcar todas como leídas: $e');
      _showErrorSnackBar('Error al marcar notificaciones como leídas');
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Historial'),
        content: const Text('¿Estás seguro de que quieres eliminar todo el historial de notificaciones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _historyService.clearHistory();
        await _loadNotifications();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Historial eliminado correctamente'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        print('❌ Error al limpiar historial: $e');
        _showErrorSnackBar('Error al eliminar el historial');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0D1B2A).withOpacity(0.95),
                    const Color(0xFF1B263B).withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildContent()),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(25),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE63946), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const FaIcon(
              FontAwesomeIcons.bell,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Text(
              'CENTRO DE ALERTAS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const FaIcon(
              FontAwesomeIcons.ellipsisVertical,
              color: Colors.white,
              size: 16,
            ),
            color: const Color(0xFF1B263B),
            onSelected: (value) {
              switch (value) {
                case 'mark_all_read':
                  _markAllAsRead();
                  break;
                case 'clear_history':
                  _clearHistory();
                  break;
                case 'refresh':
                  _loadNotifications();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    FaIcon(FontAwesomeIcons.check, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Marcar todas como leídas', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    FaIcon(FontAwesomeIcons.arrowsRotate, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Actualizar', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_history',
                child: Row(
                  children: [
                    FaIcon(FontAwesomeIcons.trash, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Limpiar historial', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.xmark,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_groupedNotifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: const Color(0xFFE63946),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _groupedNotifications.length,
        itemBuilder: (context, index) {
          final entry = _groupedNotifications.entries.elementAt(index);
          return _buildDateGroup(entry.key, entry.value);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(
            FontAwesomeIcons.bellSlash,
            color: Color(0xFF778DA9),
            size: 64,
          ),
          const SizedBox(height: 20),
          const Text(
            'Sin notificaciones',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No hay alertas en tu historial.\nLas nuevas notificaciones aparecerán aquí.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(String date, List<NotificationHistoryItem> notifications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  date,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ),
        ...notifications.map((notification) => _buildNotificationItem(notification)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNotificationItem(NotificationHistoryItem notification) {
    final timeFormat = DateFormat('HH:mm');
    final time = timeFormat.format(notification.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToComments(notification),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: notification.isRead 
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFE63946).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: notification.isRead 
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFE63946).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE63946),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (!notification.isRead) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notification.desaparecidoNombre,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  notification.body,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notification.departamento,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const FaIcon(
                      FontAwesomeIcons.chevronRight,
                      color: Colors.white54,
                      size: 12,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Cerrar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}