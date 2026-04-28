import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:dartobra_new/screens/auth/login/login_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  final String local_id;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String userCity;
  final String userState;
  final int userAge;
  final String userAvatar;
  final String legalType;
  final String company;
  final String activeMode;
  final bool finished_basic;
  final bool finished_professional;
  final bool finished_contact;
  final String profession;
  final String summary;
  final List<String> skills;
  final Map<String, dynamic> dataWorker;
  final Map<String, dynamic> dataContractor;

  const DeleteAccountScreen({
    super.key,
    required this.local_id,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.userCity,
    required this.userState,
    required this.userAge,
    required this.userAvatar,
    required this.legalType,
    required this.company,
    required this.activeMode,
    required this.finished_basic,
    required this.finished_professional,
    required this.finished_contact,
    required this.profession,
    required this.summary,
    required this.skills,
    required this.dataWorker,
    required this.dataContractor,
  });

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showWarning = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ✅ PASSO 1: Reautenticar usuário
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final credential = EmailAuthProvider.credential(
          email: widget.userEmail,
          password: _passwordController.text,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // ✅ PASSO 2: Deletar dados do Firebase Realtime Database
      await _deleteUserData();

      // ✅ PASSO 3: Deletar conta Firebase Auth
      await user?.delete();

      // ✅ PASSO 4: Voltar para login
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }

      _showSnackBar('Conta deletada permanentemente!', Colors.green);
    } catch (e) {
      _showSnackBar('Erro: ${_getErrorMessage(e)}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUserData() async {
    final database = FirebaseDatabase.instance.ref();

    // ✅ PASSO 1: Limpar candidaturas ANTES de deletar
    await _cleanupCandidatures();

    // ✅ PASSO 2: Deletar badges
    await database.child('badges/${widget.local_id}').remove();

    // ✅ PASSO 3: Deletar professionals (se worker)
    if (widget.activeMode == 'worker') {
      final profilesRef = database.child('professionals');
      final profiles = await profilesRef
          .orderByChild('local_id')
          .equalTo(widget.local_id)
          .once();
      if (profiles.snapshot.exists) {
        final profilesData = profiles.snapshot.value as Map;
        for (final profileId in profilesData.keys) {
          await profilesRef.child(profileId).remove();
        }
      }
    }

    // ✅ PASSO 4: Deletar vacancies (se contractor)
    if (widget.activeMode == 'contractor') {
      final vacanciesRef = database.child('vacancy');
      final vacancies = await vacanciesRef
          .orderByChild('local_id')
          .equalTo(widget.local_id)
          .once();
      if (vacancies.snapshot.exists) {
        final vacanciesData = vacancies.snapshot.value as Map;
        for (final vacancyId in vacanciesData.keys) {
          await vacanciesRef.child(vacancyId).remove();
        }
      }
    }

    // ✅ PASSO 5: Deletar User principal (ÚLTIMO)
    await database.child('Users/${widget.local_id}').remove();
  }

  /// ✅ LIMPAR CANDIDATURAS FEITAS PELO USUÁRIO
  Future<void> _cleanupCandidatures() async {
    final database = FirebaseDatabase.instance.ref();
    final userId = widget.local_id;

    if (widget.activeMode == 'worker') {
      // 🔵 Worker: remover de vagas onde se candidatou
      final vacanciesSnap = await database.child('vacancy').once();

      if (vacanciesSnap.snapshot.exists) {
        final vacancies = vacanciesSnap.snapshot.value as Map;

        for (final entry in vacancies.entries) {
          final vacancyId = entry.key;
          final vacancyData = entry.value as Map;

          // Normalizar requests (pode ser List ou Map)
          final requests = _normalizeList(vacancyData['requests']);

          if (requests.contains(userId)) {
            // Verificar se não foi visualizado
            final requestViews =
                vacancyData['views']?['request_views'] as Map? ?? {};

            if (requestViews[userId]?['viewed_by_owner'] == false) {
              // Decrementar badge do owner
              final ownerId = vacancyData['local_id'] as String?;
              if (ownerId != null) {
                await _decrementRequestBadge(ownerId);
              }
            }

            // Remover das listas
            final filteredRequests =
                requests.where((id) => id != userId).toList();
            await database
                .child('vacancy/$vacancyId/requests')
                .set(filteredRequests);
            await database
                .child('vacancy/$vacancyId/views/request_views/$userId')
                .remove();
          }
        }
      }
    } else {
      // 🟢 Contractor: remover de professionals onde se candidatou
      final professionalsSnap = await database.child('professionals').once();

      if (professionalsSnap.snapshot.exists) {
        final professionals = professionalsSnap.snapshot.value as Map;

        for (final entry in professionals.entries) {
          final professionalId = entry.key;
          final professionalData = entry.value as Map;

          final requests = _normalizeList(professionalData['requests']);

          if (requests.contains(userId)) {
            final requestViews =
                professionalData['views']?['request_views'] as Map? ?? {};

            if (requestViews[userId]?['viewed_by_owner'] == false) {
              final ownerId = professionalData['local_id'] as String?;
              if (ownerId != null) {
                await _decrementRequestBadge(ownerId);
              }
            }

            final filteredRequests =
                requests.where((id) => id != userId).toList();
            await database
                .child('professionals/$professionalId/requests')
                .set(filteredRequests);
            await database
                .child('professionals/$professionalId/views/request_views/$userId')
                .remove();
          }
        }
      }
    }
  }

  /// ✅ NORMALIZAR LISTA (suporta Map e List)
  List<String> _normalizeList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.whereType<String>().toList();
    }
    if (data is Map) {
      return data.values.whereType<String>().toList();
    }
    return [];
  }

  /// ✅ DECREMENTAR BADGE DE REQUEST
  Future<void> _decrementRequestBadge(String userId) async {
    try {
      final badgeRef = FirebaseDatabase.instance.ref('badges/$userId');
      final snap = await badgeRef.once();

      final current = snap.snapshot.exists
          ? snap.snapshot.value as Map
          : {'unread_chats': 0, 'unread_requests': 0};

      final newUnreadRequests =
          ((current['unread_requests'] as int? ?? 0) - 1).clamp(0, 9);

      await badgeRef.set({
        'unread_chats': current['unread_chats'] ?? 0,
        'unread_requests': newUnreadRequests,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('⚠️ Erro ao decrementar badge: $e');
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('password')) {
      return 'Senha incorreta';
    } else if (error.toString().contains('requires-recent-login')) {
      return 'Faça login novamente';
    }
    return 'Erro ao deletar conta. Tente novamente.';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Deletar Conta',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ AVATAR + NOME
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: widget.userAvatar.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(widget.userAvatar),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: Colors.grey[300],
                      ),
                      child: widget.userAvatar.isEmpty
                          ? const Icon(Icons.person,
                              size: 50, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    Text(
                      widget.userEmail,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // ✅ AVISO AMARELO
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFEB3B).withOpacity(0.1),
                      const Color(0xFFFF9800).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange[700], size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Esta ação é irreversível. Todos os seus dados, chats, candidaturas e perfil serão excluídos permanentemente.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ✅ FORM SENHA
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Digite sua senha para confirmar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Senha atual',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFF2D3142)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFFE74C3C), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite sua senha';
                        }
                        if (value.length < 6) {
                          return 'Senha muito curta';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // ✅ BOTÃO DELETAR
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _deleteAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE74C3C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.delete_forever, size: 24),
                            SizedBox(width: 12),
                            Text('Deletar Minha Conta',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}