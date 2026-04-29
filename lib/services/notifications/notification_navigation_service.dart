import 'package:dartobra_new/controllers/chat_controller.dart';
import 'package:dartobra_new/screens/chat/chat_room_screen.dart';
import 'package:dartobra_new/screens/vacancy/vacancy_info_screen.dart';
import 'package:dartobra_new/screens/vacancy/worker_profile_activation_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NotificationNavigationService {
  static final NotificationNavigationService _instance =
      NotificationNavigationService._internal();
  factory NotificationNavigationService() => _instance;
  NotificationNavigationService._internal();
 
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
 
  // ══════════════════════════════════════════════════════════════════════════
  // 1️⃣  NAVEGAR PARA CHAT
  //
  //  Busca os dados do Chat (contractor, employee) e do outro usuário
  //  no Firebase, depois abre ChatRoomScreen com tudo preenchido.
  // ══════════════════════════════════════════════════════════════════════════
 
  Future<void> navigateToChat({
    required BuildContext context,
    required String chatId,
    required String userId,
    required String userRole,
  }) async {
    try {
      print('🔔 navigateToChat | chatId=$chatId | userId=$userId | role=$userRole');
 
      // 1. Buscar dados do chat
      final chatSnap = await _database.child('Chats/$chatId').get();
      if (!chatSnap.exists || chatSnap.value == null) {
        print('⚠️ Chat $chatId não encontrado');
        _showSnack(context, 'Chat não encontrado');
        return;
      }
 
      final chatData = Map<String, dynamic>.from(chatSnap.value as Map);
      final contractorId = chatData['contractor']?.toString() ?? '';
      final employeeId = chatData['employee']?.toString() ?? '';
 
      if (contractorId.isEmpty || employeeId.isEmpty) {
        print('⚠️ Chat $chatId sem contractor/employee');
        _showSnack(context, 'Dados do chat incompletos');
        return;
      }
 
      // 2. Determinar o papel correto do usuário neste chat
      String resolvedRole;
      if (userId == contractorId) {
        resolvedRole = 'contractor';
      } else if (userId == employeeId) {
        resolvedRole = 'employee';
      } else {
        resolvedRole = userRole;
      }
 
      // 3. Determinar o outro usuário
      final otherUserId =
          resolvedRole == 'contractor' ? employeeId : contractorId;
 
      // 4. Buscar nome e avatar do outro usuário
      String otherUserName = 'Usuário';
      String? otherUserAvatar;
 
      final otherUserSnap = await _database.child('Users/$otherUserId').get();
      if (otherUserSnap.exists && otherUserSnap.value != null) {
        final otherUserData =
            Map<String, dynamic>.from(otherUserSnap.value as Map);
        otherUserName = otherUserData['Name']?.toString() ?? 'Usuário';
        otherUserAvatar = otherUserData['avatar']?.toString();
      }
 
      // 5. Navegar para ChatRoomScreen
      if (!context.mounted) return;
 
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => ChatControllerFinal(),
            child: ChatRoomScreen(
              chatId: chatId,
              contractorId: contractorId,
              employeeId: employeeId,
              userId: userId,
              userRole: resolvedRole,
              otherUserName: otherUserName,
              otherUserAvatar: otherUserAvatar,
            ),
          ),
        ),
      );
 
      print('✅ Navegou para ChatRoomScreen: $chatId');
    } catch (e) {
      print('❌ Erro navigateToChat: $e');
      if (context.mounted) {
        _showSnack(context, 'Erro ao abrir chat');
      }
    }
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  // 2️⃣  NAVEGAR PARA REQUEST
  //
  //  • Contractor recebe candidatura na vaga → abre InfoVacancy (tab 1)
  //  • Worker recebe solicitação de chat   → abre WorkerProfileActivation
  // ══════════════════════════════════════════════════════════════════════════
 
  Future<void> navigateToRequest({
    required BuildContext context,
    required String userId,
    required String userRole,
    required String requestType,
    String? profileId,
    String? vacancyId,
  }) async {
    try {
      print('🔔 navigateToRequest | type=$requestType | profileId=$profileId | vacancyId=$vacancyId | role=$userRole');
 
      if (requestType == 'vacancy_request' && vacancyId != null && vacancyId.isNotEmpty) {
        // ── CONTRACTOR: abrir InfoVacancy na tab Candidatos ──────────────
        await _navigateToInfoVacancy(context, vacancyId, userId);
      } else if (requestType == 'professional' && profileId != null && profileId.isNotEmpty) {
        // ── WORKER: abrir WorkerProfileActivation ────────────────────────
        await _navigateToWorkerProfile(context, userId);
      } else {
        print('⚠️ requestType desconhecido ou faltando IDs: $requestType');
        _showSnack(context, 'Não foi possível abrir a solicitação');
      }
    } catch (e) {
      print('❌ Erro navigateToRequest: $e');
      if (context.mounted) {
        _showSnack(context, 'Erro ao abrir solicitação');
      }
    }
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  // HELPER — InfoVacancy (Contractor)
  // ══════════════════════════════════════════════════════════════════════════
 
  Future<void> _navigateToInfoVacancy(
    BuildContext context,
    String vacancyId,
    String userId,
  ) async {
    // 1. Buscar dados da vaga
    final vacancySnap = await _database.child('vacancy/$vacancyId').get();
    if (!vacancySnap.exists || vacancySnap.value == null) {
      print('⚠️ Vaga $vacancyId não encontrada');
      if (context.mounted) _showSnack(context, 'Vaga não encontrada');
      return;
    }
 
    final vacancyData = Map<String, dynamic>.from(vacancySnap.value as Map);
    final localId = vacancyData['local_id']?.toString() ?? userId;
 
    // 2. Buscar dados do dono da vaga para legalType e companyName
    String legalType = 'PF';
    String companyName = '';
    final ownerSnap = await _database.child('Users/$localId').get();
    if (ownerSnap.exists && ownerSnap.value != null) {
      final ownerData = Map<String, dynamic>.from(ownerSnap.value as Map);
      legalType = ownerData['legalType']?.toString() ?? 'PF';
      if (ownerData['data_contractor'] != null) {
        final contractorData =
            Map<String, dynamic>.from(ownerData['data_contractor'] as Map);
        companyName = contractorData['company']?.toString() ?? '';
      }
    }
 
    // 3. Preparar requests como List<dynamic>
    List<dynamic>? requests;
    final rawRequests = vacancyData['requests'];
    if (rawRequests is List) {
      requests = rawRequests;
    } else if (rawRequests is Map) {
      requests = rawRequests.values.toList();
    }
 
    // 4. Preparar media
    Map<dynamic, dynamic>? media;
    if (vacancyData['midia'] != null) {
      media = Map<dynamic, dynamic>.from(vacancyData['midia'] as Map);
    }
 
    if (!context.mounted) return;
 
    // 5. Navegar para InfoVacancy com initialTabIndex = 1 (Candidatos)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InfoVacancy(
          userPhone: vacancyData['phone_contact']?.toString() ?? '',
          userEmail: vacancyData['email_contact']?.toString() ?? '',
          legalType: legalType,
          companyName: companyName,
          description: vacancyData['description']?.toString() ?? '',
          state: vacancyData['state']?.toString() ?? '',
          city: vacancyData['city']?.toString() ?? '',
          profession: vacancyData['profession']?.toString() ?? '',
          status: vacancyData['status']?.toString() ?? '',
          title: vacancyData['title']?.toString() ?? '',
          salary: vacancyData['salary']?.toString() ?? '',
          salaryType: vacancyData['salary_type']?.toString() ?? '',
          media: media,
          requests: requests,
          vacancyId: vacancyId,
          localId: localId,
          initialTabIndex: 1, // ✅ Abre direto na tab de Candidatos
        ),
      ),
    );
 
    print('✅ Navegou para InfoVacancy: $vacancyId (tab Candidatos)');
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  // HELPER — WorkerProfileActivation (Worker/Employee)
  // ══════════════════════════════════════════════════════════════════════════
 
  Future<void> _navigateToWorkerProfile(
    BuildContext context,
    String userId,
  ) async {
    // 1. Buscar dados do usuário
    final userSnap = await _database.child('Users/$userId').get();
    if (!userSnap.exists || userSnap.value == null) {
      print('⚠️ Usuário $userId não encontrado');
      if (context.mounted) _showSnack(context, 'Dados do perfil não encontrados');
      return;
    }
 
    final userData = Map<String, dynamic>.from(userSnap.value as Map);
 
    // 2. Extrair data_worker
    Map<String, dynamic> dataWorker = {};
    if (userData['data_worker'] != null) {
      dataWorker = Map<String, dynamic>.from(userData['data_worker'] as Map);
    }
 
    if (!context.mounted) return;
 
    // 3. Navegar para WorkerProfileActivation (tab Solicitações = 0)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerProfileActivation(
          userName: userData['Name']?.toString() ?? 'Usuário',
          userAvatar: userData['avatar']?.toString() ?? '',
          userCity: userData['city']?.toString() ?? '',
          userState: userData['state']?.toString() ?? '',
          userEmail: userData['email_contact']?.toString() ?? userData['email']?.toString() ?? '',
          userTelefone: userData['telefone']?.toString() ?? '',
          legalType: userData['legalType']?.toString() ?? 'PF',
          dataWorker: dataWorker,
          isActive: userData['isActive'] == true,
          localId: userId,
          finished_basic: userData['finished_basic'] == true,
          finished_contact: userData['finished_contact'] == true,
          finished_professional: userData['finished_professional'] == true,
          onActivated: () {},
          onProfileIncomplete: () {},
          initialTabIndex: 0, // ✅ Tab Solicitações
        ),
      ),
    );
 
    print('✅ Navegou para WorkerProfileActivation: $userId (tab Solicitações)');
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  // HELPER — SnackBar
  // ══════════════════════════════════════════════════════════════════════════
 
  void _showSnack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}