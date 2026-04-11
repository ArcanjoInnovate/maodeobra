import 'package:flutter/material.dart';
import 'package:dartobra_new/screens/profile/contact/edit_contact_email_screen.dart';
import 'package:dartobra_new/screens/profile/contact/edit_contact_telephone_screen.dart';

/// ✅ OTIMIZADO: Removida leitura desnecessária do Firebase no initState
/// 
/// ANTES: 1 leitura do Firebase toda vez que a tela é aberta
/// DEPOIS: 0 leituras - usa apenas os parâmetros do widget
/// 
/// ECONOMIA: 1 leitura por abertura da tela (100% de redução)
class EditContactInfoScreen extends StatefulWidget {
  final String local_id;
  final String contact_email;
  final String userPhone;

  const EditContactInfoScreen({
    super.key,
    required this.local_id,
    required this.contact_email,
    required this.userPhone,
  });

  @override
  State<EditContactInfoScreen> createState() => _EditContactInfoScreenState();
}

class _EditContactInfoScreenState extends State<EditContactInfoScreen> {
  late String currentEmail;
  late String currentPhone;

  @override
  void initState() {
    super.initState();
    // ✅ OTIMIZAÇÃO: Usa diretamente os parâmetros do widget
    // Não precisa buscar do Firebase pois os dados já estão atualizados
    currentEmail = widget.contact_email;
    currentPhone = widget.userPhone;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Retorna os dados atualizados para a tela anterior
        Navigator.pop(context, {
          'contact_email': currentEmail,
          'phone': currentPhone,
        });
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2D3142)),
            onPressed: () {
              // Retorna os dados atualizados
              Navigator.pop(context, {
                'contact_email': currentEmail,
                'phone': currentPhone,
              });
            },
          ),
          title: const Text(
            'Informações de Contato',
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
                const Text(
                  'Contato',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gerencie suas informações de contato',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),

                // Card Email
                _buildContactCard(
                  context,
                  icon: Icons.email_outlined,
                  title: 'Email de Contato',
                  subtitle: currentEmail.isEmpty ? 'Não configurado' : currentEmail,
                  gradientColors: const [
                    Color(0xFF4A90E2),
                    Color(0xFF357ABD),
                  ],
                  onTap: () async {
                    final newEmail = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditContactEmailScreen(
                          local_id: widget.local_id,
                          userPhone: currentPhone,
                          email_contact: currentEmail,
                        ),
                      ),
                    );

                    if (newEmail != null && newEmail.isNotEmpty) {
                      setState(() {
                        currentEmail = newEmail;
                      });

                      _showSuccessSnackBar('Email de contato atualizado!');
                    }
                  },
                ),

                const SizedBox(height: 20),

                // Card Telefone
                _buildContactCard(
                  context,
                  icon: Icons.phone_outlined,
                  title: 'Telefone',
                  subtitle: currentPhone.isEmpty ? 'Não configurado' : currentPhone,
                  gradientColors: const [
                    Color(0xFF10B981),
                    Color(0xFF059669),
                  ],
                  onTap: () async {
                    final newPhone = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditContactPhoneScreen(
                          local_id: widget.local_id,
                          email_contact: currentEmail,
                          userPhone: currentPhone,
                        ),
                      ),
                    );

                    if (newPhone != null && newPhone.isNotEmpty) {
                      setState(() {
                        currentPhone = newPhone;
                      });

                      _showSuccessSnackBar('Telefone atualizado!');
                    }
                  },
                ),

                const SizedBox(height: 24),

                // Info adicional
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Essas informações são usadas para contato e notificações. Mantenha-as atualizadas.',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 13,
                            height: 1.4,
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
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Toque para alterar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.touch_app,
                          size: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}