import 'dart:ui';

import 'package:dartobra_new/controllers/chat_controller.dart';
import 'package:dartobra_new/controllers/feed_controller.dart';
import 'package:dartobra_new/controllers/search_controller.dart' as search;
import 'package:dartobra_new/core/providers/block_provider.dart';
import 'package:dartobra_new/screens/chat/chat_room_screen.dart';
import 'package:dartobra_new/screens/complaints/complaint_professional_screen.dart';
import 'package:dartobra_new/services/chat/user_lookup_service.dart';
import 'package:dartobra_new/services/vacancy/profile_validation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  final Map<String, dynamic> professional;
  final String currentUserId;
  final String professionalId;
  final String reportedId;

  const ProfessionalProfileScreen({
    super.key,
    required this.professional,
    required this.currentUserId,
    required this.professionalId,
    required this.reportedId,
  });

  @override
  State<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen>
    with TickerProviderStateMixin {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isRequesting = false;

  // ID do dono do perfil
  String get ownerLocalId => widget.professional['local_id']?.toString() ?? '';

  // ✅ NOVO: Estado para chat existente
  bool _isCheckingChat = true;
  String? _existingChatId;
  String? _ownerRole;
  String? _myRole;

  late AnimationController _heroCtrl;
  late AnimationController _contentCtrl;
  late AnimationController _avatarCtrl;
  late Animation<double> _heroScale;
  late Animation<double> _heroOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentOpacity;
  late Animation<double> _avatarScale;

  static const Color _blue = Color(0xFF2563EB);
  static const Color _blueLight = Color(0xFF3B82F6);
  static const Color _blueSurface = Color(0xFFDBEAFE);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

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

    // ✅ NOVO: Verificar chat existente
    _checkExistingChat();
  }

  // ✅ NOVO: Verificar se já existe chat com o profissional
  Future<void> _checkExistingChat() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null || ownerLocalId.isEmpty) {
        setState(() => _isCheckingChat = false);
        return;
      }

      // Buscar chats onde eu sou contractor e o profissional é employee
      final contractorSnapshot = await _database
          .child('Chats')
          .orderByChild('contractor')
          .equalTo(currentUserId)
          .get();

      if (contractorSnapshot.exists) {
        final data = contractorSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in data.entries) {
          final chatData = entry.value as Map<dynamic, dynamic>;
          if (chatData['employee'] == ownerLocalId) {
            setState(() {
              _existingChatId = entry.key.toString();
              _myRole = 'contractor';
              _ownerRole = 'employee';
              _isCheckingChat = false;
            });
            return;
          }
        }
      }

      // Buscar chats onde eu sou employee e o profissional é contractor
      final employeeSnapshot = await _database
          .child('Chats')
          .orderByChild('employee')
          .equalTo(currentUserId)
          .get();

      if (employeeSnapshot.exists) {
        final data = employeeSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in data.entries) {
          final chatData = entry.value as Map<dynamic, dynamic>;
          if (chatData['contractor'] == ownerLocalId) {
            setState(() {
              _existingChatId = entry.key.toString();
              _myRole = 'employee';
              _ownerRole = 'contractor';
              _isCheckingChat = false;
            });
            return;
          }
        }
      }

      setState(() => _isCheckingChat = false);
    } catch (e) {
      print('❌ Erro ao verificar chat existente: $e');
      setState(() => _isCheckingChat = false);
    }
  }

  // ✅ NOVO: Abrir chat existente
  Future<void> _openExistingChat() async {
    if (_existingChatId == null || _myRole == null || _ownerRole == null)
      return;

    try {
      final userLookup = UserLookupService();
      final ownerData = await userLookup.getUserData(ownerLocalId);

      if (!mounted) return;

      final contractorId =
          _myRole == 'contractor' ? widget.currentUserId : ownerLocalId;
      final employeeId =
          _myRole == 'employee' ? widget.currentUserId : ownerLocalId;

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
              userId: widget.currentUserId,
              otherUserName: ownerData.name,
              otherUserAvatar:
                  ownerData.avatar.isNotEmpty ? ownerData.avatar : null,
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Erro ao abrir chat: $e');
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

  @override
  Widget build(BuildContext context) {
    final p = widget.professional;
    final skills =
        p['skills'] != null ? List<String>.from(p['skills']) : <String>[];

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
                _buildHero(p),
                SliverToBoxAdapter(
                  child: SlideTransition(
                    position: _contentSlide,
                    child: FadeTransition(
                      opacity: _contentOpacity,
                      child: _buildContent(p, skills),
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

  // ── Floating AppBar ──────────────────────────────────────────────────────
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

  // ── Hero ─────────────────────────────────────────────────────────────────
  Widget _buildHero(Map<String, dynamic> p) {
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
                                          width: 2.5),
                                    ),
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.white.withOpacity(0.15),
                                backgroundImage: p['avatar'] != null &&
                                        (p['avatar'] as String).isNotEmpty
                                    ? NetworkImage(p['avatar'])
                                    : null,
                                child: p['avatar'] == null ||
                                        (p['avatar'] as String).isEmpty
                                    ? const Icon(Icons.person_rounded,
                                        color: Colors.white, size: 48)
                                    : null,
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: p['isActive'] == true
                                        ? const Color(0xFF34D399)
                                        : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            p['name'] ?? 'Profissional',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (p['profession'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF93C5FD),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      p['profession'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            _surface.withOpacity(0.9),
                          ],
                        ),
                      ),
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

  // ── Content ──────────────────────────────────────────────────────────────
  Widget _buildContent(Map<String, dynamic> p, List<String> skills) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: _blueSurface,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, color: _blue, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${p['city']}, ${p['state']}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _blue,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _sectionLabel('INFORMAÇÕES'),
          const SizedBox(height: 12),
          _buildInfoList(p),
          const SizedBox(height: 28),
          if (_hasContactInfo()) ...[
            _sectionLabel('CONTATO'),
            const SizedBox(height: 12),
            _buildContactSection(),
            const SizedBox(height: 28),
          ],
          if (skills.isNotEmpty) ...[
            _sectionLabel('HABILIDADES'),
            const SizedBox(height: 12),
            _buildSkillsSection(skills),
            const SizedBox(height: 28),
          ],
          if (p['summary'] != null && (p['summary'] as String).isNotEmpty) ...[
            _sectionLabel('SOBRE'),
            const SizedBox(height: 12),
            _buildTextCard(p['summary']),
            const SizedBox(height: 28),
          ],
          if (p['experience'] != null &&
              (p['experience'] as String).isNotEmpty) ...[
            _sectionLabel('EXPERIÊNCIA'),
            const SizedBox(height: 12),
            _buildTextCard(p['experience']),
            const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }

  bool _hasContactInfo() {
    final email = widget.professional['email']?.toString() ?? '';
    final telefone = widget.professional['telefone']?.toString() ?? '';
    return (email.isNotEmpty && email != 'Não definido') ||
        (telefone.isNotEmpty && telefone != 'Não definido');
  }

  Widget _buildContactSection() {
    final email = widget.professional['email']?.toString() ?? '';
    final telefone = widget.professional['telefone']?.toString() ?? '';
    final hasEmail = email.isNotEmpty && email != 'Não definido';
    final hasTelefone = telefone.isNotEmpty && telefone != 'Não definido';

    return Column(
      children: [
        if (hasEmail)
          _contactRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: email,
            color: _blue,
            onTap: () => _copyToClipboard(email, 'Email copiado!'),
          ),
        if (hasEmail && hasTelefone) const SizedBox(height: 10),
        if (hasTelefone)
          _contactRow(
            icon: Icons.phone_outlined,
            label: 'Telefone',
            value: telefone,
            color: const Color(0xFF059669),
            onTap: () => _copyToClipboard(telefone, 'Telefone copiado!'),
          ),
      ],
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(Icons.copy_rounded, size: 16, color: _muted),
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

  Widget _buildInfoList(Map<String, dynamic> p) {
    final items = <Map<String, dynamic>>[
      if (p['legal_type'] != null && (p['legal_type'] as String).isNotEmpty)
        {
          'icon': Icons.badge_rounded,
          'label': 'Tipo de contrato',
          'value': p['legal_type'],
          'color': const Color(0xFF8B5CF6),
        },
      {
        'icon': Icons.location_on_rounded,
        'label': 'Localização',
        'value': '${p['city']}, ${p['state']}',
        'color': const Color(0xFFEF4444),
      },
      if (p['company'] != null && (p['company'] as String).isNotEmpty)
        {
          'icon': Icons.business_rounded,
          'label': 'Empresa',
          'value': p['company'],
          'color': _blue,
        },
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < items.length - 1 ? 10 : 0),
            child: _infoCard(items[i]),
          ),
      ],
    );
  }

  Widget _infoCard(Map<String, dynamic> item) {
    final Color iconColor = item['color'] as Color;
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item['icon'] as IconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['label'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item['value'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(List<String> skills) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((skill) {
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
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: _blueLight, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(skill,
                  style: const TextStyle(
                      fontSize: 13,
                      color: _blue,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextCard(String text) {
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
              offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: _ink, height: 1.7),
      ),
    );
  }

  // ✅ NOVO: Bottom Bar com verificação de chat existente
  Widget _buildBottomBar() {
    if (_isCheckingChat) {
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
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: _blue,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Se já existe chat, mostra botão "Abrir Chat"
    if (_existingChatId != null) {
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
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF10B981),
                  Color(0xFF059669),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
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
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
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
          ),
        ),
      );
    }

    // Caso contrário, botão normal de solicitação
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
          child: ElevatedButton.icon(
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
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
      try {
        context.read<FeedController>().forceRefresh();
        context.read<search.SearchController>().forceRefresh();
      } catch (_) {}

      _showSuccess('Usuário bloqueado com sucesso!');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      final erro = blockProvider.lastError ?? 'Erro desconhecido ao bloquear';
      _showError('Falha: $erro');
    }
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
          vacancyId: widget.professionalId,
          reportId: widget.currentUserId,
          reportedId: widget.reportedId,
        ),
      ),
    );
  }

  Future<void> _requestChat() async {
    setState(() => _isRequesting = true);

    final validation =
        await ProfileValidationService.validateContractorProfile();
    if (!validation.isValid) {
      setState(() => _isRequesting = false);
      validation.showErrorDialog(context);
      return;
    }

    final db = FirebaseDatabase.instance.ref();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      setState(() => _isRequesting = false);
      _showError('Você precisa estar logado');
      return;
    }

    try {
      final userSnapshot = await db.child('Users/$currentUserId').get();
      String userName = 'Usuário';
      String userAvatar = '';

      if (userSnapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        userName = userData['Name'] ?? userData['name'] ?? 'Usuário';
        userAvatar = userData['avatar'] ?? '';
      }

      final requestsRef = db
          .child('professionals')
          .child(widget.professionalId)
          .child('requests');
      final snapshot = await requestsRef.get();

      List<dynamic> requestsList = [];
      if (snapshot.exists && snapshot.value is List) {
        requestsList = List.from(snapshot.value as List);
      }

      if (requestsList.contains(currentUserId)) {
        setState(() => _isRequesting = false);
        _showError('Você já solicitou chat com este profissional');
        return;
      }

      requestsList.add(currentUserId);

      final updates = <String, dynamic>{};
      updates['professionals/${widget.professionalId}/requests'] = requestsList;
      updates[
          'professionals/${widget.professionalId}/views/request_views/$currentUserId'] = {
        'viewed_by_owner': false,
        'requested_at': DateTime.now().millisecondsSinceEpoch,
        'contractor_name': userName,
        'contractor_avatar': userAvatar,
      };

      await db.update(updates);

      try {
        await db
            .child(
                'user_requests/$currentUserId/professionals/${widget.professionalId}')
            .set(true);
      } catch (_) {}

      setState(() => _isRequesting = false);

      _showSuccess('Chat solicitado com sucesso!');
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isRequesting = false);
      _showError('Erro ao solicitar chat: $e');
    }
  }
}
