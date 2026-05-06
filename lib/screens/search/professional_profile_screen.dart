import 'dart:async';
import 'dart:ui';

import 'package:dartobra_new/controllers/chat_controller.dart';
import 'package:dartobra_new/controllers/feed_controller.dart';
import 'package:dartobra_new/controllers/search_controller.dart' as search;
import 'package:dartobra_new/core/providers/block_provider.dart';
import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/screens/chat/chat_room_screen.dart';
import 'package:dartobra_new/screens/complaints/complaint_professional_screen.dart';
import 'package:dartobra_new/services/chat/user_lookup_service.dart';
import 'package:dartobra_new/services/vacancy/profile_validation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ProfessionalProfilePage extends StatefulWidget {
  final ProfessionalModel professional;
  final String vacancyId;
  final String reportId;
  final String reportedId;

  const ProfessionalProfilePage({
    super.key,
    required this.professional,
    required this.vacancyId,
    required this.reportId,
    required this.reportedId,
  });

  @override
  State<ProfessionalProfilePage> createState() =>
      _ProfessionalProfilePageState();
}

class _ProfessionalProfilePageState extends State<ProfessionalProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _contentCtrl;
  late AnimationController _avatarCtrl;
  late Animation<double> _heroScale;
  late Animation<double> _heroOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentOpacity;
  late Animation<double> _avatarScale;

  // Paleta azul — telas de terceiros
  static const Color _blue = Color(0xFF2563EB);
  static const Color _blueLight = Color(0xFF3B82F6);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  // ID do dono do perfil
  String get ownerLocalId => widget.professional.localId;
  final FeedController feedController = FeedController();
  final searchController = search.SearchController();

  bool _isRequesting = false;
  bool _hasAlreadyRequested = false;

  // ── Verificação de chat existente ──────────────────────────────────────
  bool _isCheckingChat = true;
  String? _existingChatId;
  String? _ownerRole;
  String? _myRole;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _avatarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _heroScale = Tween<double>(begin: 1.08, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));
    _heroOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: const Interval(0.0, 0.6)));
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));
    _avatarScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _avatarCtrl, curve: Curves.elasticOut));

    _heroCtrl.forward();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _avatarCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _contentCtrl.forward();
    });

    _checkExistingChat();
  }

  // ── Verifica se já existe chat com o profissional ──────────────────────
  Future<void> _checkExistingChat() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null || ownerLocalId.isEmpty) {
        if (mounted) setState(() => _isCheckingChat = false);
        return;
      }

      final db = FirebaseDatabase.instance.ref();

      // Buscar chats onde eu sou contractor e o profissional é employee
      final contractorSnapshot = await db
          .child('Chats')
          .orderByChild('contractor')
          .equalTo(currentUserId)
          .get();

      if (contractorSnapshot.exists) {
        final data = contractorSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in data.entries) {
          final chatData = entry.value as Map<dynamic, dynamic>;
          if (chatData['employee'] == ownerLocalId) {
            if (mounted) {
              setState(() {
                _existingChatId = entry.key.toString();
                _myRole = 'contractor';
                _ownerRole = 'employee';
                _isCheckingChat = false;
              });
            }
            return;
          }
        }
      }

      // Buscar chats onde eu sou employee e o profissional é contractor
      final employeeSnapshot = await db
          .child('Chats')
          .orderByChild('employee')
          .equalTo(currentUserId)
          .get();

      if (employeeSnapshot.exists) {
        final data = employeeSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in data.entries) {
          final chatData = entry.value as Map<dynamic, dynamic>;
          if (chatData['contractor'] == ownerLocalId) {
            if (mounted) {
              setState(() {
                _existingChatId = entry.key.toString();
                _myRole = 'employee';
                _ownerRole = 'contractor';
                _isCheckingChat = false;
              });
            }
            return;
          }
        }
      }

      // Nenhum chat encontrado — verifica se já solicitou
      await _checkIfAlreadyRequested();

      if (mounted) setState(() => _isCheckingChat = false);
    } catch (e) {
      debugPrint('❌ Erro ao verificar chat existente: $e');
      if (mounted) setState(() => _isCheckingChat = false);
    }
  }

  // ── Verifica se já enviou solicitação de chat ──────────────────────────
  Future<void> _checkIfAlreadyRequested() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final professionalId = widget.professional.id;
    final db = FirebaseDatabase.instance.ref();
    final snapshot =
        await db.child('professionals/$professionalId/requests').get();

    if (snapshot.exists && snapshot.value is List) {
      final requestsList = List.from(snapshot.value as List);
      if (requestsList.contains(currentUserId)) {
        if (mounted) setState(() => _hasAlreadyRequested = true);
      }
    }
  }

  // ── Abre chat existente ────────────────────────────────────────────────
  Future<void> _openExistingChat() async {
    if (_existingChatId == null || _myRole == null || _ownerRole == null)
      return;

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final userLookup = UserLookupService();
      final ownerData = await userLookup.getUserData(ownerLocalId);

      if (!mounted) return;

      final contractorId =
          _myRole == 'contractor' ? currentUserId : ownerLocalId;
      final employeeId = _myRole == 'employee' ? currentUserId : ownerLocalId;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => ChatControllerFinal(),
            child: ChatRoomScreen(
              chatId: _existingChatId!,
              contractorId: contractorId,
              employeeId: employeeId,
              userRole: _myRole!,
              userId: currentUserId,
              otherUserName: ownerData.name,
              otherUserAvatar:
                  ownerData.avatar.isNotEmpty ? ownerData.avatar : null,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Erro ao abrir chat: $e');
      _showError('Erro ao abrir conversa. Tente novamente.');
    }
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _contentCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surface,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHero(),
                SliverToBoxAdapter(
                  child: SlideTransition(
                    position: _contentSlide,
                    child: FadeTransition(
                      opacity: _contentOpacity,
                      child: _buildContent(),
                    ),
                  ),
                ),
              ],
            ),
            _buildFloatingAppBar(),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildFloatingAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          bottom: 8,
        ),
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Material(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
            Material(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: Colors.white, size: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 3,
                onSelected: (value) {
                  if (value == 'report') _showReportDialog();
                  if (value == 'block') _showBlockDialog();
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.flag_outlined,
                              color: Colors.red.shade600, size: 17),
                        ),
                        const SizedBox(width: 12),
                        const Text('Denunciar',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.lock,
                              color: Colors.red.shade600, size: 17),
                        ),
                        const SizedBox(width: 12),
                        const Text('Bloquear usuário',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 300,
      pinned: false,
      stretch: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: ScaleTransition(
          scale: _heroScale,
          child: FadeTransition(
            opacity: _heroOpacity,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF2563EB),
                    Color(0xFF93C5FD),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -70,
                    right: -50,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: -60,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),
                        ScaleTransition(
                          scale: _avatarScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipOval(
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                  child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.2),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.4),
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                backgroundImage: widget
                                        .professional.avatar.isNotEmpty
                                    ? NetworkImage(widget.professional.avatar)
                                    : null,
                                child: widget.professional.avatar.isEmpty
                                    ? const Icon(Icons.person,
                                        size: 48, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.professional.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.professional.profession,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('CONTATOS'),
          const SizedBox(height: 16),
          _buildContactRow(
            icon: Icons.email_outlined,
            label: 'E-mail',
            value: widget.professional.email,
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 12),
          _buildContactRow(
            icon: Icons.phone_android_rounded,
            label: 'Telefone',
            value: widget.professional.telefone,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 32),
          _sectionLabel('INFORMAÇÕES GERAIS'),
          const SizedBox(height: 16),
          _buildInfoGrid(),
          const SizedBox(height: 32),
          _sectionLabel('HABILIDADES'),
          const SizedBox(height: 16),
          _buildSkillsSection(),
          const SizedBox(height: 32),
          _sectionLabel('SOBRE O PROFISSIONAL'),
          const SizedBox(height: 16),
          _buildAboutCard(),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _copyToClipboard(value, '$label copiado!'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15,
                          color: _ink,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.copy_rounded, size: 16, color: _muted),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 1.2,
        ),
      );

  Widget _buildInfoGrid() {
    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.badge_rounded,
        'label': 'Tipo de contrato',
        'value': widget.professional.legalType,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'icon': Icons.location_on_rounded,
        'label': 'Localização',
        'value': '${widget.professional.city}, ${widget.professional.state}',
        'color': const Color(0xFFEF4444),
      },
      if (widget.professional.company.isNotEmpty)
        {
          'icon': Icons.business_rounded,
          'label': 'Empresa',
          'value': widget.professional.company,
          'color': _blue,
        },
    ];

    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < items.length - 1 ? 10 : 0),
            child: _detailTile(items[i]),
          ),
      ],
    );
  }

  Widget _detailTile(Map<String, dynamic> item) {
    final Color c = item['color'] as Color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item['icon'] as IconData, color: c, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['label'] as String,
                    style: const TextStyle(
                        fontSize: 10,
                        color: _muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Text(item['value'] as String,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.professional.skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _blueLight.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _blue.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: _blueLight, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(skill,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _blue,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAboutCard() {
    final hasSummary = widget.professional.summary.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        hasSummary ? widget.professional.summary : 'Sem resumo disponível.',
        style: TextStyle(
          fontSize: 14,
          color: hasSummary ? _ink : _muted,
          height: 1.7,
        ),
      ),
    );
  }

  // ── Bottom Bar com três estados: carregando / chat existente / solicitar ──
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: _buildBottomBarContent(),
        ),
      ),
    );
  }

  Widget _buildBottomBarContent() {
    // 1. Ainda verificando
    if (_isCheckingChat) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
        ),
      );
    }

    // 2. Chat já existe → botão "Abrir Chat"
    if (_existingChatId != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openExistingChat,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Abrir Chat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Solicitação já enviada mas sem chat criado ainda
    if (_hasAlreadyRequested) {
      return _buildAlreadyRequestedBar();
    }

    // 4. Estado padrão → botão "Solicitar Chat"
    return ElevatedButton.icon(
      onPressed: _isRequesting ? null : _requestChat,
      icon: _isRequesting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: Text(
        _isRequesting ? 'Enviando...' : 'Solicitar Chat',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _blue.withOpacity(0.6),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildAlreadyRequestedBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF0EA5E9).withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF0EA5E9), size: 20),
          ),
          const Expanded(
            child: Text(
              'Chat solicitado!',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0369A1),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Color(0xFF0EA5E9)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════
  // DIÁLOGOS — DENÚNCIA E BLOQUEIO
  // ══════════════════════════════

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.flag_outlined,
                  color: Colors.red.shade600, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Denunciar Perfil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Você tem certeza que deseja denunciar este perfil profissional?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openReportScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Denunciar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.lock, color: Colors.red.shade600, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Bloquear Usuário',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Você tem certeza que deseja bloquear este usuário? '
          'Ele não poderá mais ver suas vagas ou entrar em contato com você.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeBlock();
            },
            child: const Text('Bloquear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

// ✅ Lógica de bloqueio separada e limpa
  Future<void> _executeBlock() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      _showError('Usuário não autenticado');
      return;
    }

    final blockProvider = context.read<BlockProvider>();
    feedController.registerWithBlockProvider(blockProvider);
    searchController.registerWithBlockProvider(blockProvider);

    // ✅ Só inicializa se NUNCA foi inicializado antes
    // Não chama init() se já está inicializado — evita o bug de bloquear 2x
    if (!blockProvider.isInitialized) {
      await blockProvider.init(currentUserId);
    }

    // ✅ Aguarda só se estiver carregando no momento
    if (blockProvider.isLoading) {
      int attempts = 0;
      while (blockProvider.isLoading && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
    }

    if (!mounted) return;

    final success = await blockProvider.blockUser(ownerLocalId);

    if (!mounted) return;

    if (success) {
  // ✅ Adiciona diretamente nos controllers — evita cache do iOS
  try {
    context.read<FeedController>().addBlockedUser(ownerLocalId); // ou widget.otherUserId no chat
    context.read<search.SearchController>().addBlockedUser(ownerLocalId);
  } catch (_) {}

  // forceRefresh em background (não crítico — só para sincronizar)
  Future.delayed(const Duration(seconds: 2), () {
    try {
      context.read<FeedController>().forceRefresh();
      context.read<search.SearchController>().forceRefresh();
    } catch (_) {}
  });

  _showSuccess('Usuário bloqueado com sucesso!');
  await Future.delayed(const Duration(milliseconds: 500));
  if (!mounted) return;
  Navigator.pop(context);
} else {
  final erro = blockProvider.lastError ?? 'Erro desconhecido ao bloquear';
  _showError('Falha: $erro');
}
  }

  void _openReportScreen() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      _showError('Você precisa estar logado para denunciar');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintProfessional(
          vacancyId: widget.vacancyId,
          reportId: widget.reportId,
          reportedId: widget.reportedId,
        ),
      ),
    );
  }

  Future<void> _requestChat() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    try {
      final validation =
          await ProfileValidationService.validateContractorProfile();
      if (!validation.isValid) {
        setState(() => _isRequesting = false);
        if (mounted) validation.showErrorDialog(context);
        return;
      }

      final db = FirebaseDatabase.instance.ref();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null) {
        setState(() => _isRequesting = false);
        _showError('Você precisa estar logado');
        return;
      }

      final userSnapshot = await db.child('Users/$currentUserId').get();
      String userName = 'Usuário';
      String userAvatar = '';

      if (userSnapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        userName = userData['Name'] ?? userData['name'] ?? 'Usuário';
        userAvatar = userData['avatar'] ?? '';
      }

      final professionalId = widget.professional.id;
      final requestsRef = db.child('professionals/$professionalId/requests');
      final snapshot = await requestsRef.get();

      List<dynamic> requestsList = [];
      if (snapshot.exists && snapshot.value is List) {
        requestsList = List.from(snapshot.value as List);
      }

      if (requestsList.contains(currentUserId)) {
        setState(() {
          _isRequesting = false;
          _hasAlreadyRequested = true;
        });
        _showError('Você já solicitou chat com este profissional');
        return;
      }

      requestsList.add(currentUserId);

      final updates = <String, dynamic>{};
      updates['professionals/$professionalId/requests'] = requestsList;
      updates[
          'professionals/$professionalId/views/request_views/$currentUserId'] = {
        'viewed_by_owner': false,
        'requested_at': DateTime.now().millisecondsSinceEpoch,
        'contractor_name': userName,
        'contractor_avatar': userAvatar,
      };

      await db.update(updates);

      try {
        await db
            .child('user_requests/$currentUserId/professionals/$professionalId')
            .set(true);
      } catch (_) {}

      _showSuccess('Chat solicitado com sucesso!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Erro ao solicitar chat: $e');
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }
}
