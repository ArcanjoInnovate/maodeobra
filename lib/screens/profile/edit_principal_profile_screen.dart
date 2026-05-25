import 'package:dartobra_new/screens/profile/blocked_users_screen.dart';
import 'package:dartobra_new/screens/profile/delete/delet_account_screen.dart';
import 'package:dartobra_new/screens/profile/edit_login_info_screen.dart';
import 'package:flutter/material.dart';
import 'edit_basic_info_screen.dart';
import 'edit_contact_info_screen.dart';
import 'edit_professional_info_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final String local_id;
  final String userName;
  final String userEmail;
  final String userPhone;
  final bool finished_basic;
  final String contact_email;
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

  const EditProfileScreen({
    super.key,
    required this.local_id,
    required this.userName,
    required this.userEmail,
    required this.contact_email,
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
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late String userName;
  late int userAge;
  late String userCity;
  late String userState;
  late String userAvatar;
  late String contact_email;
  late String userPhone;
  late String legalType; // ✅ Adicionado
  late bool finished_basic;
  late bool finished_contact;
  late bool finished_professional;

  late Map<String, dynamic> dataWorker;
  late Map<String, dynamic> dataContractor;

  @override
  void initState() {
    super.initState();

    userName = widget.userName;
    userAge = widget.userAge;
    userCity = widget.userCity;
    userState = widget.userState;
    userAvatar = widget.userAvatar;
    contact_email = widget.contact_email;
    legalType = widget.legalType; // ✅ Inicializado
    userPhone = widget.userPhone;

    finished_basic = widget.finished_basic;
    finished_contact = widget.finished_contact;
    finished_professional = widget.finished_professional;

    dataWorker = Map<String, dynamic>.from(widget.dataWorker);
    dataContractor = Map<String, dynamic>.from(widget.dataContractor);
  }

  // ✅ MÉTODO NOVO - CARD DE PERIGO (cole ANTES do Widget build)
  Widget _buildDangerSectionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE74C3C).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _returnToHomeScreen();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: _returnToHomeScreen,
          ),
          title: const Text(
            'Editar Perfil',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              /// 🔹 INFORMAÇÕES BÁSICAS
              _buildSectionCard(
                context: context,
                icon: Icons.person,
                iconColor: const Color(0xFF3B82F6),
                title: 'Informações Básicas',
                subtitle: 'Nome, idade, localização e foto',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditBasicInfoScreen(
                        local_id: widget.local_id,
                        userName: userName,
                        userEmail: widget.userEmail,
                        userPhone: userPhone,
                        userCity: userCity,
                        userState: userState,
                        userAge: userAge,
                        userAvatar: userAvatar,
                        finished_basic: finished_basic,
                        legalType: legalType, // ✅ Usar variável de estado
                        company: widget.company,
                        activeMode: widget.activeMode,
                        profession: widget.profession,
                        summary: widget.summary,
                        skills: widget.skills,
                        dataWorker: dataWorker,
                        dataContractor: dataContractor,
                      ),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      userName = result['name'];
                      userAge = result['age'];
                      userCity = result['city'];
                      userState = result['state'];
                      userAvatar = result['avatar'] ?? userAvatar;
                      finished_basic = true;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              /// 🔹 CONTATO
              _buildSectionCard(
                context: context,
                icon: Icons.contact_mail,
                iconColor: const Color(0xFF10B981),
                title: 'Informações de Contato',
                subtitle: 'E-mail e telefone',
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditContactInfoScreen(
                        local_id: widget.local_id,
                        contact_email: contact_email,
                        userPhone: userPhone,
                      ),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      contact_email = result['contact_email'] ?? contact_email;
                      userPhone = result['phone'] ?? userPhone;
                      finished_contact = true;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              /// 🔹 INFORMAÇÕES DE LOGIN
              _buildSectionCard(
                context: context,
                icon: Icons.lock,
                iconColor: const Color.fromARGB(255, 176, 68, 239),
                title: 'Informações de login',
                subtitle: 'Email e senha',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditLoginInfo(
                        local_id: widget.local_id,
                        userName: userName,
                        userEmail: widget.userEmail,
                        userPhone: userPhone,
                        userCity: userCity,
                        userState: userState,
                        userAge: userAge,
                        userAvatar: userAvatar,
                        finished_basic: finished_basic,
                        legalType: legalType, // ✅ Usar variável de estado
                        company: widget.company,
                        activeMode: widget.activeMode,
                        finished_professional: finished_professional,
                        finished_contact: finished_contact,
                        profession: widget.profession,
                        summary: widget.summary,
                        skills: widget.skills,
                        dataWorker: dataWorker,
                        dataContractor: dataContractor,
                      ),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      userName = result['name'];
                      userAge = result['age'];
                      userCity = result['city'];
                      userState = result['state'];
                      userAvatar = result['avatar'] ?? userAvatar;
                      finished_basic = true;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              /// 🔹 PROFISSIONAL
              _buildSectionCard(
                context: context,
                icon: Icons.work,
                iconColor: const Color(0xFFFF6B35),
                title: 'Informações Profissionais',
                subtitle: widget.activeMode == 'worker'
                    ? 'Profissão, resumo e habilidades'
                    : 'Tipo jurídico e empresa',
                onTap: () async {
                  final currentData = widget.activeMode == 'worker'
                      ? dataWorker
                      : dataContractor;

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfessionalInfoScreen(
                        local_id: widget.local_id,
                        userEmail: widget.userEmail,
                        userPhone: userPhone,
                        legalType: legalType, // ✅ Usar variável de estado
                        company: currentData['company'] ?? '',
                        activeMode: widget.activeMode,
                        profession: currentData['profession'] ?? '',
                        summary: currentData['summary'] ?? '',
                        skills: currentData['skills'] != null
                            ? List<String>.from(currentData['skills'])
                            : [],
                        userName: userName,
                        userAge: userAge,
                        userCity: userCity,
                        userState: userState,
                        userAvatar: userAvatar,
                        finished_professional: finished_professional,
                        dataWorker: dataWorker,
                        dataContractor: dataContractor,
                      ),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      // ✅ CORREÇÃO: Atualizar legalType
                      if (result['legalType'] != null) {
                        legalType = result['legalType'];
                        debugPrint('✅ legalType atualizado para: $legalType');
                      }

                      finished_professional = result['finished_professional'] ??
                          finished_professional;

                      if (result['dataWorker'] != null) {
                        dataWorker = Map<String, dynamic>.from(
                          result['dataWorker'],
                        );
                      }

                      if (result['dataContractor'] != null) {
                        dataContractor = Map<String, dynamic>.from(
                          result['dataContractor'],
                        );
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 24), // Espaçador
              _buildBlockedUsersCard(context),
              const SizedBox(height: 12),
              /// 🔹 DELETAR CONTA - NOVO CARD
              _buildDangerSectionCard(
                context: context,
                icon: Icons.delete_forever,
                iconColor: const Color(0xFFE74C3C),
                title: 'Deletar Conta',
                subtitle: 'Excluir permanentemente sua conta e dados',
                onTap: () async {
                  final shouldDelete = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeleteAccountScreen(
                        local_id: widget.local_id,
                        userName: userName,
                        userEmail: widget.userEmail,
                        userPhone: userPhone,
                        userCity: userCity,
                        userState: userState,
                        userAge: userAge,
                        userAvatar: userAvatar,
                        legalType: legalType,
                        company: widget.company,
                        activeMode: widget.activeMode,
                        finished_basic: finished_basic,
                        finished_professional: finished_professional,
                        finished_contact: finished_contact,
                        profession: widget.profession,
                        summary: widget.summary,
                        skills: widget.skills,
                        dataWorker: dataWorker,
                        dataContractor: dataContractor,
                      ),
                    ),
                  );

                  if (shouldDelete == true) {
                    // Conta deletada - volta pro login
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedUsersCard(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlockedUsersScreen(myUserId: widget.local_id),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.block_rounded,
                  color: Colors.red.shade600, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Usuários Bloqueados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gerencie quem você bloqueou',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _returnToHomeScreen() {
    debugPrint('✅ Voltando a tela de home legalType = $legalType');
    Navigator.pop(context, {
      'userName': userName,
      'userAge': userAge,
      'userCity': userCity,
      'userState': userState,
      'userAvatar': userAvatar,
      'contact_email': contact_email,
      'legalType': legalType, // ✅ Retornar legalType atualizado
      'userPhone': userPhone,
      'finished_basic': finished_basic,
      'finished_contact': finished_contact,
      'finished_professional': finished_professional,
      'dataWorker': dataWorker,
      'dataContractor': dataContractor,
    });
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
