// lib/pages/vacancy_detail_page.dart

import 'package:dartobra_new/controllers/chat_controller.dart';
import 'package:dartobra_new/core/providers/block_provider.dart';
import 'package:dartobra_new/models/search/vacancy_model.dart';
import 'package:dartobra_new/screens/chat/chat_room_screen.dart';
import 'package:dartobra_new/screens/complaints/complaint_vacancy_screen.dart';
import 'package:dartobra_new/services/chat/user_lookup_service.dart';
import 'package:dartobra_new/services/vacancy/profile_validation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class VacancyDetailPage extends StatefulWidget {
  final VacancyModel vacancy;
  final String vacancyId;
  final String reportedId;

  const VacancyDetailPage({
    super.key,
    required this.vacancy,
    required this.vacancyId,
    required this.reportedId,
  });

  @override
  State<VacancyDetailPage> createState() => _VacancyDetailPageState();
}

class _VacancyDetailPageState extends State<VacancyDetailPage>
    with TickerProviderStateMixin {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  String get ownerLocalId => widget.vacancy.localId;

  bool _isApplying = false;
  int _currentImageIndex = 0;
  late PageController _pageController;
  
  // ✅ NOVO: Estado para chat existente
  bool _isCheckingChat = true;
  String? _existingChatId;
  String? _ownerRole;
  String? _myRole;

  late AnimationController _heroCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _heroScale;
  late Animation<double> _heroOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentOpacity;

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
    _pageController = PageController();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _heroScale = Tween<double>(begin: 1.08, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));
    _heroOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: const Interval(0.0, 0.6)));
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));

    _heroCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _contentCtrl.forward();
    });
    
    // ✅ NOVO: Verificar chat existente
    _checkExistingChat();
  }

  // ✅ NOVO: Verificar se já existe chat com o dono da vaga
  Future<void> _checkExistingChat() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null || ownerLocalId.isEmpty) {
        setState(() => _isCheckingChat = false);
        return;
      }

      // Buscar chats onde eu sou contractor e o dono é employee
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

      // Buscar chats onde eu sou employee e o dono é contractor
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
    if (_existingChatId == null || _myRole == null || _ownerRole == null) return;

    try {
      final userLookup = UserLookupService();
      final ownerData = await userLookup.getUserData(ownerLocalId);

      if (!mounted) return;

      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final contractorId = _myRole == 'contractor' 
          ? currentUserId 
          : ownerLocalId;
      final employeeId = _myRole == 'employee' 
          ? currentUserId 
          : ownerLocalId;

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
              otherUserAvatar: ownerData.avatar.isNotEmpty ? ownerData.avatar : null,
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
    _pageController.dispose();
    _heroCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd/MM/yyyy \'às\' HH:mm').format(dateTime);
    } catch (_) {
      return dateTimeStr;
    }
  }

  List<String> _getImageUrls() {
    return widget.vacancy.images;
  }

  bool _hasContactInfo() {
    return widget.vacancy.emailContact.isNotEmpty ||
        widget.vacancy.phoneContact.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final images = _getImageUrls();

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
                _buildHero(images),
                SliverToBoxAdapter(
                  child: SlideTransition(
                    position: _contentSlide,
                    child: FadeTransition(
                      opacity: _contentOpacity,
                      child: _buildContent(images),
                    ),
                  ),
                ),
              ],
            ),
            _buildFloatingAppBar(context),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildFloatingAppBar(BuildContext context) {
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

  Widget _buildHero(List<String> images) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: images.isNotEmpty ? 300 : 280,
      pinned: false,
      stretch: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: ScaleTransition(
          scale: _heroScale,
          child: FadeTransition(
            opacity: _heroOpacity,
            child: images.isNotEmpty
                ? _buildImageHero(images)
                : _buildIconHero(),
          ),
        ),
      ),
    );
  }

  Widget _buildImageHero(List<String> images) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _currentImageIndex = i),
          itemBuilder: (_, index) => Image.network(
            images[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: Icon(Icons.broken_image_outlined,
                  size: 60, color: Colors.grey.shade400),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF2563EB)),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1}/${images.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        if (images.length > 1)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, _surface.withOpacity(0.95)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF2563EB),
            Color(0xFF60A5FA),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.work_outline_rounded,
                          color: Colors.white, size: 44),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                            color: Colors.white.withOpacity(0.25), width: 1),
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
                          const Text('Vaga Disponível',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.vacancy.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      letterSpacing: -0.5,
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
                  colors: [Colors.transparent, _surface.withOpacity(0.9)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<String> images) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty) ...[
            Text(
              widget.vacancy.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: _blueSurface,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                widget.vacancy.type.isNotEmpty ? widget.vacancy.type : 'Geral',
                style: TextStyle(
                    fontSize: 13,
                    color: _blue,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4),
              ),
            ),
          ),
          _sectionLabel('DETALHES'),
          const SizedBox(height: 12),
          _buildDetailsGrid(),
          const SizedBox(height: 28),
          if (_hasContactInfo()) ...[
            _sectionLabel('CONTATO'),
            const SizedBox(height: 12),
            _buildContactSection(),
            const SizedBox(height: 28),
          ],
          if (widget.vacancy.description.isNotEmpty) ...[
            _sectionLabel('DESCRIÇÃO DA VAGA'),
            const SizedBox(height: 12),
            _buildTextCard(widget.vacancy.description),
            const SizedBox(height: 28),
          ],
          if (images.isNotEmpty) ...[
            _sectionLabel('GALERIA'),
            const SizedBox(height: 12),
            _buildGallerySection(images),
            const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    final email = widget.vacancy.emailContact;
    final phone = widget.vacancy.phoneContact;

    return Column(
      children: [
        if (email.isNotEmpty)
          _contactRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: email,
            color: _blue,
            onTap: () => _copyToClipboard(email, 'Email copiado!'),
          ),
        if (email.isNotEmpty && phone.isNotEmpty) const SizedBox(height: 10),
        if (phone.isNotEmpty)
          _contactRow(
            icon: Icons.phone_outlined,
            label: 'Telefone',
            value: phone,
            color: const Color(0xFF059669),
            onTap: () => _copyToClipboard(phone, 'Telefone copiado!'),
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
                          color: Color(0xFF111827),
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

  Widget _buildGallerySection(List<String> images) {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final imageUrl = images[index];
          return GestureDetector(
            onTap: () => _openFullscreen(images, index),
            child: Container(
              width: 260,
              margin: EdgeInsets.only(
                right: index < images.length - 1 ? 12 : 0,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'vacancy_image_$index',
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 40, color: Colors.grey.shade400),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF2563EB)),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: const Icon(Icons.open_in_full_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                    if (images.length > 1)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}/${images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFullscreen(List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(
          images: images,
          initialIndex: initialIndex,
          heroTagPrefix: 'vacancy_image',
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 1.2,
        ),
      );

  Widget _buildDetailsGrid() {
    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.location_on_rounded,
        'label': 'Localização',
        'value': '${widget.vacancy.city}, ${widget.vacancy.state}',
        'color': const Color(0xFFEF4444),
      },
      {
        'icon': Icons.payments_rounded,
        'label': 'Salário',
        'value': widget.vacancy.salary.isNotEmpty
            ? widget.vacancy.salary
            : 'Não informado',
        'color': const Color(0xFF8B5CF6),
      },
      if (widget.vacancy.company.isNotEmpty)
        {
          'icon': Icons.business_rounded,
          'label': 'Empresa',
          'value': widget.vacancy.company,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item['icon'] as IconData, color: c, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['label'] as String,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 3),
                Text(item['value'] as String,
                    style: const TextStyle(
                        fontSize: 15,
                        color: _ink,
                        fontWeight: FontWeight.w600,
                        height: 1.3),
                    softWrap: true),
              ],
            ),
          ),
        ],
      ),
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
        style: TextStyle(fontSize: 14, color: _ink, height: 1.7),
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

    // Caso contrário, botão normal de candidatura
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
            onPressed: _isApplying ? null : _applyToVacancy,
            icon: _isApplying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _isApplying ? 'Enviando...' : 'Candidatar-se à Vaga',
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
  // DIÁLOGOS
  // ══════════════════════════════

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          'Você tem certeza que deseja bloquear este usuário? Ele não poderá mais ver suas vagas ou entrar em contato com você.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await context
                  .read<BlockProvider>()
                  .blockUser(ownerLocalId);

              if (!mounted) return;

              if (success) {
                _showSuccess('Usuário bloqueado com sucesso!');
                Navigator.pop(context);
              } else {
                _showError('Erro ao bloquear usuário.');
              }
            },
            child: const Text('Bloquear',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

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
            const Text('Denunciar Vaga',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Você tem certeza que deseja denunciar esta vaga?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
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

  void _openReportScreen() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      _showError('Você precisa estar logado para denunciar');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintVacancy(
          vacancyId: widget.vacancyId,
          reportId: widget.vacancyId,
          reportedId: widget.reportedId,
        ),
      ),
    );
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

  Future<void> _applyToVacancy() async {
    setState(() => _isApplying = true);

    try {
      final validation = await ProfileValidationService.validateWorkerProfile();
      if (!validation.isValid) {
        setState(() => _isApplying = false);
        validation.showErrorDialog(context);
        return;
      }

      final db = FirebaseDatabase.instance.ref();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final userSnapshot = await db.child('Users/$currentUserId').get();
      String workerName = 'Trabalhador';
      String workerAvatar = '';
      if (userSnapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        workerName = userData['Name'] ?? userData['name'] ?? 'Trabalhador';
        workerAvatar = userData['avatar'] ?? '';
      }

      final requestsSnapshot =
          await db.child('vacancy/${widget.vacancyId}/requests').get();
      List<String> requestsList = [];

      if (requestsSnapshot.exists && requestsSnapshot.value != null) {
        final data = requestsSnapshot.value;
        if (data is List) {
          requestsList = List<String>.from(data);
        } else if (data is String) {
          requestsList = [data];
        } else if (data is Map) {
          requestsList = data.values.map((v) => v.toString()).toList();
        }
      }

      if (requestsList.contains(currentUserId)) {
        setState(() => _isApplying = false);
        _showError('Você já se candidatou!');
        return;
      }

      requestsList.add(currentUserId);

      final updates = <String, dynamic>{
        'vacancy/${widget.vacancyId}/requests': requestsList,
        'vacancy/${widget.vacancyId}/views/request_views/$currentUserId': {
          'viewed_by_owner': false,
          'applied_at': DateTime.now().millisecondsSinceEpoch,
          'worker_name': workerName,
          'worker_avatar': workerAvatar,
        },
        'vacancy/${widget.vacancyId}/stats/total_applications':
            requestsList.length,
      };

      await db.update(updates);

      setState(() => _isApplying = false);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Candidatura enviada! Dono da vaga foi notificado.'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ));

      Navigator.pop(context);
    } catch (e, stack) {
      print('❌ ERRO _applyToVacancy: $e\n$stack');
      setState(() => _isApplying = false);
      _showError('Erro ao enviar candidatura: $e');
    }
  }
}

// ══════════════════════════════════════════════════════
// FULLSCREEN IMAGE VIEWER
// ══════════════════════════════════════════════════════
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroTagPrefix;

  const _FullscreenImageViewer({
    required this.images,
    required this.initialIndex,
    required this.heroTagPrefix,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: '${widget.heroTagPrefix}_$index',
                child: Image.network(
                  widget.images[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 72, color: Colors.grey.shade600),
                      const SizedBox(height: 12),
                      Text('Erro ao carregar imagem',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14)),
                    ],
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}