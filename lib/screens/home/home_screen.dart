import 'dart:async';
import 'package:dartobra_new/screens/chat/chat_list_screen.dart';
import 'package:dartobra_new/controllers/search_controller.dart' as search;
import 'package:dartobra_new/screens/complaints/complaint_user_search_screen.dart';
import 'package:dartobra_new/screens/search/search_page.dart';
import 'package:dartobra_new/screens/feed/feed_screen.dart';
import 'package:dartobra_new/main.dart' as main_app;
import 'package:dartobra_new/screens/vacancy/worker_profile_activation_screen.dart';
import 'package:dartobra_new/services/notifications/badge_init.dart';
import 'package:dartobra_new/services/notifications/notification_navigation_service.dart';

import 'package:dartobra_new/services/notifications/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dartobra_new/screens/profile/edit_principal_profile_screen.dart';
import 'package:dartobra_new/screens/vacancy/vacancy_management_screen.dart';
import 'package:provider/provider.dart';

// No topo do arquivo, fora da classe
final GlobalKey<_HomeScreenState> homeScreenKey = GlobalKey<_HomeScreenState>();

class HomeScreen extends StatefulWidget {
  final String local_id;
  final String userName;
  final String contact_email;
  final String legalType;
  final String userEmail;
  final String userPhone;
  final String userCity;
  final String userState;
  final int age;
  final String userAvatar;
  final bool finished_basic;
  final bool finished_contact;
  final bool finished_professional;
  final bool isActive;
  final String activeMode;
  final Map<String, dynamic> dataWorker;
  final Map<String, dynamic> dataContractor;

  HomeScreen({
  Key? key, // ✅ recebe Key corretamente
  required this.local_id,
  required this.userName,
  required this.userEmail,
  required this.legalType,
  required this.userPhone,
  required this.userCity,
  required this.contact_email,
  required this.userState,
  required this.age,
  required this.userAvatar,
  required this.finished_basic,
  required this.finished_contact,
  required this.finished_professional,
  required this.isActive,
  required this.activeMode,
  required this.dataWorker,
  required this.dataContractor,
}) : super(key: key); 

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ==================== VARIÁVEIS DE ESTADO ====================
  late String _activeMode;
  late String _contactEmail;
  late String _userPhone;
  late String _userName;
  late String _userCity;
  late String _userState;
  late String _userAvatar;
  late int _userAge;
  late String _legalType;
  late String _userEmail;
  late String _company;
  late bool _finishedBasic;
  late bool _finishedContact;
  late bool _finishedProfessional;
  late Map<String, dynamic> _dataWorker;
  late Map<String, dynamic> _dataContractor;

  bool _workerActivated = false;

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  // ==================key navegação de notificação ====================
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // Cache de SearchController para evitar recriação a cada rebuild
  late final search.SearchController _cachedSearchController;

  // ==================== LISTENERS ====================
  StreamSubscription<DatabaseEvent>? _userDataSubscription;

  /// ✅ ÚNICO listener de badge — escuta /badges/{userId}
  /// Cloud Functions mantêm este nó sempre atualizado.
  StreamSubscription<DatabaseEvent>? _badgeSubscription;

  bool _isLoading = true;
  int _selectedIndex = 0;

  // Contadores vindos do backend agregado
  int _unreadChats = 0;
  int _unreadRequests =
      0; // worker = professional requests | contractor = vacancy requests

  // ==================== CICLO DE VIDA ====================

