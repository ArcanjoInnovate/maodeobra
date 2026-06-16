// lib/widgets/vacancy/professional_status_control_widget.dart

import 'package:dartobra_new/widgets/expiration_widget.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';

class ProfessionalStatusControlWidget extends StatefulWidget {
  final bool initialIsActive;
  final String localId;
  final String professionalId;
  final Function(bool) onStatusChanged;

  const ProfessionalStatusControlWidget({
    Key? key,
    required this.initialIsActive,
    required this.localId,
    required this.professionalId,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  State<ProfessionalStatusControlWidget> createState() =>
      _ProfessionalStatusControlWidgetState();
}

class _ProfessionalStatusControlWidgetState
    extends State<ProfessionalStatusControlWidget> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ExpirationService _expirationService = ExpirationService();

  late bool _isActive;
  bool _isChanging = false;
  bool _isRenewing = false;
  bool _isLoading = true;

  Map<String, dynamic>? _professionalData;

  @override
  void initState() {
    super.initState();
    _isActive = widget.initialIsActive;
    _loadProfessionalData();
  }

  @override
  void didUpdateWidget(covariant ProfessionalStatusControlWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recarrega quando o professionalId finalmente chega (antes estava vazio)
    if (oldWidget.professionalId != widget.professionalId &&
        widget.professionalId.isNotEmpty) {
      _loadProfessionalData();
    }
  }
  Future<void> _loadProfessionalData() async {
    try {
      if (widget.professionalId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final snapshot = await _database
          .child('professionals/${widget.professionalId}')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        setState(() {
          _professionalData =
              Map<String, dynamic>.from(snapshot.value as Map);
          _isActive =
              _professionalData!['status']?.toString().toLowerCase() == 'active';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados profissionais: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus() async {
    setState(() => _isChanging = true);

    try {
      final newStatus = _isActive ? 'inactive' : 'active';

      await _database
          .child('professionals/${widget.professionalId}/status')
          .set(newStatus);

      await _database
          .child('professionals/${widget.professionalId}/updated_at')
          .set(DateTime.now().toIso8601String());

      await _database
          .child('Users/${widget.localId}/isActive')
          .set(!_isActive);

      setState(() {
        _isActive = !_isActive;
        _isChanging = false;
      });

      widget.onStatusChanged(_isActive);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _isActive
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  _isActive
                      ? 'Perfil ativado com sucesso!'
                      : 'Perfil pausado',
                ),
              ],
            ),
            backgroundColor:
                _isActive ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isChanging = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar status: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _renewProfessional() async {
    showDialog(
      context: context,
      builder: (context) => RenewConfirmationDialog(
        title: 'Voltar ao topo do feed',
        message:
            'Seu perfil foi publicado há 2 dias e pode estar sumindo '
            'do feed e da busca por ficar no final da lista.\n\n'
            'Renovar coloca seu perfil de volta no topo, '
            'aumentando suas chances de ser encontrado por contratantes.',
        onConfirm: () async {
          setState(() => _isRenewing = true);

          try {
            final newExpirationDate = _expirationService.renewExpirationISO();
            final newExpirationTimestamp =
                _expirationService.renewExpirationTimestamp();

            // ✅ Apenas bumpa updated_at e renova expires_at.
            // NÃO altera status — perfil permanece visível independente.
            await _database
                .child('professionals/${widget.professionalId}')
                .update({
              'expires_at': newExpirationDate,
              'expiration_timestamp': newExpirationTimestamp,
              'renewed_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });

            await _loadProfessionalData();

            if (mounted) {
              setState(() => _isRenewing = false);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      const Text('Perfil renovado — de volta ao topo do feed!'),
                    ],
                  ),
                  backgroundColor: const Color(0xFF16A34A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              setState(() => _isRenewing = false);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao renovar perfil: $e'),
                  backgroundColor: const Color(0xFFDC2626),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF2563EB),
          ),
        ),
      );
    }

    final expiresAt = _professionalData?['expires_at'];

    // ✅ FIX: detecta expiração pelo status do Firebase também,
    // cobrindo registros antigos que não têm o campo expires_at
    final statusIsExpired =
        _professionalData?['status']?.toString().toLowerCase() == 'expired';
    final isExpired =
        statusIsExpired || _expirationService.isExpired(expiresAt);

    final isNearExpiration = _expirationService.isNearExpiration(expiresAt);
    final daysLeft = _expirationService.daysUntilExpiration(expiresAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNearExpiration || isExpired
              ? const Color(0xFFEA580C).withOpacity(0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status do Perfil',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _isActive && !isExpired
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (_isActive && !isExpired
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFEA580C))
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _isActive && !isExpired
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFEA580C),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isExpired
                                ? 'Expirado'
                                : (_isActive ? 'Ativo' : 'Pausado'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isActive && !isExpired
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFEA580C),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Switch só aparece se não estiver expirado
              if (!isExpired)
                Switch(
                  value: _isActive,
                  onChanged: _isChanging ? null : (_) => _toggleStatus(),
                  activeColor: const Color(0xFF16A34A),
                  inactiveThumbColor: const Color(0xFF64748B),
                ),
            ],
          ),

          if (isNearExpiration || isExpired) ...[
            const SizedBox(height: 16),
            ExpirationWarningWidget(
              expiresAt: expiresAt,
              onRenew: !_isRenewing ? _renewProfessional : null,
            ),
          ],

          // Info de dias restantes só aparece se não estiver expirado e tiver expires_at
          if (!isExpired && expiresAt != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      daysLeft > 2
                          ? 'Válido por mais 2 dias'
                          : 'Expira em $daysLeft ${daysLeft == 1 ? "dia" : "dias"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}