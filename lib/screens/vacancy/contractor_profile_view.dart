// ============================================================
// contractor_profile_view.dart — com NotificationHistoryService integrado
// Alterações:
//   1. ✅ _approveCandidate → markAsApproved após criar chat
//   2. ✅ _rejectCandidate  → markAsRejected após remover request
//   3. ✅ _blockUser chama _rejectCandidate, portanto já fica coberto
//   4. ✅ Falha na notificação nunca bloqueia o fluxo principal
// ============================================================

import 'dart:async';
import 'package:dartobra_new/core/controllers/user_relationship_controller.dart';
import 'package:dartobra_new/features/notifications/services/notification_history_service.dart';
import 'package:dartobra_new/services/badge/badge_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
const _kBlue = Color(0xFF2563EB);
const _kBlueSoft = Color(0xFFEFF6FF);
const _kGreen = Color(0xFF16A34A);
const _kGreenSoft = Color(0xFFF0FDF4);
const _kRed = Color(0xFFDC2626);
const _kRedSoft = Color(0xFFFEF2F2);
const _kOrange = Color(0xFFEA580C);
const _kOrangeSoft = Color(0xFFFFF7ED);
const _kSurface = Color(0xFFF8FAFC);
const _kCard = Colors.white;
const _kText = Color(0xFF0F172A);
const _kTextSub = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

// ─────────────────────────────────────────────────────────────────────────────
// Helper de conversão segura
// ─────────────────────────────────────────────────────────────────────────────
Map<String, dynamic> _safeMapConvert(dynamic data) {
  if (data == null) return {};
  if (data is Map) {
    final Map<String, dynamic> result = {};
    data.forEach((key, value) {
      final stringKey = key.toString();
      if (value is Map) {
        result[stringKey] = _safeMapConvert(value);
      } else if (value is List) {
        result[stringKey] =
            value.map((e) => e is Map ? _safeMapConvert(e) : e).toList();
      } else {
        result[stringKey] = value;
      }
    });
    return result;
  }
  return {};
}

// ─────────────────────────────────────────────────────────────────────────────
// ContractorProfileView
// ─────────────────────────────────────────────────────────────────────────────
class ContractorProfileView extends StatefulWidget {
  final Map<String, dynamic> candidateData;
  final String vacancyId;
  final String myUserId;
  final VoidCallback? onApproved;
  final VoidCallback? onRejected;

  const ContractorProfileView({
    super.key,
    required this.candidateData,
    required this.vacancyId,
    required this.myUserId,
    this.onApproved,
    this.onRejected,
  });

  @override
  State<ContractorProfileView> createState() => _ContractorProfileViewState();
}

