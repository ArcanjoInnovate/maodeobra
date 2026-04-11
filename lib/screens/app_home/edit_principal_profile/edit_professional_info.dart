import 'package:dartobra_new/screens/screens_init/register_screens/onbo/components.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProfessionalInfoScreen extends StatefulWidget {
  final String local_id;
  final String userName;
  final String userEmail;
  final String userPhone;
  final bool finished_professional;
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

  const EditProfessionalInfoScreen({
    super.key,
    required this.local_id,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.userCity,
    required this.userState,
    required this.userAge,
    required this.finished_professional,
    required this.userAvatar,
    required this.legalType,
    required this.company,
    required this.activeMode,
    required this.profession,
    required this.summary,
    required this.skills,
    required this.dataWorker,
    required this.dataContractor,
  });

  @override
  State<EditProfessionalInfoScreen> createState() =>
      _EditProfessionalInfoScreenState();
}

class _EditProfessionalInfoScreenState
    extends State<EditProfessionalInfoScreen> {
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  static const int maxSkills = 4; // ✅ Limite de habilidades

  String? selectedLegalType;
  String? selectedProfession;
  String? professionalSummary;
  String? companyName;
  List<String> selectedSkills = [];
  bool _isSaving = false;

  bool _summaryIsDefined(String s) {
    final v = s.trim().toLowerCase();
    return v.isNotEmpty && v != 'não definido' && v != 'nao definido';
  }

  bool _skillIsValid(String s) {
    final v = s.trim().toLowerCase();
    return v.isNotEmpty &&
        v != 'nenhuma habilidade definida' &&
        v != 'nenhuma habilidade' &&
        v != 'não definido' &&
        v != 'nao definido';
  }

  @override
  void initState() {
    super.initState();

    selectedLegalType = widget.legalType.isNotEmpty ? widget.legalType : 'PF';
    selectedProfession = widget.profession.isNotEmpty ? widget.profession : null;

    // ✅ Só preenche o resumo se for um valor real
    if (_summaryIsDefined(widget.summary)) {
      professionalSummary = widget.summary;
      _summaryController.text = widget.summary;
    }

    companyName = widget.company;
    _companyController.text = widget.company;

    // ✅ Filtra skills inválidas ao inicializar e limita a 4
    selectedSkills = widget.skills.where(_skillIsValid).take(maxSkills).toList();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (selectedLegalType == 'PJ' && (companyName == null || companyName!.trim().isEmpty)) {
      _showSnackBar('Nome da empresa é obrigatório para Pessoa Jurídica', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dataPath = widget.activeMode == 'worker' ? 'data_worker' : 'data_contractor';

      Map<String, dynamic> dataToSave = {
        'profession': selectedProfession ?? '',
        'summary': professionalSummary ?? '',
      };

      if (widget.activeMode == 'worker') {
        dataToSave['skills'] = selectedSkills;
      }

      Map<String, dynamic> userUpdate = {
        'legalType': selectedLegalType,
        'finished_professional': true,
      };

      if (selectedLegalType == 'PJ') {
        dataToSave['company'] = companyName!.trim();
      } else {
        dataToSave['company'] = '';
      }

      await _database.child('Users').child(widget.local_id).update(userUpdate);
      await _database
          .child('Users')
          .child(widget.local_id)
          .child(dataPath)
          .update(dataToSave);

      _showSnackBar('Informações atualizadas!', isError: false);
      await Future.delayed(const Duration(seconds: 1));

      Map<String, dynamic> updatedWorker = Map<String, dynamic>.from(widget.dataWorker);
      Map<String, dynamic> updatedContractor = Map<String, dynamic>.from(widget.dataContractor);

      if (widget.activeMode == 'worker') {
        updatedWorker = {...updatedWorker, ...dataToSave};
      } else {
        updatedContractor = {...updatedContractor, ...dataToSave};
      }

      final returnData = {
        'legalType': selectedLegalType,
        'company': selectedLegalType == 'PJ' ? companyName!.trim() : '',
        'finished_professional': true,
        'dataWorker': updatedWorker,
        'dataContractor': updatedContractor,
      };

      Navigator.pop(context, returnData);
    } catch (e) {
      debugPrint('Erro ao salvar: $e');
      _showSnackBar('Erro ao salvar alterações', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Informações Profissionais',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tipo Jurídico',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildLegalTypeOption('PF', 'Pessoa Física')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildLegalTypeOption('PJ', 'Pessoa Jurídica')),
                ],
              ),

              if (selectedLegalType == 'PJ') ...[
                const SizedBox(height: 20),
                const Text(
                  'Nome da Empresa',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _companyController,
                  onChanged: (value) => companyName = value,
                  decoration: InputDecoration(
                    hintText: 'Digite o nome da empresa',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    prefixIcon: const Icon(Icons.business, color: Color(0xFF6B7280)),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              ProfessionDropdown(
                initialValue: selectedProfession,
                onChanged: (value) => setState(() => selectedProfession = value),
              ),

              const SizedBox(height: 20),

              const Text(
                'Resumo Profissional',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _summaryController,
                maxLines: 5,
                maxLength: 500,
                onChanged: (value) => professionalSummary = value,
                decoration: InputDecoration(
                  hintText: 'Conte um pouco sobre você e sua experiência profissional...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                ),
              ),

              if (widget.activeMode == 'worker') ...[
                const SizedBox(height: 20),
                SkillsField(
                  initialSkills: selectedSkills,
                  onSkillsChanged: (skills) {
                    // ✅ Filtra skills inválidas e limita a 4
                    final validSkills = skills.where(_skillIsValid).toList();
                    if (validSkills.length > maxSkills) {
                      _showSnackBar('Você pode adicionar no máximo $maxSkills habilidades', isError: true);
                      setState(() => selectedSkills = validSkills.take(maxSkills).toList());
                    } else {
                      setState(() => selectedSkills = validSkills);
                    }
                  },
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Salvar Alterações',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalTypeOption(String value, String label) {
    final isSelected = selectedLegalType == value;

    return InkWell(
      onTap: () {
        setState(() {
          selectedLegalType = value;
          if (value == 'PF') {
            companyName = '';
            _companyController.clear();
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.1)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              value == 'PF' ? Icons.person : Icons.business,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[600],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}