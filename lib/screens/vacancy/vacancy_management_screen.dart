
import 'dart:async';

import 'package:dartobra_new/screens/profile/edit_principal_profile_screen.dart';
import 'package:dartobra_new/services/expiration_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dartobra_new/screens/vacancy/create_vacancy_screen.dart';
import 'package:dartobra_new/screens/vacancy/vacancy_info_screen.dart';
import 'package:dartobra_new/screens/vacancy/worker_profile_activation_screen.dart';

class VacancyManagement extends StatefulWidget {
  final String userEmail;
  final String userPhone;
  final String localId;
  final String userName;
  final String legalType;
  final String userCity;
  final String userState;
  final String userAvatar;
  final bool finished_basic;
  final bool finished_professional;
  final bool finished_contact;
  final bool isActive;
  final String activeMode;
  final Map<String, dynamic> dataWorker;
  final Map<String, dynamic> dataContractor;
  final bool workerActivated;
  final VoidCallback onWorkerActivated;

  const VacancyManagement({
    super.key,
    required this.userEmail,
    required this.userPhone,
    required this.localId,
    required this.userName,
    required this.legalType,
    required this.userCity,
    required this.userState,
    required this.userAvatar,
    required this.finished_basic,
    required this.finished_professional,
    required this.finished_contact,
    required this.isActive,
    required this.activeMode,
    required this.dataWorker,
    required this.dataContractor,
    this.workerActivated = false,
    required this.onWorkerActivated,
  });

  @override
  State<VacancyManagement> createState() => _VacancyManagementState();
}

