import 'package:dartobra_new/services/vacancy/professional_status_service.dart';
import 'package:flutter/material.dart';

class ProfessionalStatusControlWidget extends StatefulWidget {
  final bool initialIsActive;

  /// ID do usuário no nó Users — necessário para persistir no Firebase
  final String localId;

  /// ID do documento em professionals — evita re-query desnecessária
  final String professionalId;

  /// Chamado após mudança bem-sucedida, com o novo estado (true = ativo)
  final void Function(bool isActive)? onStatusChanged;

  const ProfessionalStatusControlWidget({
    Key? key,
    required this.initialIsActive,
    required this.localId,
    required this.professionalId,
    this.onStatusChanged,
  }) : super(key: key);

  @override
  State<ProfessionalStatusControlWidget> createState() =>
      _ProfessionalStatusControlWidgetState();
}

class _ProfessionalStatusControlWidgetState
    extends State<ProfessionalStatusControlWidget> {
  late bool _isActive;
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.initialIsActive;
  }

  /// Sincroniza quando o pai reconstrói com um novo initialIsActive
  /// (ex: após recarregar dados do banco)
  @override
  void didUpdateWidget(ProfessionalStatusControlWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsActive != widget.initialIsActive) {
      setState(() => _isActive = widget.initialIsActive);
    }
  }

  Future<void> _toggleStatus() async {
    if (_isActive) {
      final confirm = await _showPauseConfirmation();
      if (confirm != true) return;
    }

    setState(() => _isChanging = true);

    try {
      // Captura o estado desejado antes de mudar qualquer coisa
      final newStatus = !_isActive;

      final success = _isActive
          ? await ProfessionalStatusService.pauseProfessionalProfile(
              localId: widget.localId,
              professionalId: widget.professionalId,
            )
          : await ProfessionalStatusService.activateProfessionalProfile(
              localId: widget.localId,
              professionalId: widget.professionalId,
            );

      if (success) {
        setState(() {
          _isActive = newStatus;
          _isChanging = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isActive
                    ? '✅ Perfil profissional ativado! Você aparecerá nas buscas.'
                    : '⏸️ Perfil profissional pausado. Você não aparecerá mais nas buscas.',
              ),
              backgroundColor:
                  _isActive ? Colors.green : Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          // Propaga o novo estado para o pai com o bool correto
          widget.onStatusChanged?.call(_isActive);
        }
      } else {
        setState(() => _isChanging = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Erro ao alterar status do perfil'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isChanging = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool?> _showPauseConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.pause_circle_outline,
                color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Pausar Perfil?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Ao pausar seu perfil profissional, você não aparecerá mais nas buscas e no feed.\n\nVocê pode reativá-lo a qualquer momento.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Pausar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isActive
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                (_isActive ? Colors.green : Colors.orange).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isActive
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isActive ? Icons.visibility : Icons.visibility_off,
                    color: _isActive ? Colors.green : Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isActive ? 'Perfil Ativo' : 'Perfil Pausado',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isActive
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isActive
                            ? 'Seu perfil está visível nas buscas'
                            : 'Seu perfil não aparece nas buscas',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isActive
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isChanging ? null : _toggleStatus,
                icon: _isChanging
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        _isActive ? Icons.pause_circle : Icons.play_circle,
                        color: Colors.white,
                      ),
                label: Text(
                  _isChanging
                      ? 'Alterando...'
                      : _isActive
                          ? 'Pausar Perfil'
                          : 'Ativar Perfil',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isActive
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}