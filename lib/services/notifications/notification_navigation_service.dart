// lib/services/notifications/notification_navigation_service.dart

import 'package:dartobra_new/controllers/chat_controller.dart';
import 'package:dartobra_new/screens/chat/chat_room_screen.dart';
import 'package:dartobra_new/screens/vacancy/vacancy_info_screen.dart';
import 'package:dartobra_new/screens/vacancy/worker_profile_activation_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Serviço centralizado para navegação via notificações.
/// Garante que todas as notificações naveguem corretamente independente
/// do estado do app (foreground/background/terminated).
class NotificationNavigationService {
  static final NotificationNavigationService _instance =
      NotificationNavigationService._internal();
  factory NotificationNavigationService() => _instance;
  NotificationNavigationService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  /// Navega para um chat específico
  /// 
  /// [context] - BuildContext para navegação
  /// [chatId] - ID do chat
  /// [userId] - ID do usuário atual
  /// [userRole] - Role do usuário (contractor/employee)
  Future<void> navigateToChat({
    required BuildContext context,
    required String chatId,
    required String userId,
    required String userRole,
  }) async {
    try {
      debugPrint('📍 Navegando para chat: $chatId | user: $userId | role: $userRole');

      // Busca dados do chat
      final chatSnapshot = await _database.child('Chats/$chatId').get();

      if (!chatSnapshot.exists) {
        debugPrint('❌ Chat não encontrado: $chatId');
        _showErrorSnackBar(context, 'Chat não encontrado');
        return;
      }

      final chatData = Map<String, dynamic>.from(chatSnapshot.value as Map);
      final contractorId = chatData['contractor']?.toString() ?? '';
      final employeeId = chatData['employee']?.toString() ?? '';

      // Determina qual é o outro usuário
      final isContractor = userRole == 'contractor';
      final otherUserId = isContractor ? employeeId : contractorId;

      debugPrint('👥 Outro usuário: $otherUserId');

      // Busca dados do outro usuário
      final userSnapshot = await _database.child('Users/$otherUserId').get();

      if (!userSnapshot.exists) {
        debugPrint('❌ Usuário não encontrado: $otherUserId');
        _showErrorSnackBar(context, 'Usuário não encontrado');
        return;
      }

      final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
      final otherUserName = userData['Name']?.toString() ?? 'Usuário';
      final otherUserAvatar = userData['avatar']?.toString();

      debugPrint('✅ Navegando para ChatRoomScreen');

      // Navega para ChatRoomScreen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => ChatControllerFinal(),
            child: ChatRoomScreen(
              chatId: chatId,
              contractorId: contractorId,
              employeeId: employeeId,
              userRole: userRole,
              userId: userId,
              otherUserName: otherUserName,
              otherUserAvatar: otherUserAvatar,
            ),
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('❌ Erro ao navegar para chat: $e');
      debugPrint('Stack: $stack');
      _showErrorSnackBar(context, 'Erro ao abrir chat');
    }
  }

