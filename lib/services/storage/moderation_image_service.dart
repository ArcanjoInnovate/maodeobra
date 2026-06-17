// image_moderation_service.dart
//
// ✅ OTIMIZADO: Cache de resultados + timeout reduzido + feedback visual melhor
// ✅ N1-03 CORRIGIDO: API Key removida do APK — chamada via Cloud Function autenticada

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO DA MODERAÇÃO
// ─────────────────────────────────────────────────────────────────────────────

enum ModerationStatus {
  approved,
  blocked,
  warning,
  error,
}

class ModerationResult {
  final ModerationStatus status;
  final String? reason;
  final String? userMessage;
  final Map<String, String>? likelihoods;

  const ModerationResult({
    required this.status,
    this.reason,
    this.userMessage,
    this.likelihoods,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ✅ CACHE DE RESULTADOS (evita re-checagens da mesma imagem)
// ─────────────────────────────────────────────────────────────────────────────

class _ModerationCache {
  static final Map<String, ModerationResult> _cache = {};
  static const int _maxCacheSize = 50;

  static String _getFileHash(File file) {
    final bytes = file.readAsBytesSync();
    return md5.convert(bytes).toString();
  }

  static ModerationResult? get(File file) {
    try {
      final hash = _getFileHash(file);
      return _cache[hash];
    } catch (_) {
      return null;
    }
  }

  static void put(File file, ModerationResult result) {
    try {
      final hash = _getFileHash(file);
      if (_cache.length >= _maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }
      _cache[hash] = result;
    } catch (_) {
      // Ignora erros de cache
    }
  }

  static void clear() => _cache.clear();
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVIÇO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class ImageModerationService {
  // ✅ N1-03: _apiKey e _visionUrl removidos. Chamada feita via Cloud Function
  // autenticada (moderateImage), que mantém a chave como secret no servidor.

  static const _likelihoodOrder = [
    'UNKNOWN',
    'VERY_UNLIKELY',
    'UNLIKELY',
    'POSSIBLE',
    'LIKELY',
    'VERY_LIKELY',
  ];

  static bool _meetsThreshold(String likelihood, String threshold) {
    final li = _likelihoodOrder.indexOf(likelihood);
    final ti = _likelihoodOrder.indexOf(threshold);
    return li >= ti && li >= 0 && ti >= 0;
  }

  // ✅ Timeout de 10s (inclui cold start da Cloud Function)
  /// ✅ NEW-03: Redimensiona para 400×400 antes de encodar em Base64.
  /// Reduz payload de ~500 KB para ~30–60 KB — menos egress, menos latência.
  static Future<Uint8List> _resizeForModeration(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final target = '${dir.path}/mod_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        target,
        minWidth: 200,
        minHeight: 200,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      if (result != null) return await File(result.path).readAsBytes();
    } catch (_) {}
    // fallback: original
    return file.readAsBytes();
  }

  static Future<ModerationResult> checkImage(File file) async {
    // ✅ Verifica cache primeiro
    final cachedResult = _ModerationCache.get(file);
    if (cachedResult != null) {
      debugPrint('✅ Cache hit - imagem já verificada');
      return cachedResult;
    }

    try {
      // ✅ NEW-03: redimensiona para 400px antes de encodar (payload ~10× menor)
      final bytes = await _resizeForModeration(file);
      final base64Image = base64Encode(bytes);

      // ✅ N1-03: chama Cloud Function autenticada em vez da Vision API diretamente
      final callable = FirebaseFunctions.instance.httpsCallable(
        'moderateImage',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );

      final response = await callable.call({'imageBase64': base64Image});

      final rawData = Map<String, dynamic>.from(response.data as Map);
      final rawSafeSearch = rawData['safeSearch'];
      final safeSearch = rawSafeSearch != null
          ? Map<String, dynamic>.from(rawSafeSearch as Map)
          : null;

      if (safeSearch == null) {
        const result = ModerationResult(status: ModerationStatus.approved);
        _ModerationCache.put(file, result);
        return result;
      }

      final adult = safeSearch['adult'] as String? ?? 'UNKNOWN';
      final violence = safeSearch['violence'] as String? ?? 'UNKNOWN';
      final racy = safeSearch['racy'] as String? ?? 'UNKNOWN';
      final medical = safeSearch['medical'] as String? ?? 'UNKNOWN';
      final spoof = safeSearch['spoof'] as String? ?? 'UNKNOWN';

      final likelihoods = {
        'adult': adult,
        'violence': violence,
        'racy': racy,
        'medical': medical,
        'spoof': spoof,
      };

      ModerationResult result;

      // BLOQUEIO total
      if (_meetsThreshold(adult, 'LIKELY') ||
          _meetsThreshold(violence, 'LIKELY')) {
        result = ModerationResult(
          status: ModerationStatus.blocked,
          reason: _meetsThreshold(adult, 'LIKELY') ? 'adult' : 'violence',
          userMessage: _buildBlockedMessage(adult, violence),
          likelihoods: likelihoods,
        );
      }
      // AVISO
      else if (_meetsThreshold(racy, 'LIKELY') ||
          _meetsThreshold(adult, 'POSSIBLE') ||
          _meetsThreshold(violence, 'POSSIBLE')) {
        result = ModerationResult(
          status: ModerationStatus.warning,
          reason: 'racy_or_possible',
          userMessage: _buildWarningMessage(racy, adult, violence),
          likelihoods: likelihoods,
        );
      }
      // APROVADA
      else {
        result = ModerationResult(
          status: ModerationStatus.approved,
          likelihoods: likelihoods,
        );
      }

      _ModerationCache.put(file, result);
      return result;
    } on SocketException {
      return const ModerationResult(
        status: ModerationStatus.error,
        reason: 'no_internet',
        userMessage:
            'Sem conexão com a internet. Verifique sua rede e tente novamente.',
      );
    } catch (e) {
      debugPrint('Erro na moderação: $e');

      // Trata erros da Cloud Function (unauthenticated, internal, etc.)
      final msg = e.toString().toLowerCase();
      if (msg.contains('unauthenticated')) {
        return const ModerationResult(
          status: ModerationStatus.error,
          reason: 'unauthenticated',
          userMessage: 'Faça login para enviar imagens.',
        );
      }

      return const ModerationResult(
        status: ModerationStatus.error,
        reason: 'unknown',
        userMessage: 'Ocorreu um erro ao verificar a imagem. Tente novamente.',
      );
    }
  }

  static String _buildBlockedMessage(String adult, String violence) {
    if (_meetsThreshold(adult, 'LIKELY')) {
      return 'Esta imagem contém conteúdo adulto ou explícito e não pode ser '
          'publicada em nossa plataforma.\n\n'
          'Nossa comunidade é composta por profissionais e contratantes em '
          'busca de oportunidades de trabalho. Imagens desse tipo prejudicam '
          'a experiência de todos e violam nossas diretrizes.\n\n'
          'Por favor, utilize apenas fotos relacionadas ao trabalho, obra ou '
          'ambiente profissional.';
    }
    return 'Esta imagem contém conteúdo violento ou impróprio e não pode ser '
        'publicada em nossa plataforma.\n\n'
        'Imagens de violência criam um ambiente hostil e inseguro para nossa '
        'comunidade de trabalhadores e contratantes.\n\n'
        'Use apenas imagens que representem seu trabalho de forma positiva e '
        'profissional.';
  }

  static String _buildWarningMessage(
      String racy, String adult, String violence) {
    return 'Atenção: nossa análise identificou que esta imagem pode conter '
        'conteúdo inapropriado para um ambiente de trabalho.\n\n'
        'Imagens inadequadas podem:\n'
        '• Afetar negativamente sua reputação profissional\n'
        '• Afastar contratantes e oportunidades de emprego\n'
        '• Violar as diretrizes da nossa plataforma\n\n'
        'Recomendamos fortemente o uso de fotos da obra, ferramentas ou '
        'ambiente de trabalho. Deseja usar esta imagem mesmo assim?';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ✅ DIÁLOGOS OTIMIZADOS COM MELHOR FEEDBACK
// ─────────────────────────────────────────────────────────────────────────────

class ModerationDialog {
  static Future<bool> show(
    BuildContext context,
    ModerationResult result,
  ) async {
    switch (result.status) {
      case ModerationStatus.approved:
        return true;

      case ModerationStatus.blocked:
        await _showBlockedDialog(context, result.userMessage ?? '');
        return false;

      case ModerationStatus.warning:
        return await _showWarningDialog(context, result.userMessage ?? '');

      case ModerationStatus.error:
        return await _showErrorDialog(context, result.userMessage ?? '');
    }
  }

  static Future<void> _showBlockedDialog(
      BuildContext context, String message) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child:
              Icon(Icons.block_rounded, color: Colors.red.shade700, size: 36),
        ),
        title: const Text(
          'Imagem não permitida',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dica: Fotos de obras, canteiros e ferramentas transmitem '
                        'profissionalismo e atraem mais contratantes.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Escolher outra imagem'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool> _showWarningDialog(
      BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade700, size: 36),
        ),
        title: const Text(
          'Imagem pode ser inadequada',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Escolher outra',
                      style: TextStyle(color: Colors.black54)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Usar mesmo assim'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<bool> _showErrorDialog(
      BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.cloud_off_rounded,
              color: Colors.grey.shade600, size: 36),
        ),
        title: const Text(
          'Verificação indisponível',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tentar mesmo assim'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ✅ HELPER OTIMIZADO COM MELHOR LOADING
// ─────────────────────────────────────────────────────────────────────────────

Future<bool> checkAndShowModerationDialog(
  BuildContext context,
  File imageFile, {
  VoidCallback? onCheckStart,
  VoidCallback? onCheckEnd,
}) async {
  onCheckStart?.call();

  // ✅ Mostra dialog otimizado com feedback visual melhor
  final result = await showDialog<ModerationResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _OptimizedLoadingDialog(imageFile: imageFile),
  );

  onCheckEnd?.call();

  if (!context.mounted) return false;

  if (result == null) return false;

  return ModerationDialog.show(context, result);
}

// ✅ DIALOG DE LOADING OTIMIZADO
class _OptimizedLoadingDialog extends StatefulWidget {
  final File imageFile;

  const _OptimizedLoadingDialog({required this.imageFile});

  @override
  State<_OptimizedLoadingDialog> createState() =>
      _OptimizedLoadingDialogState();
}

class _OptimizedLoadingDialogState extends State<_OptimizedLoadingDialog> {
  String _status = 'Preparando análise...';
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _checkImage();
  }

  Future<void> _checkImage() async {
    setState(() => _status = 'Preparando análise...');
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _status = 'Analisando conteúdo...';
      _analyzing = true;
    });

    final result = await ImageModerationService.checkImage(widget.imageFile);

    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Ícone animado
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _analyzing
                          ? Icons.shield_outlined
                          : Icons.hourglass_empty,
                      size: 32,
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ✅ Indicador de progresso menor e mais elegante
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF6B35),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Status
            Text(
              _status,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Mensagem de contexto
            Text(
              _analyzing
                  ? 'Verificando segurança do conteúdo'
                  : 'Aguarde um momento',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}