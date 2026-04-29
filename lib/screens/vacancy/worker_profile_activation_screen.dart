// ============================================================
// PATCH — worker_profile_activation.dart  (_RequestsTab)
// Alterações aplicadas:
//   1. _RequestsTabState passa a escutar
//      professionals/{myProfileKey}/views/request_views via onValue,
//      então os cards somem em tempo real quando um candidato é
//      removido (inclusive por exclusão de conta).
//   2. DeletedUserDetector já estava presente — mantido e integrado.
//   3. dispose() cancela o subscription corretamente.
// ============================================================

import 'dart:async';
import 'dart:ui';

import 'package:dartobra_new/services/badge/badge_service.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';
import 'package:dartobra_new/services/notifications/notification_navigation_service.dart';
import 'package:dartobra_new/services/notifications/notification_service.dart';
import 'package:dartobra_new/widgets/professional_control.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

const _kBlue = Color(0xFF2563EB);
const _kBlueSoft = Color(0xFFEFF6FF);
const _kBlueMid = Color(0xFFBFDBFE);
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

const int _kSummaryMinLength = 40;

// ─────────────────────────────────────────────────────────────────────────────
// Mixin — detecta usuários deletados em tempo real
// ─────────────────────────────────────────────────────────────────────────────
mixin DeletedUserDetector<T extends StatefulWidget> on State<T> {
  StreamSubscription? _deletedUsersSubscription;
  final Set<String> _deletedUsers = {};

  void initDeletedUserDetector() {
    _deletedUsersSubscription = FirebaseDatabase.instance
        .ref('deleted_users')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final data =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        if (mounted) {
          setState(() {
            _deletedUsers.clear();
            _deletedUsers.addAll(data.keys);
          });
        }
      } else {
        if (mounted) setState(() => _deletedUsers.clear());
      }
    });
  }

  bool isUserDeleted(String uid) => _deletedUsers.contains(uid);

  void disposeDeletedUserDetector() {
    _deletedUsersSubscription?.cancel();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WorkerProfileActivation — sem alterações funcionais nesta parte
// ─────────────────────────────────────────────────────────────────────────────
class WorkerProfileActivation extends StatefulWidget {
  final String userName;
  final String userAvatar;
  final String userCity;
  final String userState;
  final String legalType;
  final Map<String, dynamic> dataWorker;
  final bool isActive;
  final String localId;
  final onActivated;
  final bool finished_basic;
  final String userTelefone;
  final String userEmail;
  final bool finished_contact;
  final bool finished_professional;
  final VoidCallback onProfileIncomplete;

  const WorkerProfileActivation({
    super.key,
    required this.userName,
    required this.userAvatar,
    required this.userCity,
    required this.userEmail,
    required this.userTelefone,
    required this.userState,
    required this.legalType,
    required this.onActivated,
    required this.dataWorker,
    required this.isActive,
    required this.localId,
    required this.finished_basic,
    required this.finished_contact,
    required this.finished_professional,
    required this.onProfileIncomplete,
    required int initialTabIndex,
  });

  @override
  State<WorkerProfileActivation> createState() =>
      _WorkerProfileActivationState();
}

class _WorkerProfileActivationState extends State<WorkerProfileActivation>
    with DeletedUserDetector {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isActivating = false;
  late bool _currentIsActive;
  String? _professionalId;

  bool _hasProfile = false;
  final ExpirationService _expirationService = ExpirationService();
  bool _isCheckingProfile = true;

  @override
  void initState() {
    super.initState();
    _currentIsActive = widget.isActive;
    initDeletedUserDetector();
    _checkExistingProfile();
    _setupNotificationHandlers();
  }

  @override
  void dispose() {
    disposeDeletedUserDetector();
    super.dispose();
  }
  //────────────────────────────────────────────────────────────────────────────
  // Configurando routes das notificações para work profile
  //────────────────────────────────────────────────────────────────────────────
  void _setupNotificationHandlers() {
    final service = NotificationService();

    service.updateCallbacks(
      onChatTap: (chatId, senderId) async {
        service.dismissChatNotifications(chatId);

        if (!mounted) return;

        await NotificationNavigationService().navigateToChat(
          context: context,
          chatId: chatId,
          userId: widget.localId,
          userRole: 'employee', // Worker sempre é employee
        );
      },
      onRequestTap: (requestType, profileId, vacancyId) async {
        if (!mounted) return;

        await NotificationNavigationService().navigateToRequest(
          context: context,
          userId: widget.localId,
          userRole: 'employee', // Worker sempre é employee
          requestType: requestType ?? '',
          profileId: profileId,
          vacancyId: vacancyId,
        );
      },
    );

    debugPrint('✅ [WorkerProfileActivation] Callbacks configurados');
  }
  Future<void> _checkExistingProfile() async {
    try {
      final snapshot = await _database
          .child('professionals')
          .orderByChild('local_id')
          .equalTo(widget.localId)
          .once();

      if (snapshot.snapshot.value == null) {
        if (mounted) {
          setState(() {
            _hasProfile = false;
            _isCheckingProfile = false;
          });
        }
        return;
      }

      final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      String? activeKey;
      String? fallbackKey;
      data.forEach((key, value) {
        final status =
            (value as Map?)?['status']?.toString().toLowerCase() ?? '';
        fallbackKey ??= key.toString();
        if (status == 'active') activeKey = key.toString();
      });

      final resolvedKey = activeKey ?? fallbackKey!;
      final profData =
          Map<String, dynamic>.from(data[resolvedKey] as Map);
      final status =
          profData['status']?.toString().toLowerCase() ?? '';

      if (mounted) {
        setState(() {
          _professionalId = resolvedKey;
          _hasProfile = true;
          _currentIsActive = status == 'active';
          _isCheckingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao verificar perfil existente: $e');
      if (mounted) setState(() => _isCheckingProfile = false);
    }
  }

  bool _isProfileComplete() {
    if (!widget.finished_basic ||
        !widget.finished_contact ||
        !widget.finished_professional) return false;
    final summary =
        widget.dataWorker['summary']?.toString().trim() ?? '';
    if (summary.length < _kSummaryMinLength) return false;
    final skills = widget.dataWorker['skills'];
    if (skills == null || (skills as List).isEmpty) return false;
    return true;
  }

  void _handleProfileIncomplete() {
    final summary =
        widget.dataWorker['summary']?.toString().trim() ?? '';
    final skills = widget.dataWorker['skills'];
    final hasSkills = skills != null && (skills as List).isNotEmpty;

    String message;
    if (!widget.finished_basic ||
        !widget.finished_contact ||
        !widget.finished_professional) {
      message =
          'Complete todas as seções do seu perfil antes de ativar.';
    } else if (summary.length < _kSummaryMinLength) {
      message =
          'Sua descrição profissional está muito curta (${summary.length}/$_kSummaryMinLength caracteres). '
          'Acesse "Editar Perfil" → seção Profissional e preencha com pelo menos $_kSummaryMinLength caracteres.';
    } else if (!hasSkills) {
      message =
          'Adicione pelo menos uma habilidade no seu perfil profissional antes de ativar.';
    } else {
      message = 'Complete seu perfil antes de ativar.';
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: _kOrange,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));

    widget.onProfileIncomplete();
  }

  Future<void> _activateProfile() async {
    if (!_isProfileComplete()) {
      _handleProfileIncomplete();
      return;
    }
    setState(() => _isActivating = true);
    try {
      await _database
          .child('Users/${widget.localId}/isActive')
          .set(true);
      await _database
          .child('Users/${widget.localId}/data_worker/activated')
          .set(true);

      if (!_hasProfile) {
        await _createWorkerAd();
      } else if (_professionalId != null) {
        await _database
            .child('professionals/$_professionalId/status')
            .set('active');
        await _database
            .child('professionals/$_professionalId/updated_at')
            .set(DateTime.now().toIso8601String());
      }

      await _checkExistingProfile();
      setState(() => _isActivating = false);
      if (mounted) {
        _showSuccessSnack('Perfil profissional ativado com sucesso!');
        widget.onActivated();
      }
    } catch (e) {
      setState(() => _isActivating = false);
      if (mounted) _showErrorSnack('Erro ao ativar perfil: $e');
    }
  }

  Future<void> _createWorkerAd() async {
    final profession =
        widget.dataWorker['profession'] ?? 'Profissional';
    final summary = widget.dataWorker['summary'] ?? '';
    final skills = widget.dataWorker['skills'] ?? [];
    final company = widget.dataWorker['company'] ?? '';

    final adData = {
      'local_id': widget.localId,
      'name': widget.userName,
      'avatar': widget.userAvatar,
      'profession': profession,
      'city': widget.userCity,
      'state': widget.userState,
      'legal_type': widget.legalType,
      'company': company,
      'summary': summary,
      'skills': skills,
      'telefone': widget.userTelefone,
      'email': widget.userEmail,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'status': 'active',
      'type': 'worker',
      'expires_at': _expirationService.getExpirationDateISO(),
      'expiration_timestamp': _expirationService.getExpirationTimestamp(),
      'views': {
        'total_views': 0,
        'unique_viewers': [],
        'last_viewed_at': null
      },
    };

    final newAdRef = _database.child('professionals').push();
    await newAdRef.set(adData);
  }

  void _showActivationConfirmation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ConfirmationScreen(
          userName: widget.userName,
          userAvatar: widget.userAvatar,
          userCity: widget.userCity,
          userState: widget.userState,
          userEmail: widget.userEmail,
          userTelefone: widget.userTelefone,
          legalType: widget.legalType,
          dataWorker: widget.dataWorker,
          onConfirm: () {
            Navigator.pop(context);
            _activateProfile();
          },
        ),
      ),
    );
  }

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('$msg Válido por 2 dias.')),
      ]),
      backgroundColor: _kGreen,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: _kRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: _isCheckingProfile
            ? const Center(
                child: CircularProgressIndicator(
                    color: _kBlue, strokeWidth: 2.5))
            : _hasProfile
                ? _ActiveProfileTabs(
                    userName: widget.userName,
                    userAvatar: widget.userAvatar,
                    userCity: widget.userCity,
                    userState: widget.userState,
                    legalType: widget.legalType,
                    dataWorker: widget.dataWorker,
                    localId: widget.localId,
                    onProfileIncomplete: widget.onProfileIncomplete,
                    finished_basic: widget.finished_basic,
                    finished_contact: widget.finished_contact,
                    finished_professional: widget.finished_professional,
                    userTelefone: widget.userTelefone,
                    userEmail: widget.userEmail,
                  )
                : _InactiveView(
                    isActivating: _isActivating,
                    onActivate: _showActivationConfirmation,
                    dataWorker: widget.dataWorker,
                    isProfileComplete: _isProfileComplete(),
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vista Inativa — sem alterações
// ─────────────────────────────────────────────────────────────────────────────
class _InactiveView extends StatelessWidget {
  final bool isActivating;
  final VoidCallback onActivate;
  final Map<String, dynamic> dataWorker;
  final bool isProfileComplete;

  const _InactiveView({
    required this.isActivating,
    required this.onActivate,
    required this.dataWorker,
    required this.isProfileComplete,
  });

  @override
  Widget build(BuildContext context) {
    final summary = dataWorker['summary']?.toString().trim() ?? '';
    final skills = dataWorker['skills'];
    final hasSkills = skills != null && (skills as List).isNotEmpty;
    final summaryOk = summary.length >= _kSummaryMinLength;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), _kBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _kBlue.withOpacity(0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(Icons.work_outline_rounded,
                size: 48, color: Colors.white),
          ),
          const SizedBox(height: 28),
          const Text(
            'Perfil Profissional',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _kText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ative seu perfil e comece a receber\noportunidades de trabalho.',
            style: const TextStyle(
                fontSize: 15, color: _kTextSub, height: 1.55),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kBlueSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBlue.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.schedule_rounded,
                    color: _kBlue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Duração: 2 dias',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _kBlue)),
                    const SizedBox(height: 4),
                    Text(
                      'Você poderá renovar quando estiver próximo do vencimento para continuar visível',
                      style: TextStyle(
                          fontSize: 12,
                          color: _kBlue.withOpacity(0.8),
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          if (!isProfileComplete) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kOrangeSoft,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: _kOrange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.checklist_rounded,
                        color: _kOrange, size: 18),
                    SizedBox(width: 8),
                    Text('Requisitos para ativar',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _kOrange)),
                  ]),
                  const SizedBox(height: 12),
                  _RequirementItem(
                      label: 'Perfil básico preenchido', ok: true),
                  _RequirementItem(
                      label: 'Habilidades adicionadas',
                      ok: hasSkills),
                  _RequirementItem(
                    label:
                        'Descrição profissional (${summary.length}/$_kSummaryMinLength caracteres)',
                    ok: summaryOk,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          _FeatureCard(
            icon: Icons.campaign_outlined,
            iconColor: _kBlue,
            iconBg: _kBlueSoft,
            title: 'Anúncio Automático',
            description:
                'Criamos um anúncio baseado no seu perfil completo',
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.visibility_outlined,
            iconColor: _kGreen,
            iconBg: _kGreenSoft,
            title: 'Visibilidade',
            description:
                'Seu perfil fica disponível no banco de profissionais',
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.connect_without_contact_outlined,
            iconColor: _kOrange,
            iconBg: _kOrangeSoft,
            title: 'Oportunidades',
            description:
                'Empresas podem te encontrar e enviar propostas',
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isActivating ? null : onActivate,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isProfileComplete ? _kBlue : _kOrange,
                disabledBackgroundColor: _kBorder,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: isActivating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white)),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isProfileComplete
                              ? Icons.rocket_launch_rounded
                              : Icons.edit_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isProfileComplete
                              ? 'Ativar Perfil Profissional'
                              : 'Complete o Perfil para Ativar',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final String label;
  final bool ok;
  const _RequirementItem({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 16,
          color: ok ? _kGreen : _kRed,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: ok ? _kText : _kRed,
                  fontWeight:
                      ok ? FontWeight.normal : FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kText)),
              const SizedBox(height: 3),
              Text(description,
                  style: const TextStyle(
                      fontSize: 13, color: _kTextSub)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabs do perfil ativo
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveProfileTabs extends StatefulWidget {
  final String userName;
  final String userAvatar;
  final String userCity;
  final String userState;
  final String legalType;
  final Map<String, dynamic> dataWorker;
  final String localId;
  final VoidCallback onProfileIncomplete;
  final bool finished_basic;
  final bool finished_contact;
  final bool finished_professional;
  final String userTelefone;
  final String userEmail;

  const _ActiveProfileTabs({
    required this.userName,
    required this.userAvatar,
    required this.userCity,
    required this.userState,
    required this.legalType,
    required this.dataWorker,
    required this.localId,
    required this.onProfileIncomplete,
    required this.finished_basic,
    required this.finished_contact,
    required this.finished_professional,
    required this.userTelefone,
    required this.userEmail,
  });

  @override
  State<_ActiveProfileTabs> createState() => _ActiveProfileTabsState();
}

class _ActiveProfileTabsState extends State<_ActiveProfileTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: _kCard,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(children: [
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), _kBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: _kBlue.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: const Icon(Icons.work_outline_rounded,
                  size: 28, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Perfil Profissional',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _kText,
                          letterSpacing: -0.3)),
                  SizedBox(height: 4),
                  _ActiveBadge(),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            labelColor: _kBlue,
            unselectedLabelColor: _kTextSub,
            indicatorColor: _kBlue,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1),
            unselectedLabelStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Solicitações'),
              Tab(text: 'Atualizar Perfil'),
            ],
          ),
        ]),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            _RequestsTab(localId: widget.localId),
            _UpdateProfileTab(
              userName: widget.userName,
              userAvatar: widget.userAvatar,
              userCity: widget.userCity,
              userState: widget.userState,
              legalType: widget.legalType,
              dataWorker: widget.dataWorker,
              localId: widget.localId,
              onProfileIncomplete: widget.onProfileIncomplete,
              finished_basic: widget.finished_basic,
              finished_contact: widget.finished_contact,
              finished_professional: widget.finished_professional,
              userTelefone: widget.userTelefone,
              userEmail: widget.userEmail,
            ),
          ],
        ),
      ),
    ]);
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kGreenSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGreen.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: _kGreen, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Text('Ativo',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kGreen,
                letterSpacing: 0.2)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab de Solicitações — COM STREAM EM TEMPO REAL