class _VacancyManagementState extends State<VacancyManagement> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _allVacancies = [];
  List<Map<String, dynamic>> _filteredVacancies = [];
  String _selectedFilter = 'Todas';
  final ExpirationService _expService = ExpirationService();
  bool _isLoading = true;

  static const int MAX_VACANCIES = 5;
  StreamSubscription<DatabaseEvent>? _vacanciesSubscription;

  
  @override
  void initState() {
    super.initState();
    _listenToVacancies(); 
  }

  // ─── Profile validation ──────────────────────────────────────────────────

  bool _isProfileComplete() {
    if (!widget.finished_basic || !widget.finished_contact) return false;
    if (widget.activeMode.toLowerCase() == 'worker') return _validateWorkerProfile();
    if (widget.activeMode.toLowerCase() == 'contractor') return _validateContractorProfile();
    return false;
  }

  bool _validateWorkerProfile() {
    final d = widget.dataWorker;
    if ((d['profession'] ?? '').isEmpty || d['profession'] == 'Não definida') return false;
    if ((d['summary'] ?? '').isEmpty || d['summary'] == 'Não definido') return false;
    final skills = d['skills'];
    if (skills == null ||
        (skills is List && (skills.isEmpty || skills.contains('Nenhuma habilidade definida')))) {
      return false;
    }
    if (widget.legalType.toLowerCase() == 'pj' && (d['company'] ?? '').isEmpty) return false;
    return true;
  }

  bool _validateContractorProfile() {
    final d = widget.dataContractor;
    if ((d['profession'] ?? '').isEmpty || d['profession'] == 'Não definida') return false;
    if ((d['summary'] ?? '').isEmpty || d['summary'] == 'Não definido') return false;
    if (widget.legalType.toLowerCase() == 'pj' && (d['company'] ?? '').isEmpty) return false;
    return true;
  }

  List<String> _getIncompleteFields() {
    List<String> fields = [];
    if (!widget.finished_basic) fields.add('Informações Básicas');
    if (!widget.finished_contact) fields.add('Informações de Contato');

    if (widget.activeMode.toLowerCase() == 'worker') {
      final d = widget.dataWorker;
      if ((d['profession'] ?? '').isEmpty || d['profession'] == 'Não definida') fields.add('Profissão');
      if ((d['summary'] ?? '').isEmpty || d['summary'] == 'Não definido') fields.add('Sobre Você');
      final skills = d['skills'];
      if (skills == null ||
          (skills is List && (skills.isEmpty || skills.contains('Nenhuma habilidade definida')))) {
        fields.add('Habilidades');
      }
      if (widget.legalType.toLowerCase() == 'pj' && (d['company'] ?? '').isEmpty) {
        fields.add('Nome da Empresa');
      }
    } else if (widget.activeMode.toLowerCase() == 'contractor') {
      final d = widget.dataContractor;
      if ((d['profession'] ?? '').isEmpty || d['profession'] == 'Não definida') fields.add('Profissão/Área de Atuação');
      if ((d['summary'] ?? '').isEmpty || d['summary'] == 'Não definido') fields.add('Sobre Você/Empresa');
      if (widget.legalType.toLowerCase() == 'pj' && (d['company'] ?? '').isEmpty) fields.add('Nome da Empresa');
    }
    return fields;
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  void _showIncompleteProfileDialog() {
    final incompleteFields = _getIncompleteFields();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: const Color(0xFFFF6B35), size: 26),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Perfil Incompleto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para aproveitar todos os recursos da plataforma, você precisa completar seu perfil.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFFF6B35), size: 20),
                      const SizedBox(width: 8),
                      Text('Complete: ',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...incompleteFields.map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(left: 28, top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 6, color: Color(0xFFFF6B35)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(field,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[800]))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Depois', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _editProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Completar Agora',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  void _showVacancyLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red, size: 26),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Limite Atingido',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Você atingiu o limite de $MAX_VACANCIES vagas ativas.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Feche ou pause uma vaga existente para criar uma nova.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi',
                style: TextStyle(color: Colors.blue, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Edit profile ─────────────────────────────────────────────────────────

  void _editProfile() async {
    final currentData =
        widget.activeMode == 'worker' ? widget.dataWorker : widget.dataContractor;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          local_id: widget.localId,
          dataContractor: widget.dataContractor,
          dataWorker: widget.dataWorker,
          userName: widget.userName,
          userEmail: widget.userEmail,
          contact_email: widget.userEmail,
          userPhone: widget.userPhone,
          userCity: widget.userCity,
          finished_basic: widget.finished_basic,
          finished_professional: widget.finished_professional,
          finished_contact: widget.finished_contact,
          userAvatar: widget.userAvatar,
          userState: widget.userState,
          userAge: currentData['age'] ?? 0,
          legalType: widget.legalType,
          company: currentData['company'] ?? '',
          activeMode: widget.activeMode,
          profession: currentData['profession'] ?? '',
          summary: currentData['summary'] ?? '',
          skills: currentData['skills'] != null
              ? List<String>.from(currentData['skills'])
              : [],
        ),
      ),
    );

    if (result != null && mounted) {
      print('✅ Perfil atualizado, recarregando dados...');
    }
  }

  bool _isWorkerActivated() => widget.workerActivated;
  void _onWorkerActivated() => widget.onWorkerActivated();

  // ─── Data loading ─────────────────────────────────────────────────────────

  // ✅ STREAM EM TEMPO REAL - ATUALIZA AUTOMATICAMENTE
  void _listenToVacancies() {
    final query = _database
        .child('vacancy')
        .orderByChild('local_id')
        .equalTo(widget.localId);

    _vacanciesSubscription = query.onValue.listen((event) {
      final snapshot = event.snapshot;
      List<Map<String, dynamic>> vacancies = [];

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final vacancy = Map<String, dynamic>.from(value as Map);
          vacancy['id'] = key;
          vacancies.add(vacancy);
        });

        // Ordena por data de criação (mais recente primeiro)
        vacancies.sort((a, b) {
          final dateA = DateTime.parse(a['created_at'] ?? '2000-01-01');
          final dateB = DateTime.parse(b['created_at'] ?? '2000-01-01');
          return dateB.compareTo(dateA);
        });
      }

      if (mounted) {
        setState(() {
          _allVacancies = vacancies;
          _applyFilter(_selectedFilter);
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('❌ Erro no stream de vagas: $error');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'Todas') {
        _filteredVacancies = List.from(_allVacancies);
      } else {
        _filteredVacancies = _allVacancies.where((v) {
          final status = (v['status'] ?? 'Aberta').toString().toLowerCase();
          return status == filter.toLowerCase();
        }).toList();
      }
    });
  }

  // ─── Status helpers ───────────────────────────────────────────────────────

  _StatusStyle _getStatusStyle(String status, bool isExpired, bool isNear) {
    if (isExpired) {
      return _StatusStyle(
        color: const Color(0xFFDC2626),
        background: const Color(0xFFFEF2F2),
        label: 'Expirada',
        icon: Icons.timer_off_rounded,
      );
    }
    switch (status) {
      case 'Aberta':
        return _StatusStyle(
          color: const Color(0xFF16A34A),
          background: const Color(0xFFDCFCE7),
          label: 'Aberta',
          icon: Icons.check_circle_outline_rounded,
        );
      case 'Pausada':
        return _StatusStyle(
          color: const Color(0xFFD97706),
          background: const Color(0xFFFEF3C7),
          label: 'Pausada',
          icon: Icons.pause_circle_outline_rounded,
        );
      case 'Fechada':
        return _StatusStyle(
          color: const Color(0xFF6B7280),
          background: const Color(0xFFF3F4F6),
          label: 'Fechada',
          icon: Icons.cancel_outlined,
        );
      default:
        return _StatusStyle(
          color: const Color(0xFF6B7280),
          background: const Color(0xFFF3F4F6),
          label: status,
          icon: Icons.circle_outlined,
        );
    }
  }

  int _getCandidatesCount(dynamic requests) {
    if (requests == null) return 0;
    if (requests is List) return requests.length;
    if (requests is Map) return requests.length;
    return 0;
  }

  // ─── Worker screen ────────────────────────────────────────────────────────

  Widget _buildWorkerActivatedScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, size: 80, color: Colors.green),
            ),
            const SizedBox(height: 24),
            const Text(
              'Conta Profissional Ativada!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Sua conta profissional está ativa e você está visível para contratantes.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.notifications_active, size: 48, color: Color(0xFFFF6B35)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aguarde solicitações de contato',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quando contratantes se interessarem pelo seu perfil, você receberá notificações.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('Tela de notificações em desenvolvimento')),
                        ],
                      ),
                      backgroundColor: const Color(0xFFFF6B35),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications, size: 22),
                label: const Text('Verificar Notificações',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.work_outline, size: 48, color: Colors.blue.shade200),
            ),
            const SizedBox(height: 20),
            Text(
              _selectedFilter == 'Todas' ? 'Nenhuma vaga cadastrada' : 'Nenhuma vaga $_selectedFilter',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'Todas'
                  ? 'Crie sua primeira vaga usando o botão +'
                  : 'Não há vagas com este status',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter chip ──────────────────────────────────────────────────────────

  Widget _buildFilterChip(String label, bool isSelected, {IconData? icon}) {
    return GestureDetector(
      onTap: () => _applyFilter(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.blue.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey[600]),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.activeMode.toLowerCase() == 'worker') {
      return WorkerProfileActivation(
        userName: widget.userName,
        userAvatar: widget.userAvatar,
        userEmail: widget.userEmail,
        userTelefone: widget.userPhone,
        userCity: widget.userCity,
        userState: widget.userState,
        legalType: widget.legalType,
        dataWorker: widget.dataWorker,
        isActive: widget.isActive || widget.workerActivated,
        localId: widget.localId,
        finished_basic: widget.finished_basic,
        finished_contact: widget.finished_contact,
        finished_professional: widget.finished_professional,
        onProfileIncomplete: _showIncompleteProfileDialog,
        onActivated: _onWorkerActivated,
      );
    }
     Future<void> _refreshVacancies() async {
      _vacanciesSubscription?.cancel();
      await Future.delayed(const Duration(milliseconds: 300));
      _listenToVacancies();
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: _buildFAB(),
      body: RefreshIndicator(
        onRefresh: _refreshVacancies,
        color: Colors.blue,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _buildQuotaBar(),
            const SizedBox(height: 14),
            _buildFilterRow(),
            const SizedBox(height: 20),
            if (_isLoading)
              _buildLoadingState()
            else if (_filteredVacancies.isEmpty)
              _buildEmptyState()
            else
              ...List.generate(_filteredVacancies.length, (i) {
                return TweenAnimationBuilder<double>(
                  key: ValueKey(_filteredVacancies[i]['id']),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + i * 60),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildJobCard(context, vacancy: _filteredVacancies[i]),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () async {
        if (!_isProfileComplete()) {
          _showIncompleteProfileDialog();
          return;
        }
        if (_allVacancies.length >= MAX_VACANCIES) {
          _showVacancyLimitDialog();
          return;
        }
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateVacancys(
              isEditing: false,
              emailContact: widget.userEmail,
              localId: widget.localId,
              phoneContact: widget.userPhone,
            ),
          ),
        );
        if (result == true) ();
      },
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add, size: 22),
      label: const Text('Nova Vaga', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildQuotaBar() {
    if (_allVacancies.isEmpty) return const SizedBox.shrink();
    final isFull = _allVacancies.length >= MAX_VACANCIES;
    final progress = _allVacancies.length / MAX_VACANCIES;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isFull ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFull ? const Color(0xFFFCA5A5) : Colors.blue.shade100,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isFull ? Icons.warning_rounded : Icons.work_history_outlined,
                      size: 16,
                      color: isFull ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFull ? 'Limite atingido' : '${_allVacancies.length} de $MAX_VACANCIES vagas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isFull ? Colors.red.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: isFull ? Colors.red.shade100 : Colors.blue.shade100,
                    valueColor: AlwaysStoppedAnimation(isFull ? Colors.red : Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isFull ? Colors.red.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${_allVacancies.length}/$MAX_VACANCIES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isFull ? Colors.red.shade600 : Colors.blue.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Todas', _selectedFilter == 'Todas', icon: Icons.grid_view_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Aberta', _selectedFilter == 'Aberta', icon: Icons.check_circle_outline),
          const SizedBox(width: 8),
          _buildFilterChip('Pausada', _selectedFilter == 'Pausada', icon: Icons.pause_circle_outline),
          const SizedBox(width: 8),
          _buildFilterChip('Fechada', _selectedFilter == 'Fechada', icon: Icons.cancel_outlined),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildSkeletonCard(),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _shimmer(44, 44, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmer(140, 14),
                      const SizedBox(height: 8),
                      _shimmer(100, 12),
                    ],
                  ),
                ),
                _shimmer(60, 26, radius: 13),
              ],
            ),
            const SizedBox(height: 14),
            _shimmer(120, 12),
            const Spacer(),
            _shimmer(double.infinity, 1),
            const SizedBox(height: 10),
            Row(children: [_shimmer(100, 12), const Spacer(), _shimmer(60, 12)]),
          ],
        ),
      ),
    );
  }

  Widget _shimmer(double w, double h, {double radius = 6}) {
    return Container(
      width: w == double.infinity ? double.infinity : w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ─── Job Card ─────────────────────────────────────────────────────────────

  Widget _buildJobCard(BuildContext context, {required Map<String, dynamic> vacancy}) {
    final vacancyId = vacancy['id'];
    final title = vacancy['title'] ?? '';
    final profession = vacancy['profession'] ?? '';
    final city = vacancy['city'] ?? '';
    final state = vacancy['state'] ?? '';
    final status = vacancy['status'] ?? 'Aberta';
    final candidatesCount = _getCandidatesCount(vacancy['requests']);
    final legalType = vacancy['legal_type'] ?? '';
    final companyName = vacancy['company_name'] ?? '';
    final description = vacancy['description'] ?? '';
    final salary = vacancy['salary'] ?? 'Não informado';
    final salaryType = vacancy['salary_type'] ?? 'Não informado';
    final media = vacancy['midia'];
    final requests = vacancy['requests'];
    final hasTitle = title.isNotEmpty;

    // Expiration
    final expiresAt = vacancy['expires_at']?.toString() ?? '';
    final bool isExpired = status.toLowerCase() == 'expirada' ||
        (expiresAt.isNotEmpty && _expService.isExpired(expiresAt));
    final bool isNear =
        !isExpired && expiresAt.isNotEmpty && _expService.isNearExpiration(expiresAt);
    final int daysLeft = _expService.daysUntilExpiration(expiresAt);

    final style = _getStatusStyle(status, isExpired, isNear);
    final bool hasCandidates = candidatesCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Main card ───────────────────────────────────────────────────────
        GestureDetector(
          onTap: () async {
            if (!_isProfileComplete()) {
              _showIncompleteProfileDialog();
              return;
            }
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InfoVacancy(
                  userEmail: widget.userEmail,
                  legalType: legalType,
                  companyName: companyName,
                  description: description,
                  state: state,
                  city: city,
                  title: title,
                  profession: profession,
                  status: status,
                  salary: salary,
                  salaryType: salaryType,
                  media: media,
                  requests: requests is List
                      ? requests
                      : (requests != null ? [requests] : null),
                  localId: widget.localId,
                  userPhone: widget.userPhone,
                  vacancyId: vacancyId,
                ),
              ),
            );
            if (result == true) _listenToVacancies();
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: isExpired
                  ? Border.all(color: const Color(0xFFDC2626).withOpacity(0.3), width: 1.5)
                  : isNear
                      ? Border.all(
                          color: const Color(0xFFEA580C).withOpacity(0.3), width: 1.5)
                      : null,
              boxShadow: [
                BoxShadow(
                  color: hasCandidates
                      ? Colors.blue.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: hasCandidates ? 16 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Expiration banner ─────────────────────────────────────
                if (isExpired || isNear)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFFFF7ED),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isExpired
                              ? Icons.timer_off_rounded
                              : Icons.access_time_rounded,
                          size: 14,
                          color: isExpired
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFEA580C),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isExpired
                              ? 'Vaga expirada — toque para renovar'
                              : daysLeft == 1
                                  ? 'Expira amanhã — renove para manter visibilidade'
                                  : 'Expira em $daysLeft dias',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isExpired
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Card body ─────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, hasCandidates ? 20 : 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon box
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isExpired
                                  ? const Color(0xFFFEF2F2)
                                  : isNear
                                      ? const Color(0xFFFFF7ED)
                                      : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isExpired
                                  ? Icons.work_off_outlined
                                  : Icons.work_outline_rounded,
                              color: isExpired
                                  ? const Color(0xFFDC2626)
                                  : isNear
                                      ? const Color(0xFFEA580C)
                                      : Colors.blue.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title + profession
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasTitle) ...[
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isExpired
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  profession,
                                  style: TextStyle(
                                    fontSize: hasTitle ? 13 : 15,
                                    fontWeight: hasTitle
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    color: isExpired
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: style.background,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: style.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  style.label,
                                  style: TextStyle(
                                    color: style.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Location + salary row
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            '$city, $state',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13),
                          ),
                          if (salary != 'Não informado') ...[
                            const SizedBox(width: 12),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.attach_money_rounded,
                                size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                salary,
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Footer ────────────────────────────────────────────────
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? const Color(0xFFFEF2F2)
                        : hasCandidates
                            ? Colors.blue.shade50
                            : Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 16,
                        color: isExpired
                            ? Colors.grey.shade400
                            : hasCandidates
                                ? Colors.blue.shade600
                                : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$candidatesCount ${candidatesCount == 1 ? 'candidato' : 'candidatos'}',
                        style: TextStyle(
                          color: isExpired
                              ? Colors.grey.shade400
                              : hasCandidates
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: hasCandidates
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      if (isExpired)
                        Row(
                          children: [
                            const Icon(Icons.refresh_rounded,
                                size: 14, color: Color(0xFFDC2626)),
                            const SizedBox(width: 4),
                            const Text(
                              'Renovar',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Text(
                              'Ver detalhes',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 11, color: Colors.grey.shade400),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Candidate badge (floating, top-right) ────────────────────────
        // ── Candidate badge (SUPER MELHORADO) ────────────────────────
if (hasCandidates)
  Positioned(
    top: -12,
    right: 16,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Transform.translate(
          offset: Offset(0, -8 * value),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          // ✨ GRADIENTE AZUL LINDÍSSIMO
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade500,
              Colors.blue.shade600,
              Colors.blue.shade700,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade400.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.blue.shade600.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✨ ÍCONE PULSANTE
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.1),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              builder: (context, pulse, child) => Transform.scale(
                scale: pulse,
                child: Icon(
                  Icons.people_alt_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$candidatesCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            if (candidatesCount > 1) ...[
              const SizedBox(width: 4),
              Text(
                '👥',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
      ],
    );
  }
}

// ─── Status style model ───────────────────────────────────────────────────────

class _StatusStyle {
  final Color color;
  final Color background;
  final String label;
  final IconData icon;

  const _StatusStyle({
    required this.color,
    required this.background,
    required this.label,
    required this.icon,
  });
}