  /// Navega para a tela de solicitações baseado no role do usuário
  /// 
  /// [context] - BuildContext para navegação
  /// [userId] - ID do usuário atual
  /// [userRole] - Role do usuário (contractor/employee)
  /// [requestType] - Tipo da solicitação (professional/vacancy)
  /// [profileId] - ID do perfil profissional (para worker)
  /// [vacancyId] - ID da vaga (para contractor)
  Future<void> navigateToRequest({
    required BuildContext context,
    required String userId,
    required String userRole,
    required String requestType,
    String? profileId,
    String? vacancyId,
  }) async {
    try {
      debugPrint('📍 Navegando para solicitação:');
      debugPrint('   userId: $userId');
      debugPrint('   userRole: $userRole');
      debugPrint('   requestType: $requestType');
      debugPrint('   profileId: $profileId');
      debugPrint('   vacancyId: $vacancyId');

      if (userRole == 'contractor') {
        await _navigateToVacancyCandidates(
          context: context,
          userId: userId,
          vacancyId: vacancyId,
        );
      } else {
        await _navigateToProfessionalRequests(
          context: context,
          userId: userId,
          profileId: profileId,
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Erro ao navegar para solicitação: $e');
      debugPrint('Stack: $stack');
      _showErrorSnackBar(context, 'Erro ao abrir solicitação');
    }
  }

  /// Navega para InfoVacancy na tab de candidatos (CONTRACTOR)
  Future<void> _navigateToVacancyCandidates({
    required BuildContext context,
    required String userId,
    String? vacancyId,
  }) async {
    if (vacancyId == null || vacancyId.isEmpty) {
      debugPrint('⚠️ vacancyId nulo ou vazio');
      _showErrorSnackBar(context, 'Vaga não especificada');
      return;
    }

    debugPrint('📦 Carregando vaga: $vacancyId');

    final vacancySnapshot = await _database.child('vacancy/$vacancyId').get();

    if (!vacancySnapshot.exists) {
      debugPrint('❌ Vaga não encontrada: $vacancyId');
      _showErrorSnackBar(context, 'Vaga não encontrada');
      return;
    }

    final vacancyData = Map<String, dynamic>.from(vacancySnapshot.value as Map);

    // Busca dados do usuário
    final userSnapshot = await _database.child('Users/$userId').get();

    if (!userSnapshot.exists) {
      debugPrint('❌ Dados do usuário não encontrados');
      _showErrorSnackBar(context, 'Erro ao carregar dados');
      return;
    }

    final userData = Map<String, dynamic>.from(userSnapshot.value as Map);

    debugPrint('✅ Navegando para InfoVacancy (tab candidatos)');

    // Navega para InfoVacancy na tab de candidatos (index 1)
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfoVacancy(
          userPhone: userData['telefone']?.toString() ?? '',
          userEmail: userData['email']?.toString() ?? '',
          legalType: userData['legalType']?.toString() ?? 'PF',
          companyName: vacancyData['company_name']?.toString() ?? '',
          description: vacancyData['description']?.toString() ?? '',
          state: vacancyData['state']?.toString() ?? '',
          city: vacancyData['city']?.toString() ?? '',
          profession: vacancyData['profession']?.toString() ?? '',
          status: vacancyData['status']?.toString() ?? '',
          title: vacancyData['title']?.toString() ?? '',
          salary: vacancyData['salary']?.toString() ?? '',
          salaryType: vacancyData['salary_type']?.toString() ?? '',
          media: vacancyData['midia'] as Map<dynamic, dynamic>?,
          requests: vacancyData['requests'] as List<dynamic>?,
          vacancyId: vacancyId,
          localId: userId,
          initialTabIndex: 1, // ✅ Tab de candidatos
        ),
      ),
    );
  }

  /// Navega para WorkerProfileActivation na tab de solicitações (EMPLOYEE)
  Future<void> _navigateToProfessionalRequests({
    required BuildContext context,
    required String userId,
    String? profileId,
  }) async {
    debugPrint('👷 Carregando perfil worker: $userId');

    final userSnapshot = await _database.child('Users/$userId').get();

    if (!userSnapshot.exists) {
      debugPrint('❌ Dados do usuário não encontrados');
      _showErrorSnackBar(context, 'Erro ao carregar perfil');
      return;
    }

    final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
    final dataWorker = userData['data_worker'] as Map<dynamic, dynamic>? ?? {};

    debugPrint('✅ Navegando para WorkerProfileActivation (tab solicitações)');

    // Navega para WorkerProfileActivation na tab de solicitações (index 0)
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkerProfileActivation(
          userName: userData['Name']?.toString() ?? '',
          userAvatar: userData['avatar']?.toString() ?? '',
          userCity: userData['city']?.toString() ?? '',
          userState: userData['state']?.toString() ?? '',
          legalType: userData['legalType']?.toString() ?? 'PF',
          dataWorker: Map<String, dynamic>.from(dataWorker),
          isActive: userData['isActive'] == true,
          localId: userId,
          onActivated: () {},
          finished_basic: dataWorker['finished_basic'] == true,
          finished_contact: dataWorker['finished_contact'] == true,
          finished_professional: dataWorker['finished_professional'] == true,
          userTelefone: userData['telefone']?.toString() ?? '',
          userEmail: userData['email']?.toString() ?? '',
          onProfileIncomplete: () {},
          initialTabIndex: 0, // ✅ Tab de solicitações
        ),
      ),
    );
  }

  /// Exibe uma mensagem de erro
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}