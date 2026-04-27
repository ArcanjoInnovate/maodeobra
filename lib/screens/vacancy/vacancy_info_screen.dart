// ignore_for_file: unused_import
import 'dart:convert';
import 'package:chewie/chewie.dart';
import 'package:dartobra_new/screens/vacancy/edit_vacancy_info_screen.dart';
import 'package:dartobra_new/services/badge/badge_service.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';
import 'package:dartobra_new/services/vacancy/vacancy_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';


class InfoVacancy extends StatefulWidget {
  final String userPhone;
  final String userEmail;
  final String legalType;
  final String companyName;
  final String description;
  final String state;
  final String city;
  final String profession;
  final String status;
  final String title;
  final String salary;
  final String salaryType;
  final Map<dynamic, dynamic>? media;
  final List<dynamic>? requests;
  final String localId;
  final String vacancyId;

  const InfoVacancy({
    super.key,
    required this.userPhone,
    required this.legalType,
    required this.companyName,
    required this.description,
    required this.state,
    required this.city,
    required this.title,
    required this.profession,
    required this.status,
    required this.salary,
    required this.salaryType,
    this.media,
    this.requests,
    required this.vacancyId,
    required this.userEmail,
    required this.localId,
  });

  @override
  State<InfoVacancy> createState() => _InfoVacancyState();
}