  @override
  void initState() {
    super.initState();
    _cachedSearchController = search.SearchController();
    _initializeVariables();
    _setupRealtimeListener();
    BadgeInitializer.ensureBadgeExists(widget.local_id);
    // Removido: _loadUserData() era duplicado — _setupRealtimeListener já
    // faz o mesmo (onValue listener inclui o snapshot inicial)
    _setupBadgeListener();
    _setupNotificationHandlers(); // ← primeiro registra callbacks locais
    
    _processInitialNotification();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = main_app.appStateKey.currentState;
      if (appState != null) {
        appState.processInitialMessage();
      }
      _checkProfileCompletion();
    });

    _clearAppBadge();
  }

  // Navegando para work profile pelas notificações
  void openWorkerProfileTab() {
    // ✅ Só muda a aba — o VacancyManagement já renderiza
    // o WorkerProfileActivation internamente quando activeMode == worker
    setState(() => _selectedIndex = 3);
  }

  bool _notificationProcessed = false; 
  Future<void> _processInitialNotification() async {
    if (_notificationProcessed) return;
    // ✅ MÉTODO DIRETO - SEM DEPENDÊNCIA
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null && mounted) {
        _notificationProcessed = true;
        debugPrint('🚀 [Home] Notificação detectada DIRETAMENTE!');
        
        final data = initialMessage.data;
        final type = data['type']?.toString() ?? '';
        
        final userRole = _activeMode == 'worker' ? 'employee' : 'contractor';
        
        switch (type) {
          case 'chat':
          case 'chat_accepted':
            final chatId = data['chatId']?.toString() ?? '';
            if (chatId.isNotEmpty) {
              await NotificationNavigationService().navigateToChat(
                context: context,
                chatId: chatId,
                userId: widget.local_id,
                userRole: userRole,
              );
            }
            break;
          case 'request':
            await NotificationNavigationService().navigateToRequest(
              context: context,
              userId: widget.local_id,
              userRole: userRole,
              requestType: data['requestType']?.toString() ?? 'professional',
              profileId: data['profileId']?.toString(),
              vacancyId: data['vacancyId']?.toString(),
            );
            break;
        }
      }
    } catch (e) {
      debugPrint('❌ Erro processar notificação: $e');
    }
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _badgeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _clearAppBadge() async {
    try {
      await NotificationService().clearBadge();
      debugPrint('🧹 Badge do app limpo');
    } catch (e) {
      debugPrint('❌ Erro ao limpar badge: $e');
    }
  }

  // ==================== NOTIFICAÇÕES ====================
  void _setupNotificationHandlers() {
    final service = NotificationService();

    // ✅ Role correto baseado no activeMode do usuário
    final userRole = _activeMode == 'worker' ? 'employee' : 'contractor';

    service.updateCallbacks(
      onChatTap: (chatId, senderId) async {
        service.dismissChatNotifications(chatId);

        if (!mounted) return;

        // ✅ Navega direto para o chat específico
        await NotificationNavigationService().navigateToChat(
          context: context,
          chatId: chatId,
          userId: widget.local_id,
          userRole: userRole,
        );
      },
      onRequestTap: (requestType, profileId, vacancyId) async {
        if (!mounted) return;

        // ✅ Navega para a tela certa baseado no role
        await NotificationNavigationService().navigateToRequest(
          context: context,
          userId: widget.local_id,
          userRole: userRole,
          requestType: requestType ?? '',
          profileId: profileId,
          vacancyId: vacancyId,
        );
      },
    );
  }
  // ==================== 🚀 BADGE OTIMIZADO (1 query) ====================

  /// Escuta apenas /badges/{userId}.
  /// As Cloud Functions calculam e gravam este nó automaticamente.
  void _setupBadgeListener() {
    _badgeSubscription?.cancel();

    _badgeSubscription = _database
        .child('badges')
        .child(widget.local_id)
        .onValue
        .listen((DatabaseEvent event) {
      if (!mounted) return;

      if (event.snapshot.value == null) {
        setState(() {
          _unreadChats = 0;
          _unreadRequests = 0;
        });
        return;
      }

      final data = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );

      setState(() {
        _unreadChats = (data['unread_chats'] as int? ?? 0).clamp(0, 9);
        _unreadRequests = (data['unread_requests'] as int? ?? 0).clamp(0, 9);
      });

      debugPrint(
          '🔔 Badge atualizado — chats:$_unreadChats | requests:$_unreadRequests');
    }, onError: (error) {
      debugPrint('❌ Erro no listener de badge: $error');
    });
  }

  // ==================== INICIALIZAÇÃO ====================

  void _initializeVariables() {
    _activeMode = widget.activeMode.isEmpty ? 'worker' : widget.activeMode;
    _contactEmail = widget.contact_email;
    _userPhone = widget.userPhone;
    _userName = widget.userName;
    _userCity = widget.userCity;
    _userState = widget.userState;
    _userAvatar = widget.userAvatar;
    _userAge = widget.age;
    _legalType = widget.legalType;
    _userEmail = widget.userEmail;
    _finishedBasic = widget.finished_basic;
    _finishedContact = widget.finished_contact;
    _finishedProfessional = widget.finished_professional;
    _dataWorker = Map<String, dynamic>.from(widget.dataWorker);
    _dataContractor = Map<String, dynamic>.from(widget.dataContractor);
    _company = _dataWorker['company'] ?? _dataContractor['company'] ?? '';
  }

  void _setupRealtimeListener() {
    _userDataSubscription =
        _database.child('Users').child(widget.local_id).onValue.listen(
      (DatabaseEvent event) {
        if (event.snapshot.exists && mounted) {
          final data = Map<String, dynamic>.from(
            event.snapshot.value as Map<dynamic, dynamic>,
          );
          _updateAllData(data);
          if (_isLoading) {
            setState(() => _isLoading = false);
          }
        }
      },
      onError: (error) => debugPrint('Erro no listener de usuario: $error'),
    );
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    try {
      setState(() => _isLoading = true);

      final snapshot =
          await _database.child('Users').child(widget.local_id).get();

      if (snapshot.exists && mounted) {
        final data = Map<String, dynamic>.from(
          snapshot.value as Map<dynamic, dynamic>,
        );
        _updateAllData(data);
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateAllData(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      _userName = data['Name'] ?? data['userName'] ?? _userName;
      _contactEmail =
          data['email_contact'] ?? data['contact_email'] ?? _contactEmail;
      _userPhone = data['telefone'] ?? data['userPhone'] ?? _userPhone;
      _userCity = data['city'] ?? data['userCity'] ?? _userCity;
      _userState = data['state'] ?? data['userState'] ?? _userState;
      _userAvatar = data['avatar'] ?? data['userAvatar'] ?? _userAvatar;
      _legalType = data['legalType'] ?? _legalType;
      _activeMode = data['activeMode'] ?? _activeMode;
      _userEmail = data['email'] ?? _userEmail;
      _company = data['company'] ?? _company;

      if (data['age'] != null) {
        _userAge = data['age'] is int
            ? data['age']
            : int.tryParse(data['age'].toString()) ?? _userAge;
      }

      _finishedBasic = data['finished_basic'] ?? _finishedBasic;
      _finishedContact = data['finished_contact'] ?? _finishedContact;
      _finishedProfessional =
          data['finished_professional'] ?? _finishedProfessional;

      if (data['data_worker'] != null) {
        _dataWorker = Map<String, dynamic>.from(data['data_worker'] as Map);
        if (_dataWorker['activated'] == true) _workerActivated = true;
      } else if (data['worker'] != null) {
        _dataWorker = Map<String, dynamic>.from(data['worker'] as Map);
        if (_dataWorker['activated'] == true) _workerActivated = true;
      }

      if (data['data_contractor'] != null) {
        _dataContractor =
            Map<String, dynamic>.from(data['data_contractor'] as Map);
      } else if (data['contractor'] != null) {
        _dataContractor = Map<String, dynamic>.from(data['contractor'] as Map);
      }

      if (_company.isEmpty) {
        _company = _dataWorker['company'] ?? _dataContractor['company'] ?? '';
      }

      _isLoading = false;
    });
  }

  Future<void> reloadData() async {
    debugPrint('🔄 Recarregando dados do Firebase...');
    await _loadUserData();
  }

  // ==================== FUNÇÕES DE PERFIL ====================

  void _checkProfileCompletion() {
    if (!_finishedBasic || !_finishedContact || !_finishedProfessional) {
      _showIncompleteProfileDialog();
    }
  }

  Future<void> _updateActiveMode(String newMode) async {
    try {
      // Atualizar o activeMode no Firebase dispara onActiveModeChanged
      // que recalcula /badges/{userId} automaticamente via Cloud Function
      await _database.child('Users').child(widget.local_id).update({
        'activeMode': newMode,
      });
      debugPrint('✅ Modo atualizado para: $newMode');
    } catch (e) {
      debugPrint('❌ Erro ao atualizar modo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar modo'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void toggleMode() async {
    final newMode = _activeMode == 'worker' ? 'contractor' : 'worker';

    setState(() => _activeMode = newMode);

    // Escreve no Firebase → Cloud Function recalcula badges automaticamente
    // Não há mais necessidade de cancelar/recriar listeners de badge aqui
    await _updateActiveMode(newMode);
    _setupNotificationHandlers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(
                  'Modo: ${newMode == 'worker' ? 'Prestador' : 'Contratante'}'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void editProfile() async {
    final currentData = _activeMode == 'worker' ? _dataWorker : _dataContractor;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          local_id: widget.local_id,
          dataContractor: _dataContractor,
          dataWorker: _dataWorker,
          userName: _userName,
          userEmail: _userEmail,
          contact_email: _contactEmail,
          userPhone: _userPhone,
          userCity: _userCity,
          finished_basic: _finishedBasic,
          finished_professional: _finishedProfessional,
          finished_contact: _finishedContact,
          userAvatar: _userAvatar,
          userState: _userState,
          userAge: _userAge > 0 ? _userAge : (currentData['age'] ?? 0),
          legalType: _legalType,
          company: _company,
          activeMode: _activeMode,
          profession: currentData['profession'] ?? '',
          summary: currentData['summary'] ?? '',
          skills: currentData['skills'] != null
              ? List<String>.from(currentData['skills'])
              : [],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (result['userName'] != null) _userName = result['userName'];
        if (result['userAge'] != null) _userAge = result['userAge'];
        if (result['userCity'] != null) _userCity = result['userCity'];
        if (result['userState'] != null) _userState = result['userState'];
        if (result['userAvatar'] != null) _userAvatar = result['userAvatar'];
        if (result['contact_email'] != null)
          _contactEmail = result['contact_email'];
        if (result['legalType'] != null) _legalType = result['legalType'];
        if (result['company'] != null) _company = result['company'];
        if (result['userPhone'] != null) _userPhone = result['userPhone'];
        if (result['finished_basic'] != null)
          _finishedBasic = result['finished_basic'];
        if (result['finished_contact'] != null)
          _finishedContact = result['finished_contact'];
        if (result['finished_professional'] != null)
          _finishedProfessional = result['finished_professional'];
        if (result['dataWorker'] != null)
          _dataWorker = Map<String, dynamic>.from(result['dataWorker']);
        if (result['dataContractor'] != null)
          _dataContractor = Map<String, dynamic>.from(result['dataContractor']);
      });
    }

    await Future.delayed(Duration(milliseconds: 500));
    await reloadData();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  List<Widget> get _screens => [
        FeedScreen(
          userEmail: _userEmail,
          localId: widget.local_id,
          userPhone: _userPhone,
          userName: _userName,
          legalType: _legalType,
          userCity: _userCity,
          userState: _userState,
          userAvatar: _userAvatar,
          finished_basic: _finishedBasic,
          finished_professional: _finishedProfessional,
          finished_contact: _finishedContact,
          isActive: widget.isActive,
          activeMode: _activeMode,
          dataWorker: _dataWorker,
          dataContractor: _dataContractor,
          onNavigateToVacancies: () => _onItemTapped(3),
        ),
        ChangeNotifierProvider.value(
          value: _cachedSearchController,
          child: const SearchPage(),
        ),
        ChatListScreen(
          userId: widget.local_id,
          userRole: _activeMode == 'worker' ? 'employee' : 'contractor',
        ),
        VacancyManagement(
          userEmail: _userEmail,
          localId: widget.local_id,
          userPhone: _userPhone,
          userName: _userName,
          legalType: _legalType,
          userCity: _userCity,
          userState: _userState,
          userAvatar: _userAvatar,
          finished_basic: _finishedBasic,
          finished_professional: _finishedProfessional,
          finished_contact: _finishedContact,
          isActive: widget.isActive,
          activeMode: _activeMode,
          dataWorker: _dataWorker,
          dataContractor: _dataContractor,
          workerActivated: _workerActivated,
          onWorkerActivated: () => setState(() => _workerActivated = true),
        ),
        _buildProfileScreen(),
      ];

  // ==================== DIALOGS ====================

  void _showIncompleteProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFF6B35), size: 26),
            SizedBox(width: 12),
            Text('Perfil Incompleto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para aproveitar todos os recursos da plataforma, você precisa completar seu perfil.',
              style:
                  TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFFFE8E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFFF6B35), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complete informações como profissão, habilidades e sobre você.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
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
            child: Text('Depois',
                style: TextStyle(color: Colors.grey[600], fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              editProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Completar Agora',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // ==================== WIDGETS AUXILIARES ====================

  Widget _buildContactItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, int count) {
    if (count > 0) {
      return Badge(
        label: Text(count > 9 ? '9+' : '$count'),
        child: Icon(icon),
      );
    }
    return Icon(icon);
  }

  Widget _buildProfileScreen() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final currentData = _activeMode == 'worker' ? _dataWorker : _dataContractor;
    final displayAge = _userAge > 0 ? _userAge : (currentData['age'] ?? 0);
    final company =
        _company.isNotEmpty ? _company : (currentData['company'] ?? '');
    final profession = currentData['profession'] ?? '';
    final summary = currentData['summary'] ?? '';
    final skills = currentData['skills'] != null
        ? List<String>.from(currentData['skills'])
        : <String>[];

    final profileKey =
        '${_userName}_${_activeMode}_${_userPhone}_${_legalType}_${_contactEmail}_$_company';

    return RefreshIndicator(
      color: Colors.blue,
      onRefresh: reloadData,
      child: SingleChildScrollView(
        key: ValueKey(profileKey),
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Toggle Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.lightBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Modo Ativo',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14)),
                          SizedBox(height: 4),
                          Text(
                            _activeMode == 'worker'
                                ? '👷 Prestador'
                                : '👔 Contratante',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: toggleMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Alternar',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    _activeMode == 'worker'
                        ? 'Você está visível como prestador de serviços'
                        : 'Você está visível como contratante',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 13),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Profile Card
            Container(
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
                  Container(
                    height: screenHeight * 0.14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.lightBlue, Colors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -50),
                    child: Column(
                      children: [
                        Container(
                          height: screenHeight * 0.15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue,
                            backgroundImage: _userAvatar.isNotEmpty
                                ? NetworkImage(_userAvatar)
                                : null,
                            child: _userAvatar.isEmpty
                                ? Text(
                                    _userName.isNotEmpty
                                        ? _userName
                                            .substring(0, 1)
                                            .toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  )
                                : null,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(_userName,
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on,
                                size: 16, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text('$_userCity, $_userState',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14)),
                          ],
                        ),
                        SizedBox(height: 20),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              if (displayAge > 0)
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('Idade',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12)),
                                        SizedBox(height: 4),
                                        Text('$displayAge anos',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87)),
                                      ],
                                    ),
                                  ),
                                ),
                              if (displayAge > 0) SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text('Tipo',
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12)),
                                      SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            (_legalType == 'NÃO DEFINIDO' ||
                                                    _legalType == '')
                                                ? 'Não definido'
                                                : _legalType,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_legalType == 'PJ' && company.isNotEmpty) ...[
                          SizedBox(height: 16),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                border: Border.all(color: Colors.blue[100]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.business,
                                        color: Colors.white, size: 20),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Empresa',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                        Text(company,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Contact Info Card
            Container(
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
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informações de Contato',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  SizedBox(height: 16),
                  _buildContactItem(
                    icon: Icons.email,
                    iconColor: Colors.blue,
                    iconBgColor: Colors.blue[50]!,
                    title: 'Email',
                    value:
                        _contactEmail.isEmpty ? 'Não definido' : _contactEmail,
                  ),
                  SizedBox(height: 12),
                  _buildContactItem(
                    icon: Icons.phone,
                    iconColor: Colors.green,
                    iconBgColor: Colors.green[50]!,
                    title: 'Telefone',
                    value: _userPhone.isEmpty ? 'Não definido' : _userPhone,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // About Me
            if (summary.isNotEmpty)
              Container(
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
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Sobre mim',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(summary,
                        style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            height: 1.5)),
                  ],
                ),
              ),

            // Professional Info
            if (profession.isNotEmpty ||
                (_activeMode == 'worker' && skills.isNotEmpty)) ...[
              SizedBox(height: 16),
              Container(
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
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informações Profissionais',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    SizedBox(height: 16),
                    if (profession.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50]!,
                          border: Border.all(color: Colors.blue[50]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.work,
                                  color: Colors.white, size: 22),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Profissão',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                  Text(profession,
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_activeMode == 'worker' && skills.isNotEmpty) ...[
                      if (profession.isNotEmpty) SizedBox(height: 20),
                      Text('Habilidades',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700])),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: skills.map((skill) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50]!,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(skill,
                                style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            SizedBox(height: 16),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await NotificationService().removeToken(user.uid);
                  }

                  NotificationService().updateCallbacks(
                    onChatTap: null,
                    onRequestTap: null,
                  );

                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacementNamed(context, '/LoginScreen');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Sair da Conta',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD PRINCIPAL ====================

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5F0),
      appBar: _selectedIndex == 0
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              automaticallyImplyLeading: false,
              title: Text(
                _selectedIndex == 4
                    ? 'Meu Perfil'
                    : _selectedIndex == 3
                        ? 'Minhas Vagas'
                        : _selectedIndex == 2
                            ? 'Chats'
                            : _selectedIndex == 1
                                ? 'Oportunidades'
                                : 'Buscar Vagas',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
              actions: [
                // ✅ CORREÇÃO: Mostrar menu apenas na tela de perfil (índice 4)
                if (_selectedIndex == 4) ...[
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.black87),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    offset: Offset(0, 50),
                    onSelected: (value) {
                      if (value == 'report_user') {
                        String company = '';
                        if (widget.activeMode == 'worker') {
                          company = widget.dataWorker['company'] ?? '';
                        } else if (widget.activeMode == 'contractor') {
                          company = widget.dataContractor['company'] ?? '';
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchUserToComplaint(
                              UserEmailContact: widget.contact_email,
                              Company: company,
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'report_user',
                        child: Row(
                          children: [
                            Icon(Icons.report_outlined,
                                color: Colors.red, size: 20),
                            SizedBox(width: 12),
                            Text('Denunciar Usuário',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: ElevatedButton.icon(
                      onPressed: editProfile,
                      icon: Icon(Icons.edit, size: 18),
                      label: Text('Editar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'buscar',
          ),
          BottomNavigationBarItem(
            icon: _buildBadgeIcon(Icons.near_me_outlined, _unreadChats),
            label: 'chats',
          ),
          BottomNavigationBarItem(
            icon: _buildBadgeIcon(Icons.male, _unreadRequests),
            label: 'vagas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