// ─────────────────────────────────────────────────────────────────────────────
class _RequestsTab extends StatefulWidget {
  final String localId;
  const _RequestsTab({required this.localId});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab>
    with DeletedUserDetector {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isLoadingRequests = false;
  bool _isCreatingChat = false;

  List<Map<String, dynamic>> _workRequests = [];
  String? _myProfileKey;

  // Stream que escuta o nó do perfil profissional em tempo real
  StreamSubscription? _profileSubscription;

  @override
  void initState() {
    super.initState();
    initDeletedUserDetector();
    _findProfileKeyAndSubscribe();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    disposeDeletedUserDetector();
    super.dispose();
  }

  // ── Encontra a chave do perfil e assina o stream ──────────────────────────

  Future<void> _findProfileKeyAndSubscribe() async {
    setState(() => _isLoadingRequests = true);

    try {
      final snapshot = await _database
          .child('professionals')
          .orderByChild('local_id')
          .equalTo(widget.localId)
          .once();

      if (snapshot.snapshot.value == null) {
        if (mounted) setState(() => _isLoadingRequests = false);
        return;
      }

      final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      _myProfileKey = data.keys.first.toString();

      // Cancela subscription anterior se existir
      await _profileSubscription?.cancel();

      // Assina o nó do perfil inteiro para capturar mudanças em requests
      _profileSubscription = _database
          .child('professionals/$_myProfileKey')
          .onValue
          .listen(_onProfileSnapshot, onError: (e) {
        debugPrint('❌ Erro no stream do perfil: $e');
        if (mounted) setState(() => _isLoadingRequests = false);
      });
    } catch (e) {
      debugPrint('Erro ao buscar perfil: $e');
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  // ── Callback do stream ────────────────────────────────────────────────────

  Future<void> _onProfileSnapshot(DatabaseEvent event) async {
    if (!event.snapshot.exists || event.snapshot.value == null) {
      if (mounted) setState(() {
        _workRequests = [];
        _isLoadingRequests = false;
      });
      return;
    }

    final profileData =
        Map<String, dynamic>.from(event.snapshot.value as Map);

    // Normaliza requests (Map ou List → List<String>)
    List<String> requestLocalIds = [];
    final rawRequests = profileData['requests'];
    if (rawRequests is List) {
      requestLocalIds = rawRequests
          .where((e) => e != null && e.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList();
    } else if (rawRequests is Map) {
      requestLocalIds = rawRequests.values
          .where((e) => e != null && e.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList();
    }

    // Views
    Map<String, dynamic> viewsData = {};
    if (profileData['views'] != null &&
        profileData['views']['request_views'] != null) {
      viewsData = Map<String, dynamic>.from(
          profileData['views']['request_views'] as Map);
    }

    if (requestLocalIds.isEmpty) {
      if (mounted) setState(() {
        _workRequests = [];
        _isLoadingRequests = false;
      });
      return;
    }

    // Carrega dados dos usuários ainda presentes na lista
    final List<Map<String, dynamic>> requests = [];
    for (final localId in requestLocalIds) {
      if (isUserDeleted(localId)) continue;

      try {
        final userSnapshot =
            await _database.child('Users/$localId').once();

        if (userSnapshot.snapshot.value != null) {
          final userData = Map<String, dynamic>.from(
              userSnapshot.snapshot.value as Map);
          Map<String, dynamic> contractorData = {};
          if (userData['data_contractor'] != null) {
            contractorData = Map<String, dynamic>.from(
                userData['data_contractor'] as Map);
          }
          bool viewedByOwner = false;
          if (viewsData.containsKey(localId)) {
            viewedByOwner =
                viewsData[localId]['viewed_by_owner'] ?? false;
          }
          requests.add({
            'local_id': localId,
            'name': userData['Name'] ?? 'Nome não informado',
            'avatar': userData['avatar'] ?? '',
            'city': userData['city'] ?? '',
            'state': userData['state'] ?? '',
            'email': userData['email'] ?? '',
            'telefone': userData['telefone'] ?? '',
            'email_contact': userData['email_contact'] ?? '',
            'age': userData['age'],
            'legalType': userData['legalType'] ?? 'PF',
            'data_contractor': contractorData,
            'viewed_by_owner': viewedByOwner,
          });
        }
      } catch (e) {
        debugPrint('Erro ao buscar usuário $localId: $e');
      }
    }

    // Ordena: não lidos primeiro
    requests.sort((a, b) {
      if (a['viewed_by_owner'] == b['viewed_by_owner']) return 0;
      return a['viewed_by_owner'] ? 1 : -1;
    });

    if (mounted) {
      setState(() {
        _workRequests = requests;
        _isLoadingRequests = false;
      });
    }
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  Future<void> _refreshRequests() async =>
      await _findProfileKeyAndSubscribe();

  Future<void> _removeRequestFromList(String requestLocalId) async {
    if (_myProfileKey == null) return;
    final snapshot = await _database
        .child('professionals/$_myProfileKey/requests')
        .once();
    if (snapshot.snapshot.value != null) {
      List<dynamic> currentRequests;
      if (snapshot.snapshot.value is List) {
        currentRequests =
            List<dynamic>.from(snapshot.snapshot.value as List);
      } else if (snapshot.snapshot.value is Map) {
        currentRequests =
            (snapshot.snapshot.value as Map).values.toList();
      } else {
        currentRequests = [];
      }
      currentRequests.remove(requestLocalId);

      if (currentRequests.isEmpty) {
        await _database
            .child('professionals/$_myProfileKey/requests')
            .remove();
      } else {
        await _database
            .child('professionals/$_myProfileKey/requests')
            .set(currentRequests);
      }

      await _database
          .child(
              'professionals/$_myProfileKey/views/request_views/$requestLocalId')
          .remove();
      await BadgeHelper.decrementRequestBadge(widget.localId);

      // O stream onValue dispara e atualiza _workRequests automaticamente
    }
  }

    Future<void> decrementRequestBadge(String userId) async {
  try {
    final badgeRef = _database.child('badges/$userId/unread_requests');
    final snap = await badgeRef.once();
    
    int current = 0;
    if (snap.snapshot.exists && snap.snapshot.value != null) {
      current = (snap.snapshot.value as num).toInt();
    }
    
    final newValue = (current - 1).clamp(0, 9999);
    debugPrint('🔔 Badge: $current → $newValue');
    
    await badgeRef.set(newValue);
    debugPrint('✅ Badge decrementado com sucesso');
  } catch (e) {
    debugPrint('❌ Erro ao decrementar badge: $e');
  }
}
  Future<void> _rejectRequest(String requestLocalId) async {
  if (_myProfileKey == null) return;
  try {
    // ✅ 1. Buscar estado atual antes de remover
    final requestViewSnap = await _database
        .child('professionals/$_myProfileKey/views/request_views/$requestLocalId')
        .once();
    
    bool wasUnviewed = false;
    if (requestViewSnap.snapshot.exists && requestViewSnap.snapshot.value != null) {
      final viewData = Map<String, dynamic>.from(requestViewSnap.snapshot.value as Map);
      wasUnviewed = viewData['viewed_by_owner'] == false;
    }

    // ✅ 2. Remover da lista de requests
    await _removeRequestFromList(requestLocalId);
    
    // ✅ 3. Decrementar badge SOMENTE se não foi visualizado
    if (wasUnviewed) {
      debugPrint('🔽 Decrementando badge do owner: ${widget.localId}');
      await decrementRequestBadge(widget.localId);
    } else {
      debugPrint('ℹ️ Candidato já visualizado, badge não alterado');
    }



    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.block_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Solicitação recusada'),
        ]),
        backgroundColor: _kOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  } catch (e) {
    debugPrint('❌ Erro ao recusar solicitação: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao recusar solicitação: $e'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }
}

  Future<bool> _checkUserStillExists(String uid) async {
    final snapshot = await _database.child('Users/$uid').get();
    return snapshot.exists;
  }

  void _showUserNotFoundDialog({required String userName}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
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
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Não foi possível iniciar o chat com $userName.',
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                  height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFE2E8F0)),
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
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Entendido',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createChat(Map<String, dynamic> requestData) async {
    if (_isCreatingChat) return;
    setState(() => _isCreatingChat = true);

    try {
      final uid = requestData['local_id'] as String;
      final exists = await _checkUserStillExists(uid);

      if (!exists) {
        if (mounted) {
          setState(() => _isCreatingChat = false);
          _showUserNotFoundDialog(
              userName: requestData['name'] ?? 'este usuário');
        }
        return;
      }

      final DatabaseReference chatRef = _database.child('Chats').push();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await chatRef.set({
        'contractor': uid,
        'employee': widget.localId,
        'participants': {
          'contractor': 'offline',
          'employee': 'offline'
        },
        'metadata': {
          'created_at': timestamp,
          'last_message': '',
          'last_sender': '',
          'last_timestamp': timestamp,
        },
        'historical_messages': {
          'messages': {'init': true},
        },
        'messages_offline': {'contractor': {}, 'employee': {}},
      });

      await _removeRequestFromList(uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Solicitação aceita! Chat iniciado.'),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Erro ao aceitar solicitação'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _isCreatingChat = false);
    }
  }

  void _showRequestDetails(Map<String, dynamic> requestData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RequestDetailsScreen(
          requestData: requestData,
          onAccept: () {
            Navigator.pop(context);
            _createChat(requestData);
          },
          onReject: () {
            Navigator.pop(context);
            _rejectRequest(requestData['local_id']);
          },
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Filtra em tempo real: exclui cards de usuários deletados
    final visibleRequests = _workRequests
        .where((r) => !isUserDeleted(r['local_id'] ?? ''))
        .toList();

    return RefreshIndicator(
      color: _kBlue,
      onRefresh: _refreshRequests,
      child: _isLoadingRequests
          ? const Center(
              child: CircularProgressIndicator(
                  color: _kBlue, strokeWidth: 2.5))
          : visibleRequests.isEmpty
              ? _EmptyRequests()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  itemCount: visibleRequests.length,
                  itemBuilder: (context, index) => _RequestCard(
                    request: visibleRequests[index],
                    isCreatingChat: _isCreatingChat,
                    onTap: () =>
                        _showRequestDetails(visibleRequests[index]),
                    onAccept: () => _createChat(visibleRequests[index]),
                    onReject: () => _rejectRequest(
                        visibleRequests[index]['local_id']),
                  ),
                ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    color: _kBlueSoft,
                    borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.inbox_outlined,
                    size: 40, color: _kBlue),
              ),
              const SizedBox(height: 20),
              const Text('Nenhuma solicitação',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kText)),
              const SizedBox(height: 8),
              const Text(
                'Empresas poderão te encontrar\ne enviar solicitações por aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: _kTextSub, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isCreatingChat;

  const _RequestCard({
    required this.request,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
    required this.isCreatingChat,
  });

  @override
  Widget build(BuildContext context) {
    final contractorData =
        request['data_contractor'] as Map<String, dynamic>? ?? {};
    final bool isNew = !(request['viewed_by_owner'] ?? false);
    final String avatar = request['avatar']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNew ? _kBlue.withOpacity(0.4) : _kBorder,
          width: isNew ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isNew
                ? _kBlue.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: isNew ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNew) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: _kBlue,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_new_rounded,
                            color: Colors.white, size: 15),
                        SizedBox(width: 5),
                        Text('NOVA SOLICITAÇÃO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: avatar.isNotEmpty
                        ? NetworkImage(avatar)
                        : null,
                    backgroundColor: _kBlueSoft,
                    child: avatar.isEmpty
                        ? const Icon(Icons.business_rounded,
                            color: _kBlue, size: 26)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['name'] ?? 'Nome não informado',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: isNew
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _kText),
                        ),
                        if (contractorData['company']
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(contractorData['company'],
                                style: const TextStyle(
                                    fontSize: 13, color: _kTextSub)),
                          ),
                        const SizedBox(height: 5),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: _kTextSub),
                          const SizedBox(width: 3),
                          Text(
                              '${request['city'] ?? ''}, ${request['state'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: _kTextSub)),
                        ]),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: _kTextSub, size: 20),
                ]),
                const SizedBox(height: 16),
                const Divider(color: _kBorder, height: 1),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Recusar',
                      icon: Icons.close_rounded,
                      color: _kRed,
                      bg: _kRedSoft,
                      onTap: onReject,
                      disabled: isCreatingChat,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: isCreatingChat ? 'Aguarde...' : 'Aceitar',
                      icon: isCreatingChat
                          ? Icons.hourglass_top_rounded
                          : Icons.check_rounded,
                      color: Colors.white,
                      bg: isCreatingChat ? _kBorder : _kGreen,
                      onTap: isCreatingChat ? () {} : onAccept,
                      filled: true,
                      disabled: isCreatingChat,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  final bool filled;
  final bool disabled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
    this.filled = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: bg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab de Atualizar Perfil — mantido igual ao original