class _InfoVacancyState extends State<InfoVacancy>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final VacancyService _vacancyService = VacancyService();
  final ExpirationService _expirationService = ExpirationService();

  List<Map<String, dynamic>> _candidates = [];
  bool _isLoadingCandidates = false;

  late String _currentStatus;
  late String _currentTitle;
  late String _currentProfession;
  late String _currentDescription;
  late String _currentState;
  late String _currentCity;
  late String _currentSalary;
  late String _currentSalaryType;
  late Map<dynamic, dynamic>? _currentMedia;

  // ── Expiração ──────────────────────────────────────────────────────────────
  String? _expiresAt;
  bool _isExpired = false;
  bool _isNearExpiration = false;
  int _daysLeft = 0;
  bool _isRenewing = false;

  List<String> _images = [];
  List<String> _videos = [];
  bool _hasMedia = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _currentStatus = widget.status;
    _currentTitle = widget.title;
    _currentProfession = widget.profession;
    _currentDescription = widget.description;
    _currentState = widget.state;
    _currentCity = widget.city;
    _currentSalary = widget.salary;
    _currentSalaryType = widget.salaryType;
    _currentMedia = widget.media;

    _loadMedia();
    _loadCandidates();
    _loadExpirationInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🔧 FUNÇÃO AUXILIAR: NORMALIZA REQUESTS (MAP → LIST)
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Converte requests de qualquer formato (Map/List/null) para List<String>
  List<String> _normalizeRequests(dynamic requestsData) {
    if (requestsData == null) return [];
    
    if (requestsData is List) {
      // Já é lista, apenas filtra valores nulos e converte para String
      return requestsData
          .where((item) => item != null && item.toString().isNotEmpty)
          .map((item) => item.toString())
          .toList();
    }
    
    if (requestsData is Map) {
      // É Map (ex: {0: "uid1", 1: "uid2"}) → converte para List
      print('⚠️ requests está como Map, convertendo para List');
      return requestsData.values
          .where((item) => item != null && item.toString().isNotEmpty)
          .map((item) => item.toString())
          .toList();
    }
    
    // Tipo inesperado
    print('⚠️ requests tem tipo inesperado: ${requestsData.runtimeType}');
    return [];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📥 CARREGA CANDIDATOS (VERSÃO CORRIGIDA)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadCandidates() async {
    setState(() => _isLoadingCandidates = true);

    try {
      print('🔍 Carregando candidatos para vaga: ${widget.vacancyId}');
      
      // ✅ LÊ DIRETO DO FIREBASE
      final requestsSnapshot = await _database
          .child('vacancy/${widget.vacancyId}/requests')
          .get();
      
      print('🔍 Requests raw no Firebase: ${requestsSnapshot.value}');
      print('🔍 Tipo: ${requestsSnapshot.value.runtimeType}');
      
      // ✅ NORMALIZA requests (Map ou List → sempre List<String>)
      List<String> requestIds = [];
      if (requestsSnapshot.exists && requestsSnapshot.value != null) {
        requestIds = _normalizeRequests(requestsSnapshot.value);
      }
      
      print('🔍 Request IDs normalizados: $requestIds');
      
      if (requestIds.isEmpty) {
        setState(() {
          _candidates = [];
          _isLoadingCandidates = false;
        });
        return;
      }

      // Carrega dados dos candidatos
      final candidates = await _vacancyService.getCandidates(
        widget.vacancyId,
        requestIds,
      );

      print('✅ ${candidates.length} candidatos carregados');

      if (mounted) {
        setState(() {
          _candidates = candidates;
          _isLoadingCandidates = false;
        });
      }
    } catch (e, stack) {
      print('❌ Erro ao carregar candidatos: $e');
      print('Stack trace: $stack');
      if (mounted) {
        setState(() {
          _candidates = [];
          _isLoadingCandidates = false;
        });
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🔧 REMOVE REQUEST (VERSÃO CORRIGIDA - SEMPRE SALVA COMO LIST)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> remove_request(String uid) async {
    try {
      print('🗑️ Removendo request: $uid');
      
      // Lê estado atual
      final snapshot = await _database
          .child('vacancy/${widget.vacancyId}/requests')
          .get();
      
      List<String> currentRequests = [];
      if (snapshot.exists && snapshot.value != null) {
        currentRequests = _normalizeRequests(snapshot.value);
      }
      
      print('📋 Requests antes da remoção: $currentRequests');
      
      // Remove o UID
      currentRequests.remove(uid);
      
      print('📋 Requests após remoção: $currentRequests');
      
      // ✅ SALVA COMO LIST VERDADEIRA (não Map!)
      if (currentRequests.isEmpty) {
        await _database
            .child('vacancy/${widget.vacancyId}/requests')
            .remove();
        print('✅ Lista vazia - nó removido');
      } else {
        // Força salvar como array JSON
        await _database
            .child('vacancy/${widget.vacancyId}/requests')
            .set(currentRequests);
        print('✅ Requests salvos como lista: $currentRequests');
      }

      setState(() {
        _candidates.removeWhere((c) => c['uid'] == uid);
      });
    } catch (e, stack) {
      print('❌ Erro ao remover request: $e');
      print('Stack trace: $stack');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ❌ RECUSAR CANDIDATO (VERSÃO CORRIGIDA)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _rejectCandidate(String uid) async {
    try {
      print('❌ Recusando candidato: $uid');
      
      // Remove das requests (usando função corrigida)
      await remove_request(uid);

      // Remove views
      await _database
          .child('vacancy/${widget.vacancyId}/views/request_views/$uid')
          .remove();

      // Decrementa badge
      await BadgeHelper.decrementRequestBadge(widget.localId);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Candidato recusado'),
        backgroundColor: Colors.red,
      ));
    } catch (e) {
      print('❌ Erro ao recusar: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ APROVAR CANDIDATO (MANTIDO IGUAL)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _approveCandidate(String employeeUid) async {
    try {
      // ✅ VERIFICA SE JÁ EXISTE CHAT ENTRE CONTRATANTE E FUNCIONÁRIO
      final chatsSnapshot = await _database.child('Chats').get();
      
      if (chatsSnapshot.exists && chatsSnapshot.value != null) {
        final chatsData = chatsSnapshot.value as Map<dynamic, dynamic>;
        
        // Procura por chat existente com esses participantes
        bool chatExists = false;
        for (var chatEntry in chatsData.entries) {
          final chatData = chatEntry.value as Map<dynamic, dynamic>;
          final contractor = chatData['contractor']?.toString();
          final employee = chatData['employee']?.toString();
          
          if (contractor == widget.localId && employee == employeeUid) {
            chatExists = true;
            break;
          }
        }
        
        // ❌ SE JÁ EXISTE CHAT, RECUSA AUTOMATICAMENTE
        if (chatExists) {
          await _rejectCandidate(employeeUid);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Candidato recusado: já existe chat com este usuário',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 4),
            ));
          }
          return;
        }
      }
      
      // ✅ SE NÃO EXISTE CHAT, CRIA NORMALMENTE
      final DatabaseReference chatRef = _database.child('Chats').push();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await chatRef.set({
        'contractor': widget.localId,
        'employee': employeeUid,
        'participants': {
          'contractor': 'offline',
          'employee': 'offline',
        },
        'metadata': {
          'created_at': timestamp,
          'last_message': '',
          'last_sender': '',
          'last_timestamp': timestamp,
        },
        'historical_messages': {
          'messages': {'init': true}
        },
        'unreadCount': {
          'contractor': 0,
          'employee': 0,
        }
      });

      await _database
          .child('vacancy/${widget.vacancyId}/views/request_views/$employeeUid')
          .remove();

      await remove_request(employeeUid);
      await BadgeHelper.decrementRequestBadge(widget.localId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Chat iniciado com sucesso!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      print('❌ Erro ao aprovar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Erro ao processar candidato'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESTANTE DO CÓDIGO (MANTIDO IGUAL)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadExpirationInfo() async {
    try {
      final snapshot = await _database.child('vacancy/${widget.vacancyId}').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final expiresAt = data['expires_at']?.toString();

      if (mounted) {
        setState(() {
          _expiresAt = expiresAt;
          _isExpired = _expirationService.isExpired(expiresAt);
          _isNearExpiration = _expirationService.isNearExpiration(expiresAt);
          _daysLeft = _expirationService.daysUntilExpiration(expiresAt);
          if (data['status']?.toString().toLowerCase() == 'expirada') {
            _currentStatus = 'Expirada';
          }
        });
      }
    } catch (e) {
      debugPrint('❌ _loadExpirationInfo erro: $e');
    }
  }

  Future<void> _renewVacancy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded, color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Renovar Vaga', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'Deseja renovar esta vaga por mais 2 dias?\nEla continuará visível para candidatos.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Renovar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRenewing = true);

    final success = await _vacancyService.renewVacancy(widget.vacancyId);

    if (mounted) {
      setState(() => _isRenewing = false);

      if (success) {
        await _loadExpirationInfo();
        if (_currentStatus.toLowerCase() == 'expirada') {
          setState(() => _currentStatus = 'Aberta');
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Vaga renovada! Válida por mais $_daysLeft dias.'),
          ]),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.error_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Erro ao renovar vaga. Tente novamente.'),
          ]),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  Future<void> _reloadVacancyData() async {
    try {
      final snapshot = await _database.child('vacancy/${widget.vacancyId}').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        setState(() {
          _currentTitle = data['title'] ?? widget.title;
          _currentProfession = data['profession'] ?? widget.profession;
          _currentDescription = data['description'] ?? widget.description;
          _currentState = data['state'] ?? widget.state;
          _currentCity = data['city'] ?? widget.city;
          _currentSalary = data['salary'] ?? widget.salary;
          _currentSalaryType = data['salary_type'] ?? widget.salaryType;
          _currentStatus = data['status'] ?? widget.status;
          _currentMedia = data['midia'];

          _expiresAt = data['expires_at']?.toString();
          _isExpired = _expirationService.isExpired(_expiresAt);
          _isNearExpiration = _expirationService.isNearExpiration(_expiresAt);
          _daysLeft = _expirationService.daysUntilExpiration(_expiresAt);

          _images.clear();
          _videos.clear();
          _loadMedia();
        });

        print('✅ Dados da vaga recarregados');
      }
    } catch (e) {
      print('❌ Erro ao recarregar: $e');
    }
  }

  void _loadMedia() {
    if (_currentMedia != null) {
      if (_currentMedia!['images'] != null) {
        final imagesList = _currentMedia!['images'] as List;
        _images = imagesList.map((e) => e.toString()).toList();
      }

      if (_currentMedia!['videos'] != null) {
        final videosList = _currentMedia!['videos'] as List;
        _videos = videosList.map((e) => e.toString()).toList();
      }

      _hasMedia = _images.isNotEmpty || _videos.isNotEmpty;
    }
  }

  Future<void> _toggleVacancyStatus() async {
    if (_isExpired || _currentStatus.toLowerCase() == 'expirada') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  'Vaga expirada',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Esta vaga está expirada e não pode ser pausada ou reativada.\n\n'
            'Renove-a primeiro para voltar a gerenciar o status.',
            style: TextStyle(fontSize: 14, height: 1.55),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Agora não',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _renewVacancy();
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
      return;
    }

    try {
      String newStatus = _currentStatus == 'Pausada' ? 'Aberta' : 'Pausada';

      await _vacancyService.updateVacancy(widget.vacancyId, {
        'status': newStatus,
      });

      setState(() => _currentStatus = newStatus);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newStatus == 'Pausada'
            ? 'Vaga pausada com sucesso'
            : 'Vaga reativada com sucesso'),
        backgroundColor:
            newStatus == 'Pausada' ? Colors.orange : Colors.green,
      ));
    } catch (e) {
      print('Erro ao atualizar status: $e');
    }
  }

  Future<void> _deleteVacancy() async {
    try {
      if (_currentMedia != null) {
        if (_currentMedia!['images'] != null) {
          List<dynamic> images = _currentMedia!['images'];
          for (var imageUrl in images) {
            await _deleteFromCloudinary(imageUrl, 'image');
          }
        }

        if (_currentMedia!['videos'] != null) {
          List<dynamic> videos = _currentMedia!['videos'];
          for (var videoUrl in videos) {
            await _deleteFromCloudinary(videoUrl, 'video');
          }
        }
      }

      int unreadCandidates = 0;
      try {
        final requestViewsSnap = await _database
            .child('vacancy/${widget.vacancyId}/views/request_views')
            .get();

        if (requestViewsSnap.exists) {
          final views = Map<String, dynamic>.from(requestViewsSnap.value as Map);
          for (final entry in views.values) {
            final viewData = Map<String, dynamic>.from(entry as Map);
            if (viewData['viewed_by_owner'] == false) {
              unreadCandidates++;
            }
          }
        }
      } catch (e) {
        print('⚠️ Erro ao contar candidatos não lidos: $e');
      }

      await _database.child('vacancy/${widget.vacancyId}').remove();

      for (int i = 0; i < unreadCandidates; i++) {
        await BadgeHelper.decrementRequestBadge(widget.localId);
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vaga excluída com sucesso'),
        backgroundColor: Colors.green,
      ));

      Navigator.pop(context);
    } catch (e) {
      print('Erro ao excluir vaga: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro ao excluir vaga'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _deleteFromCloudinary(String mediaUrl, String resourceType) async {
    try {
      Uri uri = Uri.parse(mediaUrl);
      List<String> pathSegments = uri.pathSegments;

      int uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 2 >= pathSegments.length) return;

      String publicIdWithExtension = pathSegments.sublist(uploadIndex + 2).join('/');
      String publicId = publicIdWithExtension.substring(0, publicIdWithExtension.lastIndexOf('.'));

      const String cloudName = 'dsmgwupky';
      const String apiKey = '256987432736353';
      const String apiSecret = 'K8oSFMvqA6N2eU4zLTnLTVuArMU';

      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();

      String toSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      String signature = sha1.convert(utf8.encode(toSign)).toString();

      await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/destroy'),
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': timestamp.toString(),
          'signature': signature,
        },
      );
    } catch (e) {
      print('Erro ao deletar do Cloudinary: $e');
    }
  }

  void _showImageFullScreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
        ),
      ),
    );
  }

  void _showVideoFullScreen(String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoUrl: videoUrl)),
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[50],
    appBar: AppBar(
      title: const Text('Detalhes da Vaga', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.blue,
            indicatorWeight: 3,
            tabs: [
              const Tab(
                icon: Icon(Icons.info_outline, size: 20),
                text: 'Informações',
              ),
              Tab(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Conteúdo principal do tab
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.people_outline, size: 20),
                        SizedBox(height: 4),
                        Text('Candidatos', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    // Badge flutuante
                    if (_candidates.isNotEmpty)
                      Positioned(
                        top: -2,
                        right: -12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            _candidates.length > 99 ? '99+' : '${_candidates.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [_buildInfoTab(), _buildCandidatesTab()],
    ),
  );
}

  Widget _buildExpirationBanner() {
    if (_expiresAt == null || _expiresAt!.isEmpty) return const SizedBox.shrink();
    if (!_isExpired && !_isNearExpiration) return const SizedBox.shrink();
 
    final bool expired = _isExpired || _currentStatus.toLowerCase() == 'expirada';
 
    final Color accent = expired ? const Color(0xFFDC2626) : const Color(0xFFEA580C);
    final Color bgColor = expired ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED);
    final Color borderColor = accent.withOpacity(0.30);
 
    final String headline = expired
        ? 'Esta vaga expirou'
        : _daysLeft == 1
            ? 'Expira amanhã!'
            : 'Expira em $_daysLeft dias';
 
    final String sub = expired
        ? 'Ela não aparece mais para candidatos. Renove para reativar.'
        : 'Renove agora para não perder visibilidade e candidatos.';
 
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
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
                    expired ? Icons.timer_off_rounded : Icons.hourglass_bottom_rounded,
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
                          letterSpacing: -0.2,
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
          Divider(height: 1, color: borderColor),
          InkWell(
            onTap: _isRenewing ? null : _renewVacancy,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _isRenewing
                    ? [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Renovando…',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ]
                    : [
                        Icon(Icons.refresh_rounded, size: 17, color: accent),
                        const SizedBox(width: 8),
                        Text(
                          expired
                              ? 'Renovar e reativar vaga por 2 dias'
                              : 'Renovar agora (+2 dias)',
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

  Widget _buildInfoTab() {
    final bool isExpiredOrNear =
        _isExpired || _isNearExpiration || _currentStatus.toLowerCase() == 'expirada';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isExpiredOrNear
                    ? [Colors.orange.shade700, Colors.orange.shade400]
                    : [Colors.blue, Colors.lightBlue],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Vaga $_currentStatus',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _currentProfession,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '$_currentCity, $_currentState',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
                if (_expiresAt != null && _expiresAt!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
                        size: 14,
                        color: Colors.white.withOpacity(0.85),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isExpired
                            ? 'Expirada'
                            : _isNearExpiration
                                ? 'Expira em $_daysLeft ${_daysLeft == 1 ? 'dia' : 'dias'}'
                                : 'Válida por mais $_daysLeft dias',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _buildExpirationBanner(),
          if (_hasMedia)
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _images.length + _videos.length,
                itemBuilder: (context, index) {
                  if (index < _images.length) {
                    final imageUrl = _images[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _showImageFullScreen(imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            width: 160,
                            height: 188,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 160,
                              height: 188,
                              color: Colors.grey[300],
                              child: Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    final videoIndex = index - _images.length;
                    final videoUrl = _videos[videoIndex];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _showVideoFullScreen(videoUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 160,
                            height: 188,
                            color: Colors.black87,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(Icons.videocam, size: 48, color: Colors.white.withOpacity(0.7)),
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow, size: 32, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: 'Descrição da Vaga',
                  icon: Icons.description,
                  content: Text(
                    _currentDescription,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Salário',
                  icon: Icons.attach_money,
                  content: Column(children: [
                    _buildInfoRow('Valor', _currentSalary),
                    const SizedBox(height: 12),
                    _buildInfoRow('Frequência', _currentSalaryType),
                  ]),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Informações do Contratante',
                  icon: Icons.business,
                  content: Column(children: [
                    if (widget.companyName.isNotEmpty) ...[
                      _buildInfoRow('Empresa', widget.companyName),
                      const SizedBox(height: 12),
                    ],
                    _buildInfoRow(
                      'Tipo',
                      widget.legalType == 'pj' ? 'Pessoa Jurídica (PJ)' : 'Pessoa Física (PF)',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Email', widget.userEmail),
                    const SizedBox(height: 12),
                    _buildInfoRow('Telefone', widget.userPhone),
                  ]),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isExpired
                          ? null
                          : () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditInfoVacancy(
                                    isEditing: true,
                                    localId: widget.localId,
                                    emailContact: widget.userEmail,
                                    phoneContact: widget.userPhone,
                                    vacancyId: widget.vacancyId,
                                    existingTitle: _currentTitle,
                                    existingProfession: _currentProfession,
                                    existingDescription: _currentDescription,
                                    existingState: _currentState,
                                    existingCity: _currentCity,
                                    existingSalary: _currentSalary,
                                    existingSalaryType: _currentSalaryType,
                                    existingMedia: _currentMedia,
                                  ),
                                ),
                              );
                              if (result == true) await _reloadVacancyData();
                            },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleVacancyStatus,
                      icon: Icon(
                        _currentStatus == 'Pausada' ? Icons.play_circle : Icons.pause_circle,
                        size: 18,
                      ),
                      label: Text(_currentStatus == 'Pausada' ? 'Reativar' : 'Pausar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isExpired
                            ? Colors.grey.shade400
                            : (_currentStatus == 'Pausada' ? Colors.green : Colors.orange),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                if (_isExpired || _isNearExpiration || _currentStatus.toLowerCase() == 'expirada') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isRenewing ? null : _renewVacancy,
                      icon: _isRenewing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _isRenewing
                            ? 'Renovando...'
                            : _isExpired
                                ? 'Renovar Vaga (Reativar por 2 dias)'
                                : 'Renovar Vaga (+2 dias)',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Excluir vaga'),
                          content: const Text(
                              'Tem certeza que deseja excluir esta vaga? Esta ação não pode ser desfeita.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteVacancy();
                              },
                              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Excluir Vaga'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.people, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                '${_candidates.length} ${_candidates.length == 1 ? 'candidato' : 'candidatos'}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_candidates.length} pendentes',
                  style: TextStyle(
                      color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingCandidates
              ? const Center(child: CircularProgressIndicator(color: Colors.blue))
              : _candidates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('Nenhum candidato ainda',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text('Os candidatos aparecerão aqui',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _candidates.length,
                      itemBuilder: (context, index) => _buildCandidateCard(_candidates[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildCandidateCard(Map<String, dynamic> candidate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1),
                  backgroundImage: candidate['avatar'] != null ? NetworkImage(candidate['avatar']) : null,
                  child: candidate['avatar'] == null
                      ? Text(
                          candidate['name'][0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(candidate['name'],
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(candidate['phone'],
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration:
                      BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
                  child: Text('Pendente',
                      style: TextStyle(
                          color: Colors.orange[700], fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text('${candidate['city']}, ${candidate['state']}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Recusar candidato'),
                          content: const Text('Tem certeza que deseja recusar este candidato?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _rejectCandidate(candidate['uid']);
                              },
                              child: const Text('Recusar', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Recusar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveCandidate(candidate['uid']),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Aprovar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
      );
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Vídeo')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Color(0xFFFF6B35))
            : _hasError
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text('Erro ao carregar vídeo',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  )
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const SizedBox(),
      ),
    );
  }
}