class _ContractorProfileViewState extends State<ContractorProfileView> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  // ✅ Instância do serviço de histórico de notificações
  final NotificationHistoryService _notificationHistory =
      NotificationHistoryService();

  bool _isProcessing = false;
  bool _isBlocking = false;

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — busca e marca notificação de candidatura (vacancy)
  // ─────────────────────────────────────────────────────────────────────────

  /// Localiza a notificação ativa de um candidato nesta vaga e executa [action].
  /// Nunca lança exceção — falhas são apenas logadas.
  Future<void> _updateNotification(
    String employeeUid,
    Future<bool> Function(String notificationId) action,
  ) async {
    try {
      final notifications = await _notificationHistory.getUserNotifications(
        userId: widget.myUserId,
        filterByType: NotificationType.vacancyRequest,
        includeExpired: true,
      );

      final match = notifications.where(
        (n) =>
            n.requesterId == employeeUid &&
            n.targetId == widget.vacancyId &&
            n.status != NotificationStatus.rejected &&
            n.status != NotificationStatus.approved,
      );

      if (match.isEmpty) {
        debugPrint(
            '⚠️ Nenhuma notificação pendente encontrada para $employeeUid na vaga ${widget.vacancyId}');
        return;
      }

      await action(match.first.id);
    } catch (e) {
      debugPrint('⚠️ _updateNotification falhou (não crítico): $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Verificar se usuário ainda existe
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> _checkUserStillExists(String uid) async {
    final snapshot = await _database.child('Users/$uid').get();
    return snapshot.exists;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Remover request da lista
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _removeRequest(String uid) async {
    try {
      debugPrint('🗑️ Removendo request: $uid');
      final snapshot =
          await _database.child('vacancy/${widget.vacancyId}/requests').get();

      List<String> currentRequests = [];
      if (snapshot.exists && snapshot.value != null) {
        if (snapshot.value is List) {
          currentRequests = (snapshot.value as List)
              .where((e) => e != null && e.toString().isNotEmpty)
              .map((e) => e.toString())
              .toList();
        } else if (snapshot.value is Map) {
          currentRequests = (snapshot.value as Map)
              .values
              .where((e) => e != null && e.toString().isNotEmpty)
              .map((e) => e.toString())
              .toList();
        }
      }

      currentRequests.remove(uid);

      if (currentRequests.isEmpty) {
        await _database.child('vacancy/${widget.vacancyId}/requests').remove();
      } else {
        await _database
            .child('vacancy/${widget.vacancyId}/requests')
            .set(currentRequests);
      }
    } catch (e, stack) {
      debugPrint('❌ Erro ao remover request: $e\n$stack');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECUSAR CANDIDATO
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _rejectCandidate() async {
    final employeeUid = widget.candidateData['uid'] as String? ?? '';
    if (employeeUid.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      debugPrint('❌ Recusando candidato: $employeeUid');

      final requestViewSnap = await _database
          .child('vacancy/${widget.vacancyId}/views/request_views/$employeeUid')
          .get();

      bool wasUnviewed = false;
      if (requestViewSnap.exists && requestViewSnap.value != null) {
        final viewData = _safeMapConvert(requestViewSnap.value);
        wasUnviewed = viewData['viewed_by_owner'] == false;
      }

      await _removeRequest(employeeUid);
      await _database
          .child('vacancy/${widget.vacancyId}/views/request_views/$employeeUid')
          .remove();

      if (wasUnviewed) {
        debugPrint('🔽 Decrementando badge do owner: ${widget.myUserId}');
        await BadgeHelper.decrementRequestBadge(widget.myUserId);
      } else {
        debugPrint('ℹ️ Candidato já visualizado, badge não alterado');
      }

      // ✅ Marca notificação como recusada (não bloqueia o fluxo se falhar)
      await _updateNotification(employeeUid, (notificationId) async {
        return await _notificationHistory.markAsRejected(
          ownerId: widget.myUserId,
          notificationId: notificationId,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.block_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Candidato recusado'),
          ]),
          backgroundColor: _kOrange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));

        widget.onRejected?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Erro ao recusar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao recusar candidato: $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APROVAR CANDIDATO (criar chat)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _approveCandidate() async {
    final employeeUid = widget.candidateData['uid'] as String? ?? '';
    if (employeeUid.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final exists = await _checkUserStillExists(employeeUid);

      if (!exists) {
        await _removeRequest(employeeUid);
        await _database
            .child(
                'vacancy/${widget.vacancyId}/views/request_views/$employeeUid')
            .remove();

        debugPrint(
            '⚠️ Usuário $employeeUid não existe mais, removido silenciosamente');

        if (mounted) {
          setState(() => _isProcessing = false);
          _showUserNotFoundDialog();
        }
        return;
      }

      // Verificar se já existe chat (query indexada em vez de full scan)
      final chatsSnapshot = await _database
          .child('Chats')
          .orderByChild('contractor')
          .equalTo(widget.myUserId)
          .get();

      bool chatExists = false;
      if (chatsSnapshot.exists && chatsSnapshot.value != null) {
        final chatsData = _safeMapConvert(chatsSnapshot.value);
        for (final chatEntry in chatsData.entries) {
          final chatData = chatEntry.value is Map
              ? _safeMapConvert(chatEntry.value)
              : <String, dynamic>{};
          if (chatData['employee']?.toString() == employeeUid) {
            chatExists = true;
            break;
          }
        }
      }

      if (!chatExists) {
        // Verifica também como employee (caso invertido)
        final reverseSnapshot = await _database
            .child('Chats')
            .orderByChild('employee')
            .equalTo(widget.myUserId)
            .get();

        if (reverseSnapshot.exists && reverseSnapshot.value != null) {
          final reverseData = _safeMapConvert(reverseSnapshot.value);
          for (final chatEntry in reverseData.entries) {
            final chatData = chatEntry.value is Map
                ? _safeMapConvert(chatEntry.value)
                : <String, dynamic>{};
            if (chatData['contractor']?.toString() == employeeUid) {
              chatExists = true;
              break;
            }
          }
        }
      }

      if (chatExists) {
          await _rejectCandidate();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Row(children: [
                Icon(Icons.info_outline, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'Candidato recusado: já existe chat com este usuário',
                        style: TextStyle(fontSize: 13))),
              ]),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 4),
            ));
          }
          return;
        }
      }

      // Criar novo chat
      final DatabaseReference chatRef = _database.child('Chats').push();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await chatRef.set({
        'contractor': widget.myUserId,
        'employee': employeeUid,
        'participants': {'contractor': 'offline', 'employee': 'offline'},
        'metadata': {
          'created_at': timestamp,
          'last_message': '',
          'last_sender': '',
          'last_timestamp': timestamp,
        },
        'historical_messages': {
          'messages': {'init': true}
        },
        'unreadCount': {'contractor': 0, 'employee': 0},
      });

      final requestViewSnap = await _database
          .child('vacancy/${widget.vacancyId}/views/request_views/$employeeUid')
          .get();

      bool wasUnviewed = false;
      if (requestViewSnap.exists && requestViewSnap.value != null) {
        final viewData = _safeMapConvert(requestViewSnap.value);
        wasUnviewed = viewData['viewed_by_owner'] == false;

        await _database
            .child(
                'vacancy/${widget.vacancyId}/views/request_views/$employeeUid')
            .remove();

        await _removeRequest(employeeUid);

        if (wasUnviewed) {
          debugPrint('🔽 Decrementando badge do owner: ${widget.myUserId}');
          await BadgeHelper.decrementRequestBadge(widget.myUserId);
        } else {
          debugPrint('ℹ️ Candidato já visualizado, badge não alterado');
        }

        // ✅ Marca notificação como aprovada (não bloqueia o fluxo se falhar)
        await _updateNotification(employeeUid, (notificationId) async {
          return await _notificationHistory.markAsApproved(
            ownerId: widget.myUserId,
            notificationId: notificationId,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Chat iniciado com sucesso!'),
            ]),
            backgroundColor: _kGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));

          widget.onApproved?.call();
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao aprovar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.error_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Erro ao processar candidato'),
          ]),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BLOQUEAR USUÁRIO
  // _rejectCandidate já cuida da remoção e da notificação, então
  // _blockUser apenas bloqueia e delega a rejeição para ele.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _blockUser() async {
    final employeeUid = widget.candidateData['uid'] as String? ?? '';
    if (employeeUid.isEmpty) return;

    setState(() => _isBlocking = true);

    try {
      final success = await UserRelationShipController()
          .blockUser(widget.myUserId, employeeUid);

      if (!mounted) return;

      if (success) {
        // _rejectCandidate já marca a notificação como rejeitada
        await _rejectCandidate();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.block_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Usuário bloqueado e removido da lista'),
          ]),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Usuário já estava bloqueado'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao bloquear: $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _isBlocking = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dialogs
  // ─────────────────────────────────────────────────────────────────────────
  void _showUserNotFoundDialog() {
    final userName =
        widget.candidateData['name'] as String? ?? 'este usuário';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF64748B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_off_rounded,
                color: Color(0xFF64748B), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Usuário indisponível',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Não foi possível iniciar o chat com $userName.',
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF0F172A), height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este usuário pode ter encerrado sua conta ou está temporariamente indisponível.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Entendido',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmDialog() {
    final name = widget.candidateData['name'] as String? ?? 'este usuário';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: _kRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block_rounded, size: 34, color: _kRed),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bloquear usuário',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _kText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tem certeza que deseja bloquear $name?\n\n'
                'A solicitação será removida e nenhum de vocês '
                'poderá se candidatar aos perfis ou vagas um do outro.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: _kBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                          color: _kTextSub,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isBlocking
                        ? null
                        : () {
                            Navigator.of(ctx).pop();
                            _blockUser();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isBlocking
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Bloquear',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final workerData =
        widget.candidateData['data_worker'] as Map<String, dynamic>? ?? {};
    final String avatar = widget.candidateData['avatar'] as String? ?? '';
    final String name =
        widget.candidateData['name'] as String? ?? 'Nome não informado';
    final String city = widget.candidateData['city'] as String? ?? '';
    final String state = widget.candidateData['state'] as String? ?? '';
    final String email = widget.candidateData['email'] as String? ?? '';
    final String phone = widget.candidateData['phone'] as String? ?? '';
    final String legalType =
        widget.candidateData['legalType'] as String? ?? '';
    final int? age = widget.candidateData['age'] as int?;

    final String profession = workerData['profession'] as String? ?? '';
    final String summary = workerData['summary'] as String? ?? '';
    final List<dynamic> skills = workerData['skills'] as List? ?? [];

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: _kText),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detalhes do Candidato',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: _kText),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder)),
              child: const Icon(Icons.more_vert_rounded,
                  size: 18, color: _kText),
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 4,
            offset: const Offset(0, 44),
            onSelected: (value) {
              if (value == 'block') _showBlockConfirmDialog();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'block',
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _kRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.block_rounded,
                        size: 16, color: _kRed),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Bloquear usuário',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kRed),
                  ),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            backgroundColor: _kBlueSoft,
            child: avatar.isEmpty
                ? const Icon(Icons.person_rounded, size: 50, color: _kBlue)
                : null,
          ),
          const SizedBox(height: 16),
          Text(name,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _kText),
              textAlign: TextAlign.center),
          if (profession.isNotEmpty && profession != 'Não definida') ...[
            const SizedBox(height: 4),
            Text(profession,
                style: const TextStyle(fontSize: 14, color: _kTextSub)),
          ],
          const SizedBox(height: 24),
          _DetailSection(
            title: 'Informações de Contato',
            children: [
              if (email.isNotEmpty)
                _InfoRow(
                    icon: Icons.email_outlined, label: 'E-mail', value: email),
              if (phone.isNotEmpty && phone != 'Não definido')
                _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Telefone',
                    value: phone),
              _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Localização',
                  value: '$city, $state'),
              if (age != null)
                _InfoRow(
                    icon: Icons.cake_outlined,
                    label: 'Idade',
                    value: '$age anos'),
            ],
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Informações Profissionais',
            children: [
              if (profession.isNotEmpty && profession != 'Não definida')
                _InfoRow(
                    icon: Icons.work_outline_rounded,
                    label: 'Profissão',
                    value: profession),
              _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Tipo',
                  value: legalType == 'PJ'
                      ? 'Pessoa Jurídica'
                      : 'Pessoa Física'),
              if (summary.isNotEmpty && summary != 'Não definido') ...[
                const SizedBox(height: 4),
                const Divider(color: _kBorder),
                const SizedBox(height: 10),
                const Text('Resumo Profissional',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTextSub)),
                const SizedBox(height: 6),
                Text(summary,
                    style: const TextStyle(
                        fontSize: 14, color: _kText, height: 1.55),
                    textAlign: TextAlign.justify),
              ],
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: _kBorder),
                const SizedBox(height: 12),
                const Text('Habilidades',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTextSub)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: skills.map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kBlueSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBlue.withOpacity(0.3)),
                      ),
                      child: Text(skill.toString(),
                          style: const TextStyle(
                              fontSize: 12,
                              color: _kBlue,
                              fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: _kCard,
          border: Border(top: BorderSide(color: _kBorder)),
        ),
        child: SafeArea(
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing ? null : _rejectCandidate,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(color: _kRed.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_kRed),
                        ),
                      )
                    : const Text('Recusar',
                        style: TextStyle(
                            color: _kRed,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _approveCandidate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Aceitar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Componentes auxiliares
// ─────────────────────────────────────────────────────────────────────────────
class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: _kText)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder)),
            child: Icon(icon, size: 17, color: _kTextSub),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: _kTextSub)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}