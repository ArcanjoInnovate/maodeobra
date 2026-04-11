import 'package:dartobra_new/screens/profile/credentials/edit_email_screen.dart';
import 'package:flutter/material.dart';
import 'package:dartobra_new/screens/profile/credentials/edit_password_screen.dart';

class EditLoginInfo extends StatefulWidget {
  final String local_id;
  final String userName;
  final String userEmail;
  final String userPhone;
  final bool finished_basic;
  final bool finished_professional;
  final bool finished_contact;
  final String userCity;
  final String userState;
  final int userAge;
  final String userAvatar;
  final String legalType;
  final String company;
  final String activeMode;
  final String profession;
  final String summary;
  final List<String> skills;
  final Map<String, dynamic> dataWorker;
  final Map<String, dynamic> dataContractor;

  const EditLoginInfo({
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
  State<EditLoginInfo> createState() => _EditLoginInfoState();
}

class _EditLoginInfoState extends State<EditLoginInfo> {
  late String currentEmail;

  @override
  void initState() {
    super.initState();
    currentEmail = widget.userEmail;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Retorna o email atualizado quando voltar
      onWillPop: () async {
        Navigator.pop(context, currentEmail);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2D3142)),
            onPressed: () => Navigator.pop(context, currentEmail),
          ),
          title: const Text(
            'Informações de Login',
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
                  'Segurança da Conta',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gerencie suas credenciais de acesso',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                _buildInfoCard(
                  context,
                  icon: Icons.email_outlined,
                  title: 'Alterar Email',
                  subtitle: currentEmail,
                  gradientColors: [
                    const Color(0xFF667eea),
                    const Color(0xFF764ba2),
                  ],
                  onTap: () async {
                    final newEmail = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditEmail(
                          local_id: widget.local_id,
                          userName: widget.userName,
                          userEmail: currentEmail, // Passa o email atual
                          userPhone: widget.userPhone,
                          finished_basic: widget.finished_basic,
                          finished_professional: widget.finished_professional,
                          finished_contact: widget.finished_contact,
                          userCity: widget.userCity,
                          userState: widget.userState,
                          userAge: widget.userAge,
                          userAvatar: widget.userAvatar,
                          legalType: widget.legalType,
                          company: widget.company,
                          activeMode: widget.activeMode,
                          profession: widget.profession,
                          summary: widget.summary,
                          skills: widget.skills,
                          dataWorker: widget.dataWorker,
                          dataContractor: widget.dataContractor,
                        ),
                      ),
                    );

                    if (newEmail != null && newEmail.isNotEmpty) {
                      setState(() {
                        currentEmail = newEmail;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Email alterado com sucesso!',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
                _buildInfoCard(
                  context,
                  icon: Icons.lock_outline,
                  title: 'Alterar Senha',
                  subtitle: '••••••••',
                  gradientColors: [
                    const Color(0xFFf093fb),
                    const Color(0xFFf5576c),
                  ],
                  onTap: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditPassword(
                          local_id: widget.local_id,
                          userName: widget.userName,
                          userEmail: currentEmail, // Passa o email atualizado
                          userPhone: widget.userPhone,
                          finished_basic: widget.finished_basic,
                          finished_professional: widget.finished_professional,
                          finished_contact: widget.finished_contact,
                          userCity: widget.userCity,
                          userState: widget.userState,
                          userAge: widget.userAge,
                          userAvatar: widget.userAvatar,
                          legalType: widget.legalType,
                          company: widget.company,
                          activeMode: widget.activeMode,
                          profession: widget.profession,
                          summary: widget.summary,
                          skills: widget.skills,
                          dataWorker: widget.dataWorker,
                          dataContractor: widget.dataContractor,
                        ),
                      ),
                    );

                    if (result == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Senha alterada com sucesso!',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
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
        child: Container(
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