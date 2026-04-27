// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:ui';

import 'package:dartobra_new/services/badge/badge_service.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';
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

// Mínimo de caracteres para o resumo profissional
const int _kSummaryMinLength = 40;

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
  });

  @override
  State<WorkerProfileActivation> createState() =>
      _WorkerProfileActivationState();
}

class _WorkerProfileActivationState extends State<WorkerProfileActivation> {
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
    _checkExistingProfile();
  }

  Future<void> _checkExistingProfile() async {
    try {
      final snapshot = await _database
          .child('professionals')
          .orderByChild('local_id')
          .equalTo(widget.localId)
          .once();

      if (snapshot.snapshot.value == null) {
        if (mounted)
          setState(() {
            _hasProfile = false;
            _isCheckingProfile = false;
          });
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
      final profData = Map<String, dynamic>.from(data[resolvedKey] as Map);
      final status = profData['status']?.toString().toLowerCase() ?? '';

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

    final summary = widget.dataWorker['summary']?.toString().trim() ?? '';
    if (summary.length < _kSummaryMinLength) return false;

    final skills = widget.dataWorker['skills'];
    if (skills == null || (skills as List).isEmpty) return false;

    return true;
  }

  void _handleProfileIncomplete() {
    final summary = widget.dataWorker['summary']?.toString().trim() ?? '';
    final skills = widget.dataWorker['skills'];
    final hasSkills = skills != null && (skills as List).isNotEmpty;

    String message;

    if (!widget.finished_basic ||
        !widget.finished_contact ||
        !widget.finished_professional) {
      message = 'Complete todas as seções do seu perfil antes de ativar.';
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
      await _database.child('Users/${widget.localId}/isActive').set(true);
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
    final profession = widget.dataWorker['profession'] ?? 'Profissional';
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
      'views': {'total_views': 0, 'unique_viewers': [], 'last_viewed_at': null},
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
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
// Vista Inativa — com checklist de requisitos
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
            style: TextStyle(
              fontSize: 15,
              color: _kTextSub,
              height: 1.55,
            ),
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
            child: Row(
              children: [
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
                      const Text(
                        'Duração: 2 dias',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _kBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Você poderá renovar quando estiver próximo do vencimento para continuar visível',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kBlue.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (!isProfileComplete) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kOrangeSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kOrange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.checklist_rounded, color: _kOrange, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Requisitos para ativar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _kOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _RequirementItem(
                    label: 'Perfil básico preenchido',
                    ok: true,
                  ),
                  _RequirementItem(
                    label: 'Habilidades adicionadas',
                    ok: hasSkills,
                  ),
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
            description: 'Criamos um anúncio baseado no seu perfil completo',
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.visibility_outlined,
            iconColor: _kGreen,
            iconBg: _kGreenSoft,
            title: 'Visibilidade',
            description: 'Seu perfil fica disponível no banco de profissionais',
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.connect_without_contact_outlined,
            iconColor: _kOrange,
            iconBg: _kOrangeSoft,
            title: 'Oportunidades',
            description: 'Empresas podem te encontrar e enviar propostas',
          ),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isActivating ? null : onActivate,
              style: ElevatedButton.styleFrom(
                backgroundColor: isProfileComplete ? _kBlue : _kOrange,
                disabledBackgroundColor: _kBorder,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isActivating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
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
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: ok ? _kGreen : _kRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: ok ? _kText : _kRed,
                fontWeight: ok ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: _kTextSub),
                ),
              ],
            ),
          ),
        ],
      ),
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
    return Column(
      children: [
        Container(
          color: _kCard,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
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
                          offset: const Offset(0, 6),
                        ),
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
                        Text(
                          'Perfil Profissional',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _kText,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        _ActiveBadge(),
                      ],
                    ),
                  ),
                ],
              ),
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
                  letterSpacing: 0.1,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Solicitações'),
                  Tab(text: 'Atualizar Perfil'),
                ],
              ),
            ],
          ),
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
      ],
    );
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _kGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Ativo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kGreen,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab de Solicitações
// ─────────────────────────────────────────────────────────────────────────────
class _RequestsTab extends StatefulWidget {
  final String localId;

