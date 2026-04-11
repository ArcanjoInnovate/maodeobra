/* import 'package:flutter/material.dart';
import 'package:dartobra_new/screens/auth/register/onboarding_second/components.dart';



class OnboardingSecond extends StatefulWidget {
  final String local_id;
  final String email;
  final bool is_contractor;
  final Map<String, dynamic> basicInfo;

  OnboardingSecond({
    required this.email,
    required this.local_id,
    required this.is_contractor,
    required this.basicInfo,
  });

  @override
  State<OnboardingSecond> createState() => _OnboardingSecond();
}

class _OnboardingSecond extends State<OnboardingSecond> {
  String? selectedProfession;
  String professionalSummary = '';
  List<String> skills = [];

  // Validação e navegação
  void _continueToNextScreen() {
    // Validar profissão
    if (selectedProfession == null || selectedProfession!.isEmpty) {
      _showError('Por favor, selecione uma profissão');
      return;
    }

    // Validar resumo profissional
    if (professionalSummary.trim().isEmpty) {
      _showError('Por favor, adicione um resumo profissional');
      return;
    }

    if (professionalSummary.trim().length < 50) {
      _showError('O resumo profissional deve ter pelo menos 50 caracteres');
      return;
    }

    // Validar habilidades
    if (skills.isEmpty) {
      _showError('Por favor, adicione pelo menos uma habilidade');
      return;
    }

    if (skills.length < 3) {
      _showError('Adicione pelo menos 3 habilidades');
      return;
    }

    // Criar objeto com informações profissionais
    Map<String, dynamic> professionalInfo = {
      'profession': selectedProfession,
      'summary': professionalSummary.trim(),
      'skills': skills,
    };

    // AQUI: Navegar para próxima tela (verificação de email)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingThirty(
          // Sua terceira tela
          basicInfo: widget.basicInfo,
        ),
      ),
    );

    print('Dados básicos: ${widget.basicInfo}');
    print('Dados profissionais: $professionalInfo');
  }

  // Mostrar erro
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(fontSize: 15))),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // Progress Indicator fixo no topo
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.05),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Conteúdo scrollável
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: screenHeight * 0.03),
                      Text(
                        'Informações Profissionais',
                        style: TextStyle(
                          fontSize: screenHeight * 0.030,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        'Conte-nos sobre sua experiência profissional',
                        style: TextStyle(
                          fontSize: screenHeight * 0.017,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.start,
                      ),
                      SizedBox(height: screenHeight * 0.04),

                      // Dropdown de profissão
                      ProfessionDropdown(
                        onChanged: (value) {
                          setState(() {
                            selectedProfession = value;
                          });
                        },
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Campo de resumo profissional
                      ProfessionalSummaryField(
                        maxCharacters: 500,
                        onChanged: (text) {
                          setState(() {
                            professionalSummary = text;
                          });
                        },
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Campo de habilidades
                      SkillsField(
                        onSkillsChanged: (newSkills) {
                          setState(() {
                            skills = newSkills;
                          });
                        },
                      ),

                      SizedBox(height: screenHeight * 0.03),

                      // Botões de navegação
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.018,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                  width: 2,
                                ),
                                foregroundColor: const Color(0xFF374151),
                              ),
                              child: const Text(
                                'Voltar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _continueToNextScreen,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.018,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Continuar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.03),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 */