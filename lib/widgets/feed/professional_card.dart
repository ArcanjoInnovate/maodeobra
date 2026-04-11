import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/screens/search/professional_profile_screen.dart';
import 'package:dartobra_new/screens/search/my_professional_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfessionalCard extends StatelessWidget {
  final ProfessionalModel professional;
  final Function(int)? onNavigateToTab; // ✅ Callback para navegar mantendo nav bar

  const ProfessionalCard({
    Key? key,
    required this.professional,
    this.onNavigateToTab, // ✅ Opcional
  }) : super(key: key);

  bool get _isOwnProfile {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return currentUserId != null && professional.localId == currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser!.uid;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isOwnProfile ? Colors.green.shade300 : Colors.grey.shade300,
          width: _isOwnProfile ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (_isOwnProfile) {
            // ✅ Abre tela de visualização do próprio perfil
            _navigateToMyProfile(context);
          } else {
            // ✅ Abre tela normal de perfil de outro profissional
            _navigateToDetail(context, userId);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar com borda diferenciada
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isOwnProfile 
                        ? Colors.green.shade400 
                        : Colors.blue.shade200,
                    width: _isOwnProfile ? 3 : 2,
                  ),
                ),
                child: Hero(
                  tag: 'professional_${professional.id}',
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage: professional.avatar.isNotEmpty
                        ? NetworkImage(professional.avatar)
                        : null,
                    backgroundColor: _isOwnProfile 
                        ? Colors.green.shade100 
                        : Colors.blue.shade100,
                    child: professional.avatar.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 32,
                            color: _isOwnProfile 
                                ? Colors.green.shade700 
                                : Colors.blue.shade700,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Informações
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome e badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            professional.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Badge "Meu Perfil"
                        if (_isOwnProfile) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.green.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Meu',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Profissão
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        professional.profession,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Localização
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${professional.city}, ${professional.state}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Skills (opcional)
                    if (professional.skills.isNotEmpty &&
                        !professional.skills.contains('Nenhuma habilidade definida')) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: professional.skills.take(2).map((skill) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              skill,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Ícone/Botão
              const SizedBox(width: 8),
              if (_isOwnProfile)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.shade300,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.visibility,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Navegar para perfil de outro profissional
  void _navigateToDetail(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfessionalProfilePage(
          professional: professional,
          vacancyId: professional.id,
          reportedId: professional.localId,
          reportId: userId,
        ),
      ),
    );
  }

  // ✅ NOVO: Navegar para MEU perfil profissional
  void _navigateToMyProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyProfessionalProfilePage(
          professional: professional,
          onEditProfile: () {
            // ✅ Quando clicar em "Editar Perfil"
            if (onNavigateToTab != null) {
              // Volta para a tela anterior
              Navigator.pop(context);
              // Navega para a tab 3 (VacancyManagement que contém WorkerProfileActivation)
              onNavigateToTab!(3);
            } else {
              // Fallback: apenas volta
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Acesse a aba "Vagas" para editar seu perfil profissional',
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}