  const _RequestsTab({required this.localId});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isLoadingRequests = false;
  bool _isCreatingChat = false;

  List<Map<String, dynamic>> _workRequests = [];
  String? _myProfileKey;

  @override
  void initState() {
    super.initState();
    _loadWorkRequests();
  }

  Future<void> _loadWorkRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final myProfileSnapshot = await _database
          .child('professionals')
          .orderByChild('local_id')
          .equalTo(widget.localId)
          .once();

      if (myProfileSnapshot.snapshot.value == null) {
        setState(() => _isLoadingRequests = false);
        return;
      }

      final myProfileData =
          myProfileSnapshot.snapshot.value as Map<dynamic, dynamic>;
      _myProfileKey = myProfileData.keys.first;
      final myProfile = Map<String, dynamic>.from(myProfileData[_myProfileKey]);

      if (myProfile['requests'] == null ||
          (myProfile['requests'] as List).isEmpty) {
        setState(() {
          _workRequests = [];
          _isLoadingRequests = false;
        });
        return;
      }

      final requestLocalIds = List<String>.from(myProfile['requests']);

      Map<String, dynamic> viewsData = {};
      if (myProfile['views'] != null &&
          myProfile['views']['request_views'] != null) {
        viewsData = Map<String, dynamic>.from(
          myProfile['views']['request_views'] as Map,
        );
      }

      List<Map<String, dynamic>> requests = [];

