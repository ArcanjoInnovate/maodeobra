// ignore_for_file: unused_element

import 'package:dartobra_new/services/badge/badge_service.dart';
import 'package:dartobra_new/screens/profile/edit_principal_profile_screen.dart';
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
  bool _isLoading = true;

  static const int MAX_VACANCIES = 5;

  @override
  void initState() {
    super.initState();
    // ✅ CORRIGIDO: Usa nomes corretos dos métodos
    /* if (widget.activeMode == 'worker') {
      BadgeHelper.markAllWorkerRequestsAsViewed(
        widget.localId,
        widget.activeMode,
      );
    } else {
      BadgeHelper.markAllVacancyRequestsAsViewed(
        widget.localId,
        widget.activeMode,
      ); */
    
    _loadVacancies();
  }

  bool _isProfileComplete() {
    if (!widget.finished_basic || !widget.finished_contact) {
      return false;
    }

    if (widget.activeMode.toLowerCase() == 'worker') {
      return _validateWorkerProfile();
    } else if (widget.activeMode.toLowerCase() == 'contractor') {
      return _validateContractorProfile();
    }

    return false;
  }

  bool _validateWorkerProfile() {
    final dataWorker = widget.dataWorker;

    final profession = dataWorker['profession'] ?? '';
    if (profession.isEmpty || profession == 'Não definida') {
      return false;
    }

    final summary = dataWorker['summary'] ?? '';
    if (summary.isEmpty || summary == 'Não definido') {
      return false;
    }

    final skills = dataWorker['skills'];
    if (skills == null ||
        (skills is List &&
            (skills.isEmpty ||
                skills.contains('Nenhuma habilidade definida')))) {
      return false;
    }

    if (widget.legalType.toLowerCase() == 'pj') {
      final company = dataWorker['company'] ?? '';
      if (company.isEmpty) {
        return false;
      }
    }

    return true;
  }

  bool _validateContractorProfile() {
    final dataContractor = widget.dataContractor;

    final profession = dataContractor['profession'] ?? '';
    if (profession.isEmpty || profession == 'Não definida') {
      return false;
    }

    final summary = dataContractor['summary'] ?? '';
    if (summary.isEmpty || summary == 'Não definido') {
      return false;
    }

    if (widget.legalType.toLowerCase() == 'pj') {
      final company = dataContractor['company'] ?? '';
      if (company.isEmpty) {
        return false;
      }
    }

    return true;
  }

  List<String> _getIncompleteFields() {
    List<String> incompleteFields = [];

    if (!widget.finished_basic) {
      incompleteFields.add('Informações Básicas');
    }
    if (!widget.finished_contact) {
      incompleteFields.add('Informações de Contato');
    }

    if (widget.activeMode.toLowerCase() == 'worker') {
      final dataWorker = widget.dataWorker;

      final profession = dataWorker['profession'] ?? '';
      if (profession.isEmpty || profession == 'Não definida') {
        incompleteFields.add('Profissão');
      }

      final summary = dataWorker['summary'] ?? '';
      if (summary.isEmpty || summary == 'Não definido') {
        incompleteFields.add('Sobre Você');
      }

      final skills = dataWorker['skills'];
      if (skills == null ||
          (skills is List &&
              (skills.isEmpty ||
                  skills.contains('Nenhuma habilidade definida')))) {
        incompleteFields.add('Habilidades');
      }

      if (widget.legalType.toLowerCase() == 'pj') {
        final company = dataWorker['company'] ?? '';
        if (company.isEmpty) {
          incompleteFields.add('Nome da Empresa');
        }
      }
    } else if (widget.activeMode.toLowerCase() == 'contractor') {
      final dataContractor = widget.dataContractor;

      final profession = dataContractor['profession'] ?? '';
      if (profession.isEmpty || profession == 'Não definida') {
        incompleteFields.add('Profissão/Área de Atuação');
      }

      final summary = dataContractor['summary'] ?? '';
      if (summary.isEmpty || summary == 'Não definido') {
        incompleteFields.add('Sobre Você/Empresa');
      }

      if (widget.legalType.toLowerCase() == 'pj') {
        final company = dataContractor['company'] ?? '';
        if (company.isEmpty) {
          incompleteFields.add('Nome da Empresa');
        }
      }
    }

    return incompleteFields;
  }

  void _showIncompleteProfileDialog() {
    final incompleteFields = _getIncompleteFields();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF6B35),
              size: 26,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Perfil Incompleto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para aproveitar todos os recursos da plataforma, você precisa completar seu perfil.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFFFE8E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFFF6B35),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Complete: ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ...incompleteFields
                      .map(
                        (field) => Padding(
                          padding: EdgeInsets.only(left: 28, top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: Color(0xFFFF6B35),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  field,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Depois',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _editProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Completar Agora',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
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
            Icon(Icons.block, color: Colors.red, size: 26),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Limite Atingido',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Você atingiu o limite de $MAX_VACANCIES vagas ativas.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Feche ou pause uma vaga existente para criar uma nova.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.3,
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
            child: Text(
              'Entendi',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editProfile() async {
    final currentData = widget.activeMode == 'worker'
        ? widget.dataWorker
        : widget.dataContractor;

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

  bool _isWorkerActivated() {
    return widget.workerActivated;
  }

  void _onWorkerActivated() {
    widget.onWorkerActivated();
  }

  Future<void> _loadVacancies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _database.child('vacancy').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> vacancies = [];

        data.forEach((key, value) {
          final vacancy = Map<String, dynamic>.from(value as Map);
          if (vacancy['local_id'] == widget.localId) {
            vacancy['id'] = key;
            vacancies.add(vacancy);
          }
        });

        vacancies.sort((a, b) {
          final dateA = DateTime.parse(a['created_at'] ?? '2000-01-01');
          final dateB = DateTime.parse(b['created_at'] ?? '2000-01-01');
          return dateB.compareTo(dateA);
        });

        setState(() {
          _allVacancies = vacancies;
          _applyFilter(_selectedFilter);
          _isLoading = false;
        });
      } else {
        setState(() {
          _allVacancies = [];
          _filteredVacancies = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar vagas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;

      if (filter == 'Todas') {
        _filteredVacancies = List.from(_allVacancies);
      } else {
        _filteredVacancies = _allVacancies.where((vacancy) {
          final status = (vacancy['status'] ?? 'Aberta')
              .toString()
              .toLowerCase();
          final filterLower = filter.toLowerCase();
          return status == filterLower;
        }).toList();
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Aberta':
        return Colors.green;
      case 'Pausada':
        return Colors.amber;
      case 'Fechada':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  int _getCandidatesCount(dynamic requests) {
    if (requests == null) return 0;
    if (requests is List) return requests.length;
    if (requests is Map) return requests.length;
    return 0;
  }

  Widget _buildWorkerActivatedScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, size: 80, color: Colors.green),
            ),
            SizedBox(height: 24),
            Text(
              'Conta Profissional Ativada!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Sua conta profissional está ativa e você está visível para contratantes.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_active,
                    size: 48,
                    color: Color(0xFFFF6B35),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aguarde solicitações de contato',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Quando contratantes se interessarem pelo seu perfil, você receberá notificações.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.info, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tela de notificações em desenvolvimento',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Color(0xFFFF6B35),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.notifications, size: 22),
                label: Text(
                  'Verificar Notificações',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Edite seu perfil na aba "Perfil"'),
                    backgroundColor: Colors.grey[700],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              icon: Icon(Icons.edit),
              label: Text('Editar Perfil Profissional'),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFFFF6B35),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 80, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              _selectedFilter == 'Todas'
                  ? 'Nenhuma vaga cadastrada'
                  : 'Nenhuma vaga $_selectedFilter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
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

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => _applyFilter(label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeMode.toLowerCase() == 'worker') {
      return WorkerProfileActivation(
        userName: widget.userName,
        userAvatar: widget.userAvatar,
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

    return Scaffold(
      floatingActionButton: FloatingActionButton(
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

          if (result == true) {
            _loadVacancies();
          }
        },
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, size: 28, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadVacancies,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            if (_allVacancies.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _allVacancies.length >= MAX_VACANCIES
                      ? Colors.red[50]
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _allVacancies.length >= MAX_VACANCIES
                        ? Colors.red[200]!
                        : Colors.blue[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _allVacancies.length >= MAX_VACANCIES
                          ? Icons.warning
                          : Icons.info_outline,
                      color: _allVacancies.length >= MAX_VACANCIES
                          ? Colors.red
                          : Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_allVacancies.length} de $MAX_VACANCIES vagas criadas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _allVacancies.length >= MAX_VACANCIES
                              ? Colors.red[800]
                              : Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todas', _selectedFilter == 'Todas'),
                  SizedBox(width: 8),
                  _buildFilterChip('Aberta', _selectedFilter == 'Aberta'),
                  SizedBox(width: 8),
                  _buildFilterChip('Pausada', _selectedFilter == 'Pausada'),
                  SizedBox(width: 8),
                  _buildFilterChip('Fechada', _selectedFilter == 'Fechada'),
                ],
              ),
            ),
            SizedBox(height: 20),

            _isLoading
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Colors.blue),
                    ),
                  )
                : _filteredVacancies.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: _filteredVacancies.map((vacancy) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: _buildJobCard(context, vacancy: vacancy),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(
    BuildContext context, {
    required Map<String, dynamic> vacancy,
  }) {
    final vacancyId = vacancy['id'];
    final title = vacancy['title'] ?? '';
    final profession = vacancy['profession'] ?? '';
    final city = vacancy['city'] ?? '';
    final state = vacancy['state'] ?? '';
    final status = vacancy['status'] ?? 'Aberta';
    final statusColor = _getStatusColor(status);
    final candidatesCount = _getCandidatesCount(vacancy['requests']);

    final legalType = vacancy['legal_type'] ?? '';
    final companyName = vacancy['company_name'] ?? '';
    final description = vacancy['description'] ?? '';
    final salary = vacancy['salary'] ?? 'Não informado';
    final salaryType = vacancy['salary_type'] ?? 'Não informado';
    final media = vacancy['midia'];
    final requests = vacancy['requests'];

    final hasTitle = title.isNotEmpty;

    return GestureDetector(
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

        if (result == true) {
          _loadVacancies();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasTitle) ...[
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                            ],
                            Text(
                              profession,
                              style: TextStyle(
                                fontSize: hasTitle ? 14 : 16,
                                fontWeight: hasTitle
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                color: hasTitle
                                    ? Colors.grey[700]
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        '$city, $state',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_outline, size: 18, color: Colors.blue),
                  SizedBox(width: 6),
                  Text(
                    '$candidatesCount ${candidatesCount == 1 ? 'candidato' : 'candidatos'}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}