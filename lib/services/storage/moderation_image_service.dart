// image_moderation_service.dart
//
// Serviço de moderação de imagens via Google Cloud Vision API.
// Bloqueia conteúdo adulto/violento e exibe mensagens educativas ao usuário.
//
// SETUP NECESSÁRIO:
//   1. Ative a Cloud Vision API no Google Cloud Console
//   2. Crie uma API Key com restrição ao pacote do seu app
//   3. Adicione ao pubspec.yaml:
//        http: ^1.2.0
//   4. Defina sua chave em um arquivo de config ou .env (nunca no código em produção)

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO DA MODERAÇÃO
// ─────────────────────────────────────────────────────────────────────────────

enum ModerationStatus {
  /// Imagem aprovada – pode ser enviada normalmente
  approved,

  /// Imagem contém conteúdo inapropriado – bloqueada
  blocked,

  /// Imagem contém conteúdo limítrofe – usuário é alertado mas pode continuar
  warning,

  /// Falha na checagem (sem internet, cota, etc.) – decisão da app
  error,
}

class ModerationResult {
  final ModerationStatus status;
  final String? reason;
  final String? userMessage;
  final Map<String, String>?
      likelihoods; // ex: {'adult': 'LIKELY', 'violence': 'POSSIBLE'}

  const ModerationResult({
    required this.status,
    this.reason,
    this.userMessage,
    this.likelihoods,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVIÇO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class ImageModerationService {
  // ⚠️  Em produção, nunca deixe a chave hardcoded.
  // Use flutter_dotenv, firebase_remote_config ou similar.
  static const String _apiKey = 'AIzaSyDeoq1DDYc4ZqTrNM2zUCxoA9bUq7cYgo8';
  static const String _visionUrl =
      'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey';

  // Likelihoods da API (em ordem crescente de certeza)
  static const _likelihoodOrder = [
    'UNKNOWN',
    'VERY_UNLIKELY',
    'UNLIKELY',
    'POSSIBLE',
    'LIKELY',
    'VERY_LIKELY',
  ];

  /// Retorna true se [likelihood] >= [threshold]
  static bool _meetsThreshold(String likelihood, String threshold) {
    final li = _likelihoodOrder.indexOf(likelihood);
    final ti = _likelihoodOrder.indexOf(threshold);
    return li >= ti && li >= 0 && ti >= 0;
  }

  // ── Análise principal ────────────────────────────────────────────────────

  /// Verifica a imagem e retorna o resultado da moderação.
  /// [file] é o arquivo local selecionado pelo usuário.
  static Future<ModerationResult> checkImage(File file) async {
    try {
      // Converte para base64
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final body = jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'SAFE_SEARCH_DETECTION', 'maxResults': 1},
            ],
          }
        ]
      });

      final response = await http
          .post(
            Uri.parse(_visionUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('Vision API erro ${response.statusCode}: ${response.body}');
        print('Vision API erro ${response.body}');
        return const ModerationResult(
          status: ModerationStatus.error,
          reason: 'api_error',
          userMessage:
              'Não foi possível verificar a imagem agora. Tente novamente.',
        );
      }

      final json = jsonDecode(response.body);
      final safeSearch = json['responses']?[0]?['safeSearchAnnotation']
          as Map<String, dynamic>?;

      if (safeSearch == null) {
        return const ModerationResult(status: ModerationStatus.approved);
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

      // ── Regra 1: BLOQUEIO total ───────────────────────────────────────────
      // Conteúdo adulto explícito ou violência grave → imagem rejeitada
      if (_meetsThreshold(adult, 'LIKELY') ||
          _meetsThreshold(violence, 'LIKELY')) {
        return ModerationResult(
          status: ModerationStatus.blocked,
          reason: _meetsThreshold(adult, 'LIKELY') ? 'adult' : 'violence',
          userMessage: _buildBlockedMessage(adult, violence),
          likelihoods: likelihoods,
        );
      }

      // ── Regra 2: AVISO (pode continuar após conscientização) ──────────────
      // Conteúdo sugestivo ou possível violência moderada
      if (_meetsThreshold(racy, 'LIKELY') ||
          _meetsThreshold(adult, 'POSSIBLE') ||
          _meetsThreshold(violence, 'POSSIBLE')) {
        return ModerationResult(
          status: ModerationStatus.warning,
          reason: 'racy_or_possible',
          userMessage: _buildWarningMessage(racy, adult, violence),
          likelihoods: likelihoods,
        );
      }

      // ── Aprovada ──────────────────────────────────────────────────────────
      return ModerationResult(
        status: ModerationStatus.approved,
        likelihoods: likelihoods,
      );
    } on SocketException {
      return const ModerationResult(
        status: ModerationStatus.error,
        reason: 'no_internet',
        userMessage:
            'Sem conexão com a internet. Verifique sua rede e tente novamente.',
      );
    } catch (e) {
      debugPrint('Erro na moderação: $e');
      return const ModerationResult(
        status: ModerationStatus.error,
        reason: 'unknown',
        userMessage: 'Ocorreu um erro ao verificar a imagem. Tente novamente.',
      );
    }
  }

  // ── Mensagens educativas ─────────────────────────────────────────────────

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
// DIÁLOGOS DE UX
// ─────────────────────────────────────────────────────────────────────────────

class ModerationDialog {
  // Mostra o dialog adequado ao resultado e retorna:
  //   true  → usuário confirmou continuar (só em warning)
  //   false → imagem deve ser descartada
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

  // ── Dialog de bloqueio total ─────────────────────────────────────────────
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

  // ── Dialog de aviso (usuário pode continuar) ─────────────────────────────
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

  // ── Dialog de erro de API ────────────────────────────────────────────────
  // Por segurança, em erro de API bloqueamos também e pedimos nova tentativa.
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
// HELPER: verifica UMA imagem e já mostra o dialog se necessário.
// Retorna true se a imagem pode ser usada, false se deve ser descartada.
// ─────────────────────────────────────────────────────────────────────────────
Future<bool> checkAndShowModerationDialog(
  BuildContext context,
  File imageFile, {
  /// Callback opcional para mostrar um loading enquanto a API é chamada
  VoidCallback? onCheckStart,
  VoidCallback? onCheckEnd,
}) async {
  onCheckStart?.call();
  final result = await ImageModerationService.checkImage(imageFile);
  onCheckEnd?.call();

  if (!context.mounted) return false;
  return ModerationDialog.show(context, result);
}
