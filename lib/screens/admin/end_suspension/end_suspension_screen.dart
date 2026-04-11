import 'package:flutter/material.dart';
//import 'package:dartobra_new/screens/home/home_screen.dart';
import 'package:firebase_database/firebase_database.dart';

class SuspensionEndScreen extends StatefulWidget {
  final String occurrenceDate;
  final String reason;
  final String description;
  final Map<String, dynamic> userData;
  final String local_id;
  final String type;

  const SuspensionEndScreen({
    Key? key,
    required this.occurrenceDate,
    required this.type,
    required this.local_id,
    required this.userData,
    required this.reason,
    required this.description,
  }) : super(key: key);

  @override
  State<SuspensionEndScreen> createState() => _SuspensionEndScreenState();
}

class _SuspensionEndScreenState extends State<SuspensionEndScreen> {
  bool acceptedTerms = false;

  Future<bool> _clearSuspension() async {
    DatabaseReference ref;
    
    if (widget.type == 'contractor') {
      ref = FirebaseDatabase.instance.ref().child('Users/${widget.local_id}');
    } else if (widget.type == 'employee') {
      ref = FirebaseDatabase.instance.ref().child('Funcionarios/${widget.local_id}');
    } else {
      return false;
    }

    try {
      await ref.update({
        'suspension': {
          'data': '',
          'description': '',
          'motive': '',
          'init': '',
          'end': '',
        },
      });
      print('✅ Suspensão removida com sucesso');
      return true;
    } catch (e) {
      print('❌ Erro ao limpar suspensão: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade50,
              Colors.white,
              Colors.green.shade50,
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
                    // Header
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[600]!, Colors.green.shade700],
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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Suspensão Finalizada',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sua suspensão chegou ao fim',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 10,
                        right: 10,
                        bottom: 24.0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mensagem de Boas-vindas
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border(
                                  left: BorderSide(
                                    color: Colors.green.shade500,
                                    width: 4,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.celebration,
                                    size: 24,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bem-vindo de Volta!',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'O período de suspensão terminou. Para continuar usando nossos serviços, você precisa aceitar os termos de uso novamente.',
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

                            // Informações da Suspensão
                            Text(
                              'RESUMO DA SUSPENSÃO',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Data do Ocorrido
                            _buildInfoRow(
                              icon: Icons.calendar_today,
                              label: 'Data do Ocorrido',
                              value: widget.occurrenceDate,
                            ),
                            const SizedBox(height: 12),

                            // Motivo
                            _buildInfoRow(
                              icon: Icons.info_outline,
                              label: 'Motivo',
                              value: widget.reason,
                            ),
                            const SizedBox(height: 12),

                            // Descrição
                            _buildInfoRow(
                              icon: Icons.description_outlined,
                              label: 'Descrição',
                              value: widget.description,
                            ),

                            const SizedBox(height: 24),

                            // Termos de Uso
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.gavel,
                                        size: 20,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'TERMOS DE USO',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Ao continuar, você concorda em:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildTermItem('Respeitar todas as regras da plataforma'),
                                  _buildTermItem('Manter conduta profissional e ética'),
                                  _buildTermItem('Não repetir violações anteriores'),
                                  _buildTermItem('Estar ciente de que novas violações podem resultar em suspensão permanente'),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Checkbox de Aceite
                            InkWell(
                              onTap: () {
                                setState(() {
                                  acceptedTerms = !acceptedTerms;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: acceptedTerms
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: acceptedTerms
                                      ? Colors.green.shade50
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: acceptedTerms
                                            ? Colors.green
                                            : Colors.white,
                                        border: Border.all(
                                          color: acceptedTerms
                                              ? Colors.green
                                              : Colors.grey.shade400,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: acceptedTerms
                                          ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Li e concordo com os termos de uso',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: acceptedTerms
                                              ? Colors.green.shade900
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Botão de Confirmar
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: acceptedTerms
                                    ? () async {
                                        // Mostrar loading
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );

                                        // Limpar suspensão
                                        bool sucesso = await _clearSuspension();

                                        // Fechar loading
                                        Navigator.pop(context);

                                        if (sucesso) {
                                          // Navegar baseado no tipo
                                          if (widget.type == 'employee') {
                                            
                                          } else if (widget.type == 'contractor') {
                                            
                                          }
                                        } else {
                                          // Mostrar erro
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Erro ao processar. Tente novamente.',
                                              ),
                                              backgroundColor: Colors.red,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  backgroundColor: acceptedTerms
                                      ? Colors.green[600]
                                      : Colors.grey[300],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: acceptedTerms ? 4 : 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      acceptedTerms
                                          ? Icons.check_circle
                                          : Icons.lock_outline,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      acceptedTerms
                                          ? 'Confirmar e Continuar'
                                          : 'Aceite os Termos para Continuar',
                                      style: const TextStyle(
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
