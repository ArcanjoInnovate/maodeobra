import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:dartobra_new/features/auth/presentation/pages/login/login_screen.dart';

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

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      // ── Passo 1: Reautenticar ──────────────────────────────────────────
      final credential = EmailAuthProvider.credential(
        email: widget.userEmail,
        password: _passwordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // ── Passo 2: Deletar dados próprios do banco ───────────────────────
      // NÃO inclui limpeza de candidaturas em vagas/profissionais alheios.
      // Isso é feito pela Cloud Function onUserDeleted com Admin SDK,
      // que tem permissão para escrever em /badges de outros usuários.
      // O cliente Flutter não tem (e não deve ter) essa permissão.
      await _deleteOwnData();

      // ── Passo 3: Deletar conta Firebase Auth ───────────────────────────
      // Feito DEPOIS de deletar /Users/{uid}, para que o trigger
      // onUserDeleted ainda consiga ler o snapshot anterior (role, etc.).
      await user.delete();

      // ── Passo 4: Navegar para login ────────────────────────────────────
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        _showSnackBar('Conta deletada permanentemente!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Erro: ${_getErrorMessage(e)}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Deleta apenas os dados que pertencem ao próprio usuário.
  //
  // O que NÃO fazemos aqui (responsabilidade da Cloud Function):
  //   - decrementar /badges de outros usuários
  //   - remover o userId de /vacancy/{id}/requests de outros
  //   - remover o userId de /professionals/{id}/requests de outros
  //
  // A Cloud Function onUserDeleted é disparada quando /Users/{uid} é
  // removido e executa toda essa limpeza com Admin SDK.
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _deleteOwnData() async {
    final db = FirebaseDatabase.instance.ref();
    final userId = widget.local_id;

    // Badge próprio
    await db.child('badges/$userId').remove();

    // Perfil de profissional próprio (se worker)
    if (widget.activeMode == 'worker') {
      final profilesSnap = await db
          .child('professionals')
          .orderByChild('local_id')
          .equalTo(userId)
          .once();

      if (profilesSnap.snapshot.exists) {
        final profiles = Map<String, dynamic>.from(
          profilesSnap.snapshot.value as Map,
        );
        for (final profileId in profiles.keys) {
          await db.child('professionals/$profileId').remove();
        }
      }
    }

    // Vagas próprias (se contractor)
    if (widget.activeMode == 'contractor') {
      final vacanciesSnap = await db
          .child('vacancy')
          .orderByChild('local_id')
          .equalTo(userId)
          .once();

      if (vacanciesSnap.snapshot.exists) {
        final vacancies = Map<String, dynamic>.from(
          vacanciesSnap.snapshot.value as Map,
        );
        for (final vacancyId in vacancies.keys) {
          await db.child('vacancy/$vacancyId').remove();
        }
      }
    }

    // Nó principal do usuário — deve ser o ÚLTIMO a ser removido,
    // pois o trigger onUserDeleted lê o snapshot anterior para obter o role.
    await db.child('Users/$userId').remove();
  }

  String _getErrorMessage(dynamic error) {
    final msg = error.toString();
    if (msg.contains('password') || msg.contains('wrong-password')) {
      return 'Senha incorreta';
    }
    if (msg.contains('requires-recent-login')) {
      return 'Faça login novamente e tente de novo';
    }
    return 'Erro ao deletar conta. Tente novamente.';
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
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
              // Avatar + nome
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
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Aviso
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

              // Formulário de senha
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Digite sua senha para confirmar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3142),
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
                        if (value.length < 6) return 'Senha muito curta';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Botão deletar
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_forever, size: 24),
                            SizedBox(width: 12),
                            Text('Deletar Minha Conta',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)),
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