      for (String localId in requestLocalIds) {
        try {
          final userSnapshot = await _database.child('Users/$localId').once();
          if (userSnapshot.snapshot.value != null) {
            final userData = Map<String, dynamic>.from(
              userSnapshot.snapshot.value as Map,
            );
            Map<String, dynamic> contractorData = {};
            if (userData['data_contractor'] != null) {
              contractorData = Map<String, dynamic>.from(
                userData['data_contractor'] as Map,
              );
            }
            bool viewedByOwner = false;
            if (viewsData.containsKey(localId)) {
              viewedByOwner = viewsData[localId]['viewed_by_owner'] ?? false;
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
          debugPrint('Erro ao buscar dados do usuário $localId: $e');
        }
      }

      requests.sort((a, b) {
        if (a['viewed_by_owner'] == b['viewed_by_owner']) return 0;
        return a['viewed_by_owner'] ? 1 : -1;
      });

      setState(() {
        _workRequests = requests;
        _isLoadingRequests = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar requisições: $e');
      setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _refreshRequests() async => await _loadWorkRequests();

  Future<void> _removeRequestFromList(String requestLocalId) async {
    if (_myProfileKey == null) return;
    final snapshot =
        await _database.child('professionals/$_myProfileKey/requests').once();
    if (snapshot.snapshot.value != null) {
      List<dynamic> currentRequests =
          List<dynamic>.from(snapshot.snapshot.value as List<dynamic>);
      currentRequests.remove(requestLocalId);
      await _database
          .child('professionals/$_myProfileKey/requests')
          .set(currentRequests);
      await _database
          .child(
              'professionals/$_myProfileKey/views/request_views/$requestLocalId')
          .remove();
      await BadgeHelper.decrementRequestBadge(widget.localId);
      if (mounted) {
        setState(() {
          _workRequests.removeWhere((req) => req['local_id'] == requestLocalId);
        });
      }
    }
  }

  Future<void> _rejectRequest(String requestLocalId) async {
    if (_myProfileKey == null) return;
    try {
      await _removeRequestFromList(requestLocalId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.block_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Solicitação recusada'),
          ]),
          backgroundColor: _kOrange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao recusar solicitação: $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  Future<void> _createChat(Map<String, dynamic> requestData) async {
    if (_isCreatingChat) return;

    setState(() => _isCreatingChat = true);

    try {
      final DatabaseReference chatRef = _database.child('Chats').push();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await chatRef.set({
        'contractor': requestData['local_id'],
        'employee': widget.localId,
        'participants': {'contractor': 'offline', 'employee': 'offline'},
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
      await _removeRequestFromList(requestData['local_id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Solicitação aceita! Chat iniciado.'),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Erro ao aceitar solicitação'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _kBlue,
      onRefresh: _refreshRequests,
      child: _isLoadingRequests
          ? const Center(
              child:
                  CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5))
          : _workRequests.isEmpty
              ? _EmptyRequests()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _workRequests.length,
                  itemBuilder: (context, index) => _RequestCard(
                    request: _workRequests[index],
                    isCreatingChat: _isCreatingChat,
                    onTap: () => _showRequestDetails(_workRequests[index]),
                    onAccept: () => _createChat(_workRequests[index]),
                    onReject: () =>
                        _rejectRequest(_workRequests[index]['local_id']),
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
                  borderRadius: BorderRadius.circular(24),
                ),
                child:
                    const Icon(Icons.inbox_outlined, size: 40, color: _kBlue),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nenhuma solicitação',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Empresas poderão te encontrar\ne enviar solicitações por aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _kTextSub, height: 1.5),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_new_rounded,
                            color: Colors.white, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'NOVA SOLICITAÇÃO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundImage:
                          avatar.isNotEmpty ? NetworkImage(avatar) : null,
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
                              fontWeight:
                                  isNew ? FontWeight.w800 : FontWeight.w600,
                              color: _kText,
                            ),
                          ),
                          if (contractorData['company']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                contractorData['company'],
                                style: const TextStyle(
                                    fontSize: 13, color: _kTextSub),
                              ),
                            ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 13, color: _kTextSub),
                              const SizedBox(width: 3),
                              Text(
                                '${request['city'] ?? ''}, ${request['state'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12, color: _kTextSub),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: _kTextSub, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: _kBorder, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
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
                  ],
                ),
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
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab de Atualizar Perfil
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
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isUpdating = false;
  String? _professionalId;

  // ✅ FONTE ÚNICA DE VERDADE: carregada do Firebase, não de prop
  bool _currentProfessionalIsActive = false;
  bool _isLoadingStatus = true; // ← aguarda o Firebase antes de renderizar o widget

  String? _expiresAt;
  bool _isExpired = false;
  bool _isNearExpiration = false;
  final ExpirationService _expirationService = ExpirationService();
  int _daysLeft = 0;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    await _findProfessionalId(); // ← define _professionalId E _currentProfessionalIsActive
    await _loadExpirationInfo();
  }

  // ✅ Lê o status real do Firebase e guarda em _currentProfessionalIsActive
  Future<void> _findProfessionalId() async {
    try {
      final snapshot = await _database
          .child('professionals')
          .orderByChild('local_id')
          .equalTo(widget.localId)
          .once();

      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        String? activeKey;
        String? fallbackKey;

        data.forEach((key, value) {
          final status =
              (value as Map?)?['status']?.toString().toLowerCase() ?? '';
          fallbackKey ??= key.toString();
          if (status == 'active') activeKey = key.toString();
        });

        final resolvedKey = activeKey ?? fallbackKey;
        if (resolvedKey != null) {
          final profData =
              Map<String, dynamic>.from(data[resolvedKey] as Map);
          final status = profData['status']?.toString().toLowerCase() ?? '';

          if (mounted) {
            setState(() {
              _professionalId = resolvedKey;
              _currentProfessionalIsActive = status == 'active';
              _isLoadingStatus = false;
            });
          }
          return;
        }
      }

      if (mounted) setState(() => _isLoadingStatus = false);
    } catch (e) {
      debugPrint('Erro ao buscar ID do profissional: $e');
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _loadExpirationInfo() async {
    if (_professionalId == null || _professionalId!.isEmpty) return;

    try {
      final snapshot =
          await _database.child('professionals/$_professionalId').get();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final expiresAt = data['expires_at']?.toString();

        if (mounted) {
          setState(() {
            _expiresAt = expiresAt;
            _isExpired = _expirationService.isExpired(expiresAt);
            _isNearExpiration = _expirationService.isNearExpiration(expiresAt);
            _daysLeft = _expirationService.daysUntilExpiration(expiresAt);
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar expiração: $e');
    }
  }

  void _showRenewalRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.timer_off_rounded,
                  color: Color(0xFFEA580C), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Perfil expirado',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Seu perfil profissional está expirado e não pode ser pausado ou reativado.\n\n'
          'Renove-o primeiro para voltar a gerenciar o status.',
          style: TextStyle(fontSize: 14, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Agora não',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isUpdating = true);
              final success = await _expirationService
                  .renewProfessional(_professionalId!);
              if (success && mounted) {
                await _loadExpirationInfo();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Row(children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Perfil renovado! +2 dias de visibilidade'),
                  ]),
                  backgroundColor: const Color(0xFF16A34A),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ));
              }
              if (mounted) setState(() => _isUpdating = false);
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Renovar agora',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  bool _isProfileComplete() {
    if (!widget.finished_basic ||
        !widget.finished_contact ||
        !widget.finished_professional) return false;

    final summary = widget.dataWorker['summary']?.toString().trim() ?? '';
    if (summary.length < _kSummaryMinLength) return false;

    final skills = widget.dataWorker['skills'];
    if (skills == null || (skills as List).isEmpty) return false;

    return true;
  }

  void _handleProfileIncomplete() {
    final summary = widget.dataWorker['summary']?.toString().trim() ?? '';
    final skills = widget.dataWorker['skills'];
    final hasSkills = skills != null && (skills as List).isNotEmpty;

    String message;
    if (!widget.finished_basic ||
        !widget.finished_contact ||
        !widget.finished_professional) {
      message = 'Complete todas as seções do perfil antes de sincronizar.';
    } else if (summary.length < _kSummaryMinLength) {
      message =
          'Descrição profissional muito curta (${summary.length}/$_kSummaryMinLength caracteres). '
          'Acesse "Editar Perfil" → seção Profissional e preencha corretamente.';
    } else if (!hasSkills) {
      message = 'Adicione habilidades ao seu perfil antes de sincronizar.';
    } else {
      message = 'Complete seu perfil antes de sincronizar.';
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

  Future<void> _updateProfessionalProfile() async {
    if (!_isProfileComplete()) {
      _handleProfileIncomplete();
      return;
    }
    if (_professionalId == null) {
      await _findProfessionalId();
      if (_professionalId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erro: Perfil profissional não encontrado'),
            backgroundColor: _kRed,
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
    }
    setState(() => _isUpdating = true);
    try {
      final updateData = {
        'name': widget.userName,
        'avatar': widget.userAvatar,
        'profession': widget.dataWorker['profession'] ?? 'Profissional',
        'city': widget.userCity,
        'state': widget.userState,
        'legal_type': widget.legalType,
        'company': widget.dataWorker['company'] ?? '',
        'summary': widget.dataWorker['summary'] ?? '',
        'skills': widget.dataWorker['skills'] ?? [],
        'telefone': widget.userTelefone,
        'email': widget.userEmail,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _database
          .child('professionals/$_professionalId')
          .update(updateData);
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Perfil atualizado com sucesso!'),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao atualizar perfil: $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  void _showUpdateConfirmation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ConfirmationScreen(
          userName: widget.userName,
          userEmail: widget.userEmail,
          userTelefone: widget.userTelefone,
          userAvatar: widget.userAvatar,
          userCity: widget.userCity,
          userState: widget.userState,
          legalType: widget.legalType,
          dataWorker: widget.dataWorker,
          isUpdate: true,
          onConfirm: () {
            Navigator.pop(context);
            _updateProfessionalProfile();
          },
        ),
      ),
    );
  }

  Widget _buildExpirationBanner() {
    final bool expired = _isExpired;
    final bool shouldShow = expired || (_isNearExpiration && _daysLeft <= 1);

    final isTestMode = ExpirationService.testDate != null;

    if (!shouldShow && !isTestMode) {
      return const SizedBox.shrink();
    }

    if (isTestMode && !shouldShow) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFFEA580C).withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.science_rounded,
                            color: Color(0xFFEA580C), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🧪 Modo de Teste Ativo',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Perfil criado antes do testDate. Ajuste para ver o banner de renovação.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFEA580C),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _DebugInfoRow(
                            'Data atual simulada',
                            _expirationService
                                .getCurrentNow()
                                .toString()
                                .split('.')[0]),
                        if (_expiresAt != null)
                          _DebugInfoRow(
                              'Expira em', _expiresAt!.split('.')[0]),
                        _DebugInfoRow('Dias restantes', '$_daysLeft dias'),
                        _DebugInfoRow(
                            'Status',
                            _isExpired
                                ? 'Expirado'
                                : _isNearExpiration
                                    ? 'Próximo de expirar'
                                    : 'Ativo'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: const Color(0xFFEA580C).withOpacity(0.3)),
            InkWell(
              onTap: _isUpdating
                  ? null
                  : () async {
                      setState(() => _isUpdating = true);
                      final success = await _expirationService
                          .renewProfessional(_professionalId!);
                      if (success && mounted) {
                        await _loadExpirationInfo();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Row(children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 12),
                            Text('🧪 Perfil ajustado para o tempo de teste!'),
                          ]),
                          backgroundColor: const Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                        ));
                      }
                      if (mounted) setState(() => _isUpdating = false);
                    },
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isUpdating
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFEA580C)),
                            ),
                          )
                        : const Icon(Icons.refresh_rounded,
                            size: 18, color: Color(0xFFEA580C)),
                    const SizedBox(width: 8),
                    Text(
                      _isUpdating
                          ? 'Ajustando...'
                          : '🧪 Ajustar para Teste (+2 dias)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final Color accent =
        expired ? const Color(0xFFDC2626) : const Color(0xFFEA580C);
    final Color bgColor =
        expired ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED);

    final String headline = expired
        ? 'Seu perfil expirou'
        : _daysLeft == 1
            ? 'Expira amanhã!'
            : 'Expira em $_daysLeft dias';

    final String sub = expired
        ? 'Ele não aparece mais no banco de profissionais. Renove para reativar.'
        : 'Renove agora para continuar visível para empresas.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    expired
                        ? Icons.timer_off_rounded
                        : Icons.hourglass_bottom_rounded,
                    color: accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: accent.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: accent.withOpacity(0.3)),
          InkWell(
            onTap: _isUpdating
                ? null
                : () async {
                    setState(() => _isUpdating = true);
                    final success = await _expirationService
                        .renewProfessional(_professionalId!);
                    if (success && mounted) {
                      await _loadExpirationInfo();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Row(children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('Perfil renovado! +2 dias de visibilidade'),
                        ]),
                        backgroundColor: const Color(0xFF16A34A),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ));
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Row(children: [
                          Icon(Icons.error_outline,
                              color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('Erro ao renovar perfil'),
                        ]),
                        backgroundColor: const Color(0xFFDC2626),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ));
                    }
                    if (mounted) setState(() => _isUpdating = false);
                  },
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isUpdating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFEA580C)),
                          ),
                        )
                      : Icon(Icons.refresh_rounded, size: 17, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    _isUpdating ? 'Renovando...' : 'Renovar agora (+2 dias)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skills = (widget.dataWorker['skills'] as List?) ?? [];
    final profession = widget.dataWorker['profession']?.toString() ??
        'Profissão não definida';
    final summary = widget.dataWorker['summary']?.toString().trim() ?? '';
    final summaryOk = summary.length >= _kSummaryMinLength;
    final hasSkills = skills.isNotEmpty;
    final profileComplete = _isProfileComplete();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        children: [
          // ── Avatar + Nome ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundImage: widget.userAvatar.isNotEmpty
                      ? NetworkImage(widget.userAvatar)
                      : null,
                  backgroundColor: _kBlueSoft,
                  child: widget.userAvatar.isEmpty
                      ? const Icon(Icons.person_rounded,
                          size: 42, color: _kBlue)
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kText,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profession,
                  style: const TextStyle(fontSize: 14, color: _kTextSub),
                ),
                const SizedBox(height: 14),
                const _ActiveBadge(),
              ],
            ),
          ),

          if (_expiresAt != null &&
              (_isExpired || (_isNearExpiration && _daysLeft <= 1))) ...[
            const SizedBox(height: 16),
            _buildExpirationBanner(),
          ],

          const SizedBox(height: 16),

          // ── Alerta se perfil incompleto ───────────────────────────────
          if (!profileComplete) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kOrangeSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kOrange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: _kOrange, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Perfil incompleto',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _kOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _RequirementItem(
                    label: 'Habilidades adicionadas',
                    ok: hasSkills,
                  ),
                  _RequirementItem(
                    label:
                        'Descrição profissional (${summary.length}/$_kSummaryMinLength caracteres)',
                    ok: summaryOk,
                  ),
                  if (!summaryOk) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: _kOrange.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: _kOrange),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Acesse "Editar Perfil" → seção Profissional para preencher sua descrição.',
                              style:
                                  TextStyle(fontSize: 12, color: _kOrange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Status Control ────────────────────────────────────────────
          // ✅ Mostra loading enquanto o Firebase não respondeu,
          //    depois renderiza o widget com o status real.
          //    O ValueKey garante que o widget é recriado sempre que
          //    o status muda, respeitando o valor atualizado do Firebase.
          if (_isLoadingStatus)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                      color: _kBlue, strokeWidth: 2.5),
                ),
              ),
            )
          else if (_isExpired)
            Stack(
              children: [
                IgnorePointer(
                  child: ProfessionalStatusControlWidget(
                    key: ValueKey(
                        'status_${_currentProfessionalIsActive}_${_professionalId}'),
                    initialIsActive: _currentProfessionalIsActive,
                    localId: widget.localId,
                    professionalId: _professionalId ?? '',
                    onStatusChanged: (_) {},
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _showRenewalRequiredDialog,
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            )
          else
            ProfessionalStatusControlWidget(
              // ✅ ValueKey: força recriação do widget quando o status muda
              key: ValueKey(
                  'status_${_currentProfessionalIsActive}_${_professionalId}'),
              initialIsActive: _currentProfessionalIsActive,
              localId: widget.localId,
              professionalId: _professionalId ?? '',
              onStatusChanged: (bool isNowActive) {
                setState(() => _currentProfessionalIsActive = isNowActive);
              },
            ),

          const SizedBox(height: 16),

          // ── Informações do Perfil ─────────────────────────────────────
          Container(
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
                const Text(
                  'Informações do Perfil',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Localização',
                  value: '${widget.userCity}, ${widget.userState}',
                ),
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Tipo',
                  value: widget.legalType == 'PJ'
                      ? 'Pessoa Jurídica'
                      : 'Pessoa Física',
                ),
                if (widget.legalType == 'PJ' &&
                    widget.dataWorker['company']
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true)
                  _InfoRow(
                    icon: Icons.business_outlined,
                    label: 'Empresa',
                    value: widget.dataWorker['company'],
                  ),
                if (widget.userTelefone.isNotEmpty &&
                    widget.userTelefone != 'Não definido')
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Telefone',
                    value: widget.userTelefone,
                  ),
                if (widget.userEmail.isNotEmpty)
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'E-mail de contato',
                    value: widget.userEmail,
                  ),
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(color: _kBorder),
                  const SizedBox(height: 12),
                  const Text(
                    'Habilidades',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kTextSub,
                    ),
                  ),
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
                          border: Border.all(color: _kBlueMid),
                        ),
                        child: Text(
                          skill.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kBlueSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBlueMid),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _kBlue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sincronize o anúncio com as alterações mais recentes do seu perfil.',
                    style:
                        TextStyle(fontSize: 13, color: _kBlue, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isUpdating ? null : _showUpdateConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: profileComplete ? _kBlue : _kOrange,
                disabledBackgroundColor: _kBorder,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isUpdating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          profileComplete
                              ? Icons.sync_rounded
                              : Icons.edit_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          profileComplete
                              ? 'Sincronizar Perfil Profissional'
                              : 'Complete o Perfil para Sincronizar',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ Widget auxiliar para o debug
class _DebugInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _DebugInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: _kTextSub)),
              const SizedBox(height: 1),
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tela de Confirmação (Ativar / Atualizar)
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
  Widget build(BuildContext context) {
    final skills = (dataWorker['skills'] as List?) ?? [];

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
        title: Text(
          isUpdate ? 'Confirmar Atualização' : 'Confirmar Ativação',
          style: const TextStyle(
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
              radius: 52,
              backgroundImage:
                  userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
              backgroundColor: _kBlueSoft,
              child: userAvatar.isEmpty
                  ? const Icon(Icons.person_rounded,
                      size: 52, color: _kBlue)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isUpdate
                  ? 'Revise as informações atualizadas'
                  : 'Revise as informações antes de ativar',
              style: const TextStyle(fontSize: 14, color: _kTextSub),
            ),
            const SizedBox(height: 28),
            Container(
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
                  _ConfirmRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Nome',
                      value: userName),
                  _ConfirmRow(
                      icon: Icons.work_outline_rounded,
                      label: 'Profissão',
                      value: dataWorker['profession'] ?? 'Não definida'),
                  _ConfirmRow(
                      icon: Icons.badge_outlined,
                      label: 'Tipo',
                      value: legalType == 'PJ'
                          ? 'Pessoa Jurídica'
                          : 'Pessoa Física'),
                  if (legalType == 'PJ' &&
                      dataWorker['company']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true)
                    _ConfirmRow(
                        icon: Icons.business_outlined,
                        label: 'Empresa',
                        value: dataWorker['company']),
                  _ConfirmRow(
                      icon: Icons.location_on_outlined,
                      label: 'Localização',
                      value: '$userCity, $userState'),
                  if (userTelefone.isNotEmpty &&
                      userTelefone != 'Não definido')
                    _ConfirmRow(
                        icon: Icons.phone_outlined,
                        label: 'Telefone',
                        value: userTelefone),
                  if (userEmail.isNotEmpty)
                    _ConfirmRow(
                        icon: Icons.email_outlined,
                        label: 'E-mail de contato',
                        value: userEmail),
                  if (dataWorker['summary']?.toString().isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 4),
                    const Divider(color: _kBorder),
                    const SizedBox(height: 12),
                    const Text(
                      'Resumo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTextSub,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dataWorker['summary'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: _kText,
                        height: 1.55,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ],
                  if (skills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: _kBorder),
                    const SizedBox(height: 12),
                    const Text(
                      'Habilidades',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTextSub,
                      ),
                    ),
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
                            border: Border.all(color: _kBlueMid),
                          ),
                          child: Text(
                            skill.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: _kCard,
          border: Border(top: BorderSide(color: _kBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: _kBorder, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: _kTextSub,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUpdate ? _kBlue : _kGreen,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isUpdate ? 'Confirmar' : 'Ativar Agora',
                    style: const TextStyle(
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

class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConfirmRow({
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

// ─────────────────────────────────────────────────────────────────────────────
// Tela de Detalhes da Solicitação
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