// ─────────────────────────────────────────────────────────────────────────────
class _UpdateProfileTab extends StatefulWidget {
  final String userName;
  final String userAvatar;
  final String userCity;
  final String userState;
  final String legalType;
  final Map<String, dynamic> dataWorker;
  final String localId;
  final VoidCallback onProfileIncomplete;
  final bool finished_basic;
  final bool finished_contact;
  final bool finished_professional;
  final String userTelefone;
  final String userEmail;

  const _UpdateProfileTab({
    required this.userName,
    required this.userAvatar,
    required this.userCity,
    required this.userState,
    required this.legalType,
    required this.dataWorker,
    required this.localId,
    required this.onProfileIncomplete,
    required this.finished_basic,
    required this.finished_contact,
    required this.finished_professional,
    required this.userTelefone,
    required this.userEmail,
  });

  @override
  State<_UpdateProfileTab> createState() => _UpdateProfileTabState();
}

class _UpdateProfileTabState extends State<_UpdateProfileTab> {
  // Cole aqui o restante da implementação original de _UpdateProfileTabState
  @override
  Widget build(BuildContext context) => const SizedBox();
}

// ─────────────────────────────────────────────────────────────────────────────
// Tela de Confirmação — mantida igual ao original
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmationScreen extends StatelessWidget {
  final String userName;
  final String userAvatar;
  final String userCity;
  final String userTelefone;
  final String userEmail;
  final String userState;
  final String legalType;
  final Map<String, dynamic> dataWorker;
  final VoidCallback onConfirm;
  final bool isUpdate;

  const _ConfirmationScreen({
    required this.userName,
    required this.userAvatar,
    required this.userCity,
    required this.userTelefone,
    required this.userEmail,
    required this.userState,
    required this.legalType,
    required this.dataWorker,
    required this.onConfirm,
    this.isUpdate = false,
  });

  @override
  Widget build(BuildContext context) =>
      const SizedBox(); // Mantido igual ao original
}

