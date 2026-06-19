import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dartobra_new/models/user_model.dart';
import 'package:dartobra_new/screens/home/home_screen.dart';
import 'package:dartobra_new/screens/admin/suspension/suspension_controller.dart';
import 'package:dartobra_new/features/auth/presentation/pages/login/login_screen.dart';

class SuspensionScreen extends StatefulWidget {
  final String localId;

  /// Dados já carregados (evita leitura extra ao abrir a tela).
  final UserModel user;

  const SuspensionScreen({
    Key? key,
    required this.localId,
    required this.user,
  }) : super(key: key);

  @override
  State<SuspensionScreen> createState() => _SuspensionScreenState();
}

class _SuspensionScreenState extends State<SuspensionScreen> {
  late final SuspensionController _controller;

  // Dados extraídos do UserModel para exibição
  late final String _startDate;
  late final String _endDate;
  late final String _occurrenceDate;
  late final String _reason;
  late final String _description;
  late final int _daysRemaining;

  @override
  void initState() {
    super.initState();
    _controller = SuspensionController(localId: widget.localId);

    final s = widget.user.suspension;
    _startDate = s['init']?.toString() ?? '';
    _endDate = s['end']?.toString() ?? '';
    _occurrenceDate = s['data']?.toString() ?? _startDate;
    _reason = s['motive']?.toString() ?? '';
    _description = s['description']?.toString() ?? '';
    _daysRemaining = widget.user.suspensionDaysRemaining;

    // Se a suspensão já expirou, limpa e vai para Home automaticamente
    if (_daysRemaining <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoRelease());
    }
  }

  // ── Navegação ──────────────────────────────────────────────────────────────

  /// Faz logout do Firebase e navega diretamente para LoginScreen,
  /// removendo toda a pilha de navegação.
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _goHome(UserModel u) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          local_id: u.localId,
          userName: u.userName,
          userEmail: u.email,
          contact_email: u.contactEmail,
          legalType: u.legalType,
          userPhone: u.phone,
          userCity: u.city,
          userState: u.state,
          age: u.age,
          userAvatar: u.avatar,
          finished_basic: u.finishedBasic,
          finished_contact: u.finishedContact,
          finished_professional: u.finishedProfessional,
          isActive: u.isActive,
          activeMode: u.activeMode,
          dataWorker: u.dataWorker,
          dataContractor: u.dataContractor,
        ),
      ),
      (route) => false,
    );
  }

  /// Chamado automaticamente quando a suspensão já expirou.
  Future<void> _autoRelease() async {
    final updatedUser = await _controller.clearSuspension();
    if (!mounted) return;

    if (updatedUser != null) {
      _goHome(updatedUser);
    } else {
      // Fallback: mantém na tela e mostra aviso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao liberar conta. Tente reiniciar o app.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Enquanto redireciona (suspensão expirada) — mostra loading
    if (_daysRemaining <= 0) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade50,
              Colors.white,
              Colors.orange.shade50
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ───────────────────────────────────────────────
                    SizedBox(
                      width: screenWidth,
                      height: screenHeight * 0.28,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade500,
                              Colors.red.shade500
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.access_time,
                                  size: 38, color: Colors.white),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            const Text(
                              'Conta Suspensa',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Olá, ${widget.user.userName}. Seu acesso foi temporariamente restrito.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange.shade100),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Conteúdo ─────────────────────────────────────────────
                    SizedBox(height: screenHeight * 0.02),
                    Padding(
                      padding: EdgeInsets.only(
                        left: 10,
                        right: 10,
                        bottom: screenHeight * 0.03,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Período
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                    color: Colors.orange.shade500, width: 4),
                              ),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildPeriodItem(
                                    label: 'Data de Início',
                                    value: _startDate,
                                  ),
                                ),
                                Expanded(
                                  child: _buildPeriodItem(
                                    label: 'Data Final',
                                    value: _endDate,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tempo Restante',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$_daysRemaining dias',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (_occurrenceDate.isNotEmpty) ...[
                            _buildInfoSection(
                              icon: Icons.calendar_today,
                              title: 'DATA DO OCORRIDO',
                              content: _occurrenceDate,
                            ),
                            const SizedBox(height: 24),
                          ],

                          if (_reason.isNotEmpty) ...[
                            _buildInfoSection(
                              icon: Icons.warning_amber,
                              title: 'MOTIVO',
                              content: _reason,
                            ),
                            const SizedBox(height: 24),
                          ],

                          if (_description.isNotEmpty) ...[
                            Text(
                              'DESCRIÇÃO DETALHADA',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                _description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],

                          // Botões
                          Row(
                            children: [
                              // Suporte
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showSupportDialog(context),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: Colors.orange.shade500,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.email, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Suporte',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Sair
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _logout(context),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: Colors.grey.shade600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Sair',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────────

  Widget _buildPeriodItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          value.isNotEmpty ? value : '—',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(ctx).size.width * 0.96,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.support_agent,
                    size: 40, color: Colors.blue.shade700),
              ),
              const SizedBox(height: 16),
              const Text(
                'Contato do Suporte',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Entre em contato conosco para resolver sua situação.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              _buildSupportItem(
                icon: Icons.email,
                iconColor: Colors.blue.shade700,
                label: 'Email',
                value: 'suportemaodeobra@gmail.com',
                snackMsg: 'Email copiado!',
                context: ctx,
              ),
              const SizedBox(height: 12),
              _buildSupportItem(
                icon: Icons.phone,
                iconColor: Colors.green.shade700,
                label: 'Telefone',
                value: '(62) 98765-4321',
                snackMsg: 'Telefone copiado!',
                context: ctx,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String snackMsg,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            color: Colors.grey.shade600,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.blue,
                  content: Text(snackMsg,
                      style: const TextStyle(color: Colors.white)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
