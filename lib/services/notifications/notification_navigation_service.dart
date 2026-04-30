import 'package:dartobra_new/controllers/chat_controller.dart';
import 'package:dartobra_new/screens/chat/chat_room_screen.dart';
import 'package:dartobra_new/screens/home/home_screen.dart';
import 'package:dartobra_new/screens/vacancy/vacancy_info_screen.dart';
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
  // HELPER — limpa a pilha até a primeira rota e empurra a nova tela.
  //
  // Isso evita o bug onde várias notificações empilham telas repetidas.
  // Após o pop a pilha fica com apenas a rota raiz (home/splash), e a nova
  // tela entra limpa.
  // ══════════════════════════════════════════════════════════════════════════

  void _pushClean(BuildContext context, WidgetBuilder builder) {
    // Remove todas as rotas acima da primeira (index == 0),
    // que é a home/splash. Depois faz push da nova tela.
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(builder: builder),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1️⃣  NAVEGAR PARA CHAT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> navigateToChat({
    required BuildContext context,
    required String chatId,
    required String userId,
    required String userRole,
  }) async {
    try {
      print(
          '🔔 navigateToChat | chatId=$chatId | userId=$userId | role=$userRole');

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

      String resolvedRole;
      if (userId == contractorId) {
        resolvedRole = 'contractor';
      } else if (userId == employeeId) {
        resolvedRole = 'employee';
      } else {
        resolvedRole = userRole;
      }

      final otherUserId =
          resolvedRole == 'contractor' ? employeeId : contractorId;

      String otherUserName = 'Usuário';
      String? otherUserAvatar;

      final otherUserSnap = await _database.child('Users/$otherUserId').get();
      if (otherUserSnap.exists && otherUserSnap.value != null) {
        final otherUserData =
            Map<String, dynamic>.from(otherUserSnap.value as Map);
        otherUserName = otherUserData['Name']?.toString() ?? 'Usuário';
        otherUserAvatar = otherUserData['avatar']?.toString();
      }

      if (!context.mounted) return;

      // ✅ FIX: usa _pushClean para não empilhar sobre outra ChatRoomScreen
      _pushClean(
        context,
        (_) => ChangeNotifierProvider(
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
      print(
          '🔔 navigateToRequest | type=$requestType | profileId=$profileId | vacancyId=$vacancyId | role=$userRole');

      if (requestType == 'vacancy_request' &&
          vacancyId != null &&
          vacancyId.isNotEmpty) {
        await _navigateToInfoVacancy(context, vacancyId, userId);
      } else if (requestType == 'professional' &&
          profileId != null &&
          profileId.isNotEmpty) {
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
    final vacancySnap = await _database.child('vacancy/$vacancyId').get();
    if (!vacancySnap.exists || vacancySnap.value == null) {
      print('⚠️ Vaga $vacancyId não encontrada');
      if (context.mounted) _showSnack(context, 'Vaga não encontrada');
      return;
    }

    final vacancyData = Map<String, dynamic>.from(vacancySnap.value as Map);
    final localId = vacancyData['local_id']?.toString() ?? userId;

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

    List<dynamic>? requests;
    final rawRequests = vacancyData['requests'];
    if (rawRequests is List) {
      requests = rawRequests;
    } else if (rawRequests is Map) {
      requests = rawRequests.values.toList();
    }

    Map<dynamic, dynamic>? media;
    if (vacancyData['midia'] != null) {
      media = Map<dynamic, dynamic>.from(vacancyData['midia'] as Map);
    }

    if (!context.mounted) return;

    // ✅ FIX: popUntil + push — nunca empilha duas InfoVacancy
    _pushClean(
      context,
      (_) => InfoVacancy(
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
        initialTabIndex: 1,
      ),
    );

    print('✅ Navegou para InfoVacancy: $vacancyId (tab Candidatos)');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER — WorkerProfileActivation (Worker/Employee)
  //
  // PROBLEMA ORIGINAL: WorkerProfileActivation é renderizado dentro do
  // build() do VacancyManagement — não existe como rota independente.
  // Por isso o Navigator.push anterior não funcionava: a tela montava
  // mas sem o contexto de providers e state que o VacancyManagement fornece.
  //
  // SOLUÇÃO: Buscamos todos os dados do usuário e abrimos
  // WorkerProfileActivation diretamente como rota standalone,
  // fornecendo todos os parâmetros necessários explicitamente.
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _navigateToWorkerProfile(
    BuildContext context,
    String userId,
  ) async {
    print('🔔 _navigateToWorkerProfile: $userId');

    for (int i = 0; i < 20; i++) {
      // ✅ Acessa currentState AQUI dentro, a cada tentativa
      final state = homeScreenKey.currentState;
      if (state != null && state.mounted) {
        print('✅ HomeScreen encontrada na tentativa ${i + 1}');
        state.openWorkerProfileTab();
        return;
      }
      print('⏳ Tentativa ${i + 1}: HomeScreen não montada ainda...');
      await Future.delayed(const Duration(milliseconds: 300));
    }

    print('⚠️ HomeScreen não encontrada após 20 tentativas');
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
