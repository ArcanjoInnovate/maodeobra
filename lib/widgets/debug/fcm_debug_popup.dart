import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';

class FCMDebugPopup extends StatefulWidget {
  final String userId;

  const FCMDebugPopup({super.key, required this.userId});

  @override
  State<FCMDebugPopup> createState() => _FCMDebugPopupState();
}

class _FCMDebugPopupState extends State<FCMDebugPopup> {
  final List<DebugLog> _logs = [];
  bool _isProcessing = true;
  String _finalStatus = '';

  @override
  void initState() {
    super.initState();
    _startFCMProcess();
  }

  void _addLog(String message, LogType type) {
    setState(() {
      _logs.add(DebugLog(
        message: message,
        type: type,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _startFCMProcess() async {
    try {
      _addLog('🚀 Iniciando processo FCM...', LogType.info);
      _addLog('👤 UserID: ${widget.userId}', LogType.info);
      
      await Future.delayed(const Duration(milliseconds: 500));

      // ── 1. Solicitar permissões ──────────────────────────────────────
      _addLog('📱 Solicitando permissões...', LogType.info);
      
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final statusName = _getAuthStatusName(settings.authorizationStatus);
      _addLog('✅ Permissão: $statusName', 
          settings.authorizationStatus == AuthorizationStatus.authorized 
              ? LogType.success 
              : LogType.warning);

      await Future.delayed(const Duration(milliseconds: 500));

      // ── 2. Obter tokens ──────────────────────────────────────────────
      _addLog('🔑 Obtendo tokens...', LogType.info);
      
      String? apnsToken;
      String? fcmToken;

      try {
        if (Platform.isIOS) {
          _addLog('📲 Plataforma: iOS', LogType.info);
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          _addLog(
            apnsToken != null 
                ? '✅ APNS Token obtido: ${apnsToken.substring(0, 20)}...' 
                : '❌ APNS Token: null',
            apnsToken != null ? LogType.success : LogType.error,
          );
        } else {
          _addLog('📲 Plataforma: Android', LogType.info);
        }

        await Future.delayed(const Duration(milliseconds: 300));

        fcmToken = await FirebaseMessaging.instance.getToken();
        _addLog(
          fcmToken != null 
              ? '✅ FCM Token obtido: ${fcmToken.substring(0, 30)}...' 
              : '❌ FCM Token: null',
          fcmToken != null ? LogType.success : LogType.error,
        );

      } catch (e) {
        _addLog('❌ Erro ao obter tokens: $e', LogType.error);
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // ── 3. Salvar dados de debug ─────────────────────────────────────
      _addLog('💾 Salvando dados de debug...', LogType.info);
      
      try {
        await FirebaseDatabase.instance
            .ref('Users/${widget.userId}/fcmDebug')
            .set({
          'authStatus': settings.authorizationStatus.index,
          'authStatusName': statusName,
          'apnsNull': apnsToken == null,
          'fcmNull': fcmToken == null,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        _addLog('✅ Debug salvo em Users/${widget.userId}/fcmDebug', LogType.success);
      } catch (e) {
        _addLog('❌ Erro ao salvar debug: $e', LogType.error);
        
        // Tenta nó alternativo
        try {
          await FirebaseDatabase.instance
              .ref('debug_fcm/${widget.userId}')
              .set({
            'error': 'Falha ao salvar em Users',
            'details': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          });
          _addLog('⚠️ Debug salvo em nó alternativo: debug_fcm/${widget.userId}', LogType.warning);
        } catch (altError) {
          _addLog('❌ Erro no nó alternativo: $altError', LogType.error);
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // ── 4. Salvar FCM Token ──────────────────────────────────────────
      if (fcmToken != null) {
        _addLog('💾 Salvando FCM Token...', LogType.info);
        
        try {
          await FirebaseDatabase.instance
              .ref('Users/${widget.userId}/fcmToken')
              .set(fcmToken);
          
          _addLog('✅ FCM Token salvo com sucesso!', LogType.success);
          _addLog('📍 Caminho: Users/${widget.userId}/fcmToken', LogType.info);
          
          setState(() {
            _finalStatus = 'success';
          });
          
        } catch (e) {
          _addLog('❌ Erro ao salvar FCM Token: $e', LogType.error);
          
          // Tenta nó alternativo
          try {
            await FirebaseDatabase.instance
                .ref('debug_fcm/${widget.userId}/token')
                .set(fcmToken);
            _addLog('⚠️ Token salvo em debug_fcm/${widget.userId}/token', LogType.warning);
            
            setState(() {
              _finalStatus = 'partial';
            });
          } catch (altError) {
            _addLog('❌ Falha total ao salvar token: $altError', LogType.error);
            setState(() {
              _finalStatus = 'error';
            });
          }
        }
      } else {
        _addLog('⚠️ Sem FCM Token para salvar', LogType.warning);
        setState(() {
          _finalStatus = 'no_token';
        });
      }

      // ── 5. Verificação final ─────────────────────────────────────────
      await Future.delayed(const Duration(milliseconds: 500));
      _addLog('🔍 Verificando dados salvos...', LogType.info);
      
      try {
        final snapshot = await FirebaseDatabase.instance
            .ref('Users/${widget.userId}')
            .get();
        
        if (snapshot.exists) {
          final data = snapshot.value as Map?;
          _addLog('✅ Nó Users/${widget.userId} existe', LogType.success);
          
          if (data?.containsKey('fcmToken') == true) {
            _addLog('✅ fcmToken encontrado no banco', LogType.success);
          } else {
            _addLog('⚠️ fcmToken NÃO encontrado no banco', LogType.warning);
          }
          
          if (data?.containsKey('fcmDebug') == true) {
            _addLog('✅ fcmDebug encontrado no banco', LogType.success);
          }
        } else {
          _addLog('❌ Nó Users/${widget.userId} NÃO existe!', LogType.error);
        }
      } catch (e) {
        _addLog('❌ Erro ao verificar: $e', LogType.error);
      }

    } catch (e) {
      _addLog('❌ ERRO GERAL: $e', LogType.error);
      setState(() {
        _finalStatus = 'error';
      });
      
      // Tenta salvar erro geral
      try {
        await FirebaseDatabase.instance
            .ref('debug_fcm/${widget.userId}/generalError')
            .set({
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        });
        _addLog('⚠️ Erro salvo em debug_fcm/${widget.userId}/generalError', LogType.warning);
      } catch (_) {
        _addLog('❌ Não foi possível salvar nem o erro', LogType.error);
      }
    }

    setState(() {
      _isProcessing = false;
    });
    
    _addLog('🏁 Processo finalizado!', LogType.info);
  }

  String _getAuthStatusName(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return 'Autorizado';
      case AuthorizationStatus.denied:
        return 'Negado';
      case AuthorizationStatus.notDetermined:
        return 'Não determinado';
      case AuthorizationStatus.provisional:
        return 'Provisório';
      default:
        return 'Desconhecido';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F36),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bug_report_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Debug FCM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Processo de salvamento',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isProcessing)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                ],
              ),
            ),

            // ── Logs ──────────────────────────────────────────────────
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              log.message,
                              style: TextStyle(
                                color: _getLogColor(log.type),
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Status Final ──────────────────────────────────────────
            if (!_isProcessing && _finalStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(_finalStatus).withOpacity(0.1),
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.shade800,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(_finalStatus),
                      color: _getStatusColor(_finalStatus),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getStatusMessage(_finalStatus),
                        style: TextStyle(
                          color: _getStatusColor(_finalStatus),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Loading ou Botão Fechar ───────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: _isProcessing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.blue.shade400,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Processando...',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Fechar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLogColor(LogType type) {
    switch (type) {
      case LogType.success:
        return Colors.green.shade400;
      case LogType.error:
        return Colors.red.shade400;
      case LogType.warning:
        return Colors.orange.shade400;
      case LogType.info:
        return Colors.blue.shade300;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green.shade400;
      case 'partial':
        return Colors.orange.shade400;
      case 'no_token':
        return Colors.yellow.shade600;
      case 'error':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'success':
        return Icons.check_circle_rounded;
      case 'partial':
        return Icons.warning_rounded;
      case 'no_token':
        return Icons.info_rounded;
      case 'error':
        return Icons.error_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'success':
        return 'Token FCM salvo com sucesso!';
      case 'partial':
        return 'Token salvo parcialmente (nó alternativo)';
      case 'no_token':
        return 'Nenhum token FCM disponível';
      case 'error':
        return 'Erro ao salvar token FCM';
      default:
        return 'Status desconhecido';
    }
  }
}

// ── Models ────────────────────────────────────────────────────────────

enum LogType {
  info,
  success,
  warning,
  error,
}

class DebugLog {
  final String message;
  final LogType type;
  final DateTime timestamp;

  DebugLog({
    required this.message,
    required this.type,
    required this.timestamp,
  });
}