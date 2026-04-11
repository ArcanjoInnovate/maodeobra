// lib/widgets/vacancy_card.dart
// ✅ VERSÃO FINAL - Abre tela diferente para vaga própria

import 'package:dartobra_new/screens/search/my_vacancy_details_screen.dart';
import 'package:dartobra_new/screens/search/vacancy_details_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/search/vacancy_model.dart';

class VacancyCard extends StatelessWidget {
  final VacancyModel vacancy;
  final Function(int)? onNavigateToTab;

  const VacancyCard({
    Key? key,
    required this.vacancy,
    this.onNavigateToTab,
  }) : super(key: key);

  bool get _isOwnVacancy {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return currentUserId != null && vacancy.localId == currentUserId;
  }

  // localId do usuário atual (uid do Firebase)
  String get _localId =>
      FirebaseAuth.instance.currentUser?.uid ?? vacancy.localId;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isOwnVacancy ? Colors.green.shade300 : Colors.grey.shade300,
          width: _isOwnVacancy ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (_isOwnVacancy) {
            _navigateToMyVacancy(context);
          } else {
            _navigateToDetail(context);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isOwnVacancy
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isOwnVacancy
                            ? Colors.green.shade200
                            : Colors.blue.shade200,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.work_outline,
                      color: _isOwnVacancy
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vacancy.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isOwnVacancy) ...[
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
                                    Icon(Icons.check_circle,
                                        size: 12,
                                        color: Colors.green.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Minha',
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
                        if (vacancy.company.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.business_outlined,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  vacancy.company,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline,
                        size: 14, color: Colors.teal.shade800),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        vacancy.profession,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${vacancy.city}, ${vacancy.state}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (vacancy.salary.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.shade200, width: 0.5),
                      ),
                      child: Text(
                        vacancy.salary,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _isOwnVacancy
                    ? _buildViewButton(context)
                    : _buildViewDetailsButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _navigateToMyVacancy(context),
      icon: const Icon(Icons.visibility, size: 16),
      label: const Text('Ver minha vaga'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.green.shade700,
        backgroundColor: Colors.green.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.green.shade300, width: 1),
        ),
      ),
    );
  }

  Widget _buildViewDetailsButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _navigateToDetail(context),
      icon: const Icon(Icons.arrow_forward, size: 16),
      label: const Text('Ver detalhes'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VacancyDetailPage(
          vacancy: vacancy,
          vacancyId: vacancy.id,
          reportedId: vacancy.localId,
        ),
      ),
    );
  }

  void _navigateToMyVacancy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyVacancyDetailPage(
          vacancy: vacancy,
          localId: _localId,
          onEditVacancy: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Vá para a tela de Vagas para editar sua vaga',
                ),
                backgroundColor: Colors.orange.shade700,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}