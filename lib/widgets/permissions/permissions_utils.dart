// lib/utils/permission_handler_util.dart - ✅ VERSÃO iOS 100% CORRIGIDA

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resultado da checagem de permissão
enum PermissionResult {
  granted,           // ✅ Permissão concedida
  denied,            // ⚠️ Negada agora (pode pedir de novo)
  permanentlyDenied, // 🔒 Negada permanentemente → Settings
}

class PermissionUtil {
  /// ✅ Checa e solicita permissão para câmera ou galeria
  static Future<PermissionResult> checkAndRequest({
    required bool isCamera,
  }) async {
    print('📸 Checando permissão ${isCamera ? 'CÂMERA' : 'GALERIA'}...');
    
    Permission permission;
    
    if (isCamera) {
      permission = Permission.camera;
    } else {
      // ✅ iOS = photos | Android 13+ = photos | Android <13 = storage
      if (Platform.isIOS) {
        permission = Permission.photos;
      } else {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        permission = androidInfo.version.sdkInt >= 33 
            ? Permission.photos 
            : Permission.storage;
      }
    }

    // ✅ Status ATUAL
    final status = await permission.status;
    print('📸 Status atual: $status');

    if (status.isGranted) {
      print('✅ Já concedida');
      return PermissionResult.granted;
    }
    
    if (status.isPermanentlyDenied) {
      print('🔒 Já permanentemente negada');
      return PermissionResult.permanentlyDenied;
    }

    // ✅ PEDIR PERMISSÃO
    final result = await permission.request();
    print('📸 Resultado request: $result');

    if (result.isGranted) return PermissionResult.granted;
    if (result.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    
    return PermissionResult.denied;
  }

  /// ✅ Diálogo inteligente baseado no resultado
  static Future<bool?> showPermissionDialog({
    required BuildContext context,
    required PermissionResult result,
    required String permissionLabel, // 'câmera', 'galeria'
    required String usageReason,     // 'para foto de perfil'
  }) async {
    print('💬 Mostrando dialog: $result | $permissionLabel');

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: result == PermissionResult.permanentlyDenied 
                    ? const Color(0xFFFFE4E4) 
                    : const Color(0xFFFFF3CD),
                shape: BoxShape.circle,
              ),
              child: Icon(
                result == PermissionResult.permanentlyDenied 
                    ? Icons.lock 
                    : Icons.lock_outline,
                color: result == PermissionResult.permanentlyDenied 
                    ? const Color(0xFFDC2626) 
                    : const Color(0xFFD97706),
                size: 28,
              ),
            ),
            Expanded(
              child: Text(
                result == PermissionResult.permanentlyDenied 
                    ? 'Permissão $permissionLabel bloqueada' 
                    : 'Permissão $permissionLabel necessária',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precisamos acessar sua $permissionLabel $usageReason.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            if (result == PermissionResult.permanentlyDenied) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    children: [
                      const WidgetSpan(child: Icon(Icons.info_outline, size: 16, color: Colors.blue)),
                      const WidgetSpan(child: SizedBox(width: 8)),
                      TextSpan(
                        text: Platform.isIOS 
                            ? 'Configurações → Dartobra New → Fotos' 
                            : 'Configurações → Apps → Dartobra New → $permissionLabel',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          if (result != PermissionResult.permanentlyDenied) ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tentar Novamente'),
            ),
          ],
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: Text(result == PermissionResult.permanentlyDenied 
                ? 'Configurações' 
                : 'Abrir Configurações'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}