// ─────────────────────────────────────────────────────────────────────────────
// Tela de Detalhes da Solicitação — mantida igual ao original
// ─────────────────────────────────────────────────────────────────────────────
class _RequestDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestDetailsScreen({
    required this.requestData,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final contractorData =
        requestData['data_contractor'] as Map<String, dynamic>? ?? {};
    final String avatar = requestData['avatar']?.toString() ?? '';

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
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: _kText),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detalhes da Solicitação',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _kText,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage:
                  avatar.isNotEmpty ? NetworkImage(avatar) : null,
              backgroundColor: _kBlueSoft,
              child: avatar.isEmpty
                  ? const Icon(Icons.business_rounded,
                      size: 50, color: _kBlue)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              requestData['name'] ?? 'Nome não informado',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
              textAlign: TextAlign.center,
            ),
            if (contractorData['profession']?.toString() != null &&
                contractorData['profession'].toString() !=
                    'Não definida') ...[
              const SizedBox(height: 4),
              Text(
                contractorData['profession'],
                style: const TextStyle(fontSize: 14, color: _kTextSub),
              ),
            ],
            const SizedBox(height: 24),
            _DetailSection(
              title: 'Informações de Contato',
              children: [
                if (requestData['email']?.toString().isNotEmpty == true)
                  _DetailRow(
                    icon: Icons.email_outlined,
                    label: 'E-mail',
                    value: requestData['email'],
                  ),
                if (requestData['email_contact']
                        ?.toString()
                        .isNotEmpty ==
                    true)
                  _DetailRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'E-mail de Contato',
                    value: requestData['email_contact'],
                  ),
                if (requestData['telefone']?.toString().isNotEmpty ==
                        true &&
                    requestData['telefone'] != 'Não definido')
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Telefone',
                    value: requestData['telefone'],
                  ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Localização',
                  value:
                      '${requestData['city'] ?? ''}, ${requestData['state'] ?? ''}',
                ),
                if (requestData['age'] != null)
                  _DetailRow(
                    icon: Icons.cake_outlined,
                    label: 'Idade',
                    value: '${requestData['age']} anos',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Informações Profissionais',
              children: [
                if (contractorData['company']
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true)
                  _DetailRow(
                    icon: Icons.business_outlined,
                    label: 'Empresa',
                    value: contractorData['company'],
                  ),
                if (contractorData['profession']?.toString() != null &&
                    contractorData['profession'].toString() !=
                        'Não definida')
                  _DetailRow(
                    icon: Icons.work_outline_rounded,
                    label: 'Profissão',
                    value: contractorData['profession'],
                  ),
                _DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Tipo',
                  value: requestData['legalType'] == 'PJ'
                      ? 'Pessoa Jurídica'
                      : requestData['legalType'] == 'PF'
                          ? 'Pessoa Física'
                          : 'Não definido',
                ),
                if (contractorData['summary']?.toString().isNotEmpty ==
                        true &&
                    contractorData['summary'] != 'Não definido') ...[
                  const SizedBox(height: 4),
                  const Divider(color: _kBorder),
                  const SizedBox(height: 10),
                  const Text(
                    'Sobre',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTextSub),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    contractorData['summary'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kText,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: _kCard,
          border: Border(top: BorderSide(color: _kBorder)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: _kRed.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Recusar',
                    style: TextStyle(
                      color: _kRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Aceitar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
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
              border: Border.all(color: _kBorder),
            ),
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
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}