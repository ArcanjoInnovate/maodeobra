// lib/services/app_lifecycle_service.dart
//
// ✅ OTIMIZADO: ExpirationService client-side removido.
// A verificação de expiração agora é feita exclusivamente pelo
// Cloud Function 'checkExpiringProfessionals' (a cada 1h, server-side).
// Isso elimina escritas duplicadas e garante execução confiável
// mesmo quando nenhum usuário está com o app aberto.

class AppLifecycleService {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    // Sem-op: expiração gerenciada pelo servidor.
  }

  Future<void> checkNow() async {
    // Sem-op: expiração gerenciada pelo servidor.
  }

  void dispose() {
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}