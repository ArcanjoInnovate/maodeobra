// lib/widgets/expiration_warning_widget.dart

import 'package:dartobra_new/services/expiration/expiration_service.dart';
import 'package:flutter/material.dart';


/// Widget que exibe avisos de expiração para vagas e perfis profissionais
class ExpirationWarningWidget extends StatelessWidget {
  final dynamic expiresAt;
  final VoidCallback? onRenew;
  final bool isCompact;

  const ExpirationWarningWidget({
    Key? key,
    required this.expiresAt,
    this.onRenew,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final expirationService = ExpirationService();
    
    final isExpired = expirationService.isExpired(expiresAt);
    final isNearExpiration = expirationService.isNearExpiration(expiresAt);
    final daysLeft = expirationService.daysUntilExpiration(expiresAt);

    // Não mostra nada se tiver mais de 1 dia
    if (!isExpired && !isNearExpiration) {
      return const SizedBox.shrink();
    }

    final Color backgroundColor;
    final Color textColor;
    final Color borderColor;
    final IconData icon;
    final String displayTitle;
    final String displayBody;

    if (isExpired) {
      backgroundColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFFDC2626);
      borderColor = const Color(0xFFDC2626);
      icon = Icons.trending_down_rounded;
      displayTitle = 'Publicação com 2 dias — renovação necessária';
      displayBody =
          'Sua publicação foi postada há 2 dias e pode estar sumindo '
          'do feed e da busca por ficar no final da lista. '
          'Renove agora para voltar ao topo e aumentar suas chances de visualização.';
    } else if (daysLeft == 1) {
      backgroundColor = const Color(0xFFFFF7ED);
      textColor = const Color(0xFFEA580C);
      borderColor = const Color(0xFFEA580C);
      icon = Icons.schedule_rounded;
      displayTitle = 'Publicação expira amanhã — renove para o topo';
      displayBody =
          'Sua publicação tem menos de 1 dia antes de completar 2 dias. '
          'Quanto mais antiga, mais ela fica no final do feed e da busca. '
          'Renove agora para subir ao topo da lista.';
    } else {
      backgroundColor = const Color(0xFFFFF7ED);
      textColor = const Color(0xFFEA580C);
      borderColor = const Color(0xFFEA580C);
      icon = Icons.schedule_rounded;
      displayTitle = 'Publicação expira em $daysLeft dia(s)';
      displayBody =
          'Sua publicação foi postada há pouco mais de 1 dia. '
          'Em breve ela pode começar a sumir do topo do feed e da busca. '
          'Renove quando chegar a hora para voltar ao topo.';
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(
              isExpired ? 'Renovar para o topo' : 'Expira em breve',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            displayBody,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.85),
              height: 1.45,
            ),
          ),
          if (onRenew != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onRenew,
                style: TextButton.styleFrom(
                  backgroundColor: textColor,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Renovar e voltar ao topo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge de expiração pequeno para usar em cards
class ExpirationBadge extends StatelessWidget {
  final dynamic expiresAt;

  const ExpirationBadge({
    Key? key,
    required this.expiresAt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final expirationService = ExpirationService();
    
    final isExpired = expirationService.isExpired(expiresAt);
    final daysLeft = expirationService.daysUntilExpiration(expiresAt);

    // Não mostra se tiver mais de 2 dias
    if (!isExpired && daysLeft > 2) {
      return const SizedBox.shrink();
    }

    final Color backgroundColor;
    final Color textColor;
    final String text;

    if (isExpired) {
      backgroundColor = const Color(0xFFDC2626);
      textColor = Colors.white;
      text = 'EXPIRADO';
    } else if (daysLeft == 1) {
      backgroundColor = const Color(0xFFEA580C);
      textColor = Colors.white;
      text = 'EXPIRA AMANHÃ';
    } else {
      backgroundColor = const Color(0xFFEA580C);
      textColor = Colors.white;
      text = 'EXPIRA EM ${daysLeft}D';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Dialog para confirmar renovação
class RenewConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;

  const RenewConfirmationDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 32,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Renovar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}