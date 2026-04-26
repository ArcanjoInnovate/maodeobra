import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
  restricted, // iOS only
}

class PermissionUtil {
  /// Verifica e solicita permissão de câmera ou galeria
  static Future<PermissionResult> checkAndRequest({required bool isCamera}) async {
    final Permission permission = isCamera ? Permission.camera : Permission.photos;
    
    final PermissionStatus status = await permission.status;
    
    // Já concedida
    if (status.isGranted || status.isLimited) {
      return PermissionResult.granted;
    }
    
    // Negada permanentemente (Android) ou Restrita (iOS)
    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }
    if (Platform.isIOS && status.isRestricted) {
      return PermissionResult.restricted;
    }
    
    // Solicita permissão
    final PermissionStatus result = await permission.request();
    
    if (result.isGranted || result.isLimited) {
      return PermissionResult.granted;
    } else if (result.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    } else if (Platform.isIOS && result.isRestricted) {
      return PermissionResult.restricted;
    } else {
      return PermissionResult.denied;
    }
  }
  
  /// Mostra dialog explicando a permissão
  static Future<bool?> showPermissionDialog({
    required BuildContext context,
    required PermissionResult result,
    required String permissionLabel,
    required String usageReason,
  }) async {
    if (result == PermissionResult.granted) return true;
    
    final bool isPermanent = result == PermissionResult.permanentlyDenied || 
                             result == PermissionResult.restricted;
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Permissão Necessária',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPermanent
                  ? 'Acesso à $permissionLabel foi negado permanentemente.'
                  : 'Precisamos de acesso à $permissionLabel $usageReason.',
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            if (isPermanent) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Vá em Ajustes e ative a permissão manualmente.',
                        style: TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, true);
              if (isPermanent) {
                await openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              isPermanent ? 'Abrir Ajustes' : 'Tentar Novamente',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}