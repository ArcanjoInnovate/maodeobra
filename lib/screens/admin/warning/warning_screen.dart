import 'package:flutter/material.dart';
import 'package:dartobra_new/models/user_model.dart';
import 'package:dartobra_new/screens/home/home_screen.dart';
import 'package:dartobra_new/screens/admin/warning/warning_controller.dart';

class WarningScreen extends StatelessWidget {
  final String localId;

  /// Dados já carregados (evita leitura extra ao abrir a tela).
  final UserModel user;

  const WarningScreen({
    Key? key,
    required this.localId,
    required this.user,
  }) : super(key: key);

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _occurrenceDate => user.warning['data']?.toString() ?? '';
  String get _reason => user.warning['motive']?.toString() ?? '';
  String get _description => user.warning['description']?.toString() ?? '';

  // ── Navegação ──────────────────────────────────────────────────────────────

  void _goHome(BuildContext context, UserModel u) {
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

  Future<void> _onAcknowledge(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final controller = WarningController(localId: localId);
    final updatedUser = await controller.acknowledgeWarning();

    if (!context.mounted) return;
    Navigator.pop(context); // fecha loading

    if (updatedUser != null) {
      _goHome(context, updatedUser);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao limpar advertência. Tente novamente.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.yellow.shade50,
              Colors.white,
              Colors.yellow.shade50
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
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
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.yellow[600]!, Colors.orange.shade500],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Advertência',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Olá, ${user.userName}. Você recebeu uma advertência.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // ── Conteúdo ─────────────────────────────────────────────
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 10, right: 10, bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banner de atenção
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                    color: Colors.yellow.shade500, width: 4),
                              ),
                            ),
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber,
                                    size: 24, color: Colors.yellow.shade600),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Atenção Necessária',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.yellow.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Esta é uma advertência formal. Futuras violações podem resultar em suspensão ou banimento da conta.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                          height: 1.4,
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

                          // Botão
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _onAcknowledge(context),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                backgroundColor: Colors.yellow[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Li e Compreendi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
      ),
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
            Icon(icon, size: 20, color: Colors.grey[600]),
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
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
