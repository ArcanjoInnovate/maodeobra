import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dartobra_new/services/complaint/complaint_user_service.dart';

class ComplaintUser extends StatefulWidget {
  final String reportedId;
  final String reportedName;
  final String reportedEmail;

  const ComplaintUser({
    Key? key,
    required this.reportedId,
    required this.reportedName,
    required this.reportedEmail,
  }) : super(key: key);

  @override
  State<ComplaintUser> createState() => _ComplaintUserState();
}

class _ComplaintUserState extends State<ComplaintUser>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _descriptionController = TextEditingController();
  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  // ── State ─────────────────────────────────────────────────────────────────
  int     _currentStep  = 0; // 0 = motivo | 1 = gravidade | 2 = descrição
  bool    _isSubmitting = false;
  bool    _submitted    = false;
  String? _selectedReason;
  String? _selectedSeverity;

  // ── Dados ─────────────────────────────────────────────────────────────────
  static const _accent = Color(0xFFDC2626); // red-600

  final List<_ReasonOption> _reasons = [
    _ReasonOption('Perfil falso ou fraudulento', Icons.manage_accounts_outlined),
    _ReasonOption('Comportamento inadequado',    Icons.block_outlined),
    _ReasonOption('Usuario menor de idade',      Icons.lock_outlined),
    _ReasonOption('Assédio ou bullying',         Icons.sentiment_very_dissatisfied_outlined),
    _ReasonOption('Linguagem ofensiva',          Icons.warning_amber_outlined),
    _ReasonOption('Fotos inapropriadas',         Icons.hide_image_outlined),
    _ReasonOption('Golpe ou fraude',             Icons.gpp_bad_outlined),
    _ReasonOption('Spam ou propaganda',          Icons.mark_email_unread_outlined),
    _ReasonOption('Informações falsas',          Icons.fact_check_outlined),
    _ReasonOption('Uso indevido da plataforma',  Icons.report_gmailerrorred_outlined),
    _ReasonOption('Discriminação',               Icons.record_voice_over_outlined),
    _ReasonOption('Outro motivo',                Icons.more_horiz_outlined),
  ];

  final List<_SeverityOption> _severities = [
    _SeverityOption('Leve',  'Incômodo pontual sem dano grave',            Color(0xFFF59E0B), Icons.sentiment_neutral_outlined),
    _SeverityOption('Média', 'Comportamento recorrente ou dano moderado',  Color(0xFFF97316), Icons.sentiment_dissatisfied_outlined),
    _SeverityOption('Grave', 'Situação urgente ou risco real',             Color(0xFFDC2626), Icons.sentiment_very_dissatisfied_outlined),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _nextStep() {
    if (_currentStep == 0 && _selectedReason == null) {
      _toast('Selecione o motivo da denúncia');
      return;
    }
    if (_currentStep == 1 && _selectedSeverity == null) {
      _toast('Selecione o nível de gravidade');
      return;
    }
    _animateStep(() => setState(() => _currentStep++));
  }

  void _prevStep() => _animateStep(() => setState(() => _currentStep--));

  void _animateStep(VoidCallback change) {
    _fadeCtrl.reverse().then((_) {
      _slideCtrl.reset();
      change();
      _fadeCtrl.forward();
      _slideCtrl.forward();
    });
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final desc = _descriptionController.text.trim();
    if (desc.isEmpty) { _toast('Escreva uma descrição'); return; }
    if (desc.length < 20) { _toast('Mínimo de 20 caracteres'); return; }

    setState(() => _isSubmitting = true);
    try {
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      await ComplaintService().createComplaint(
        reportId:    userId!,
        reportedId:  widget.reportedId,
        reason:      _selectedReason!,
        severity:    _selectedSeverity!,
        description: desc,
      );
      _animateStep(() => setState(() { _isSubmitting = false; _submitted = true; }));
    } catch (_) {
      setState(() => _isSubmitting = false);
      _toast('Erro ao enviar. Tente novamente.');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: const Color(0xFF1C1C1E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: _buildAppBar(),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1C1C1E)),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Denunciar Usuário',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1C1C1E),
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade100),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _buildStepper(),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _buildCurrentStep(),
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  // ── Stepper ────────────────────────────────────────────────────────────────
  Widget _buildStepper() {
    final steps = ['Motivo', 'Gravidade', 'Descrição'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepIndex = i ~/ 2;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 2,
                    decoration: BoxDecoration(
                      color: stepIndex < _currentStep
                          ? _accent
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
              final index   = i ~/ 2;
              final done    = index < _currentStep;
              final current = index == _currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: done
                      ? _accent
                      : current
                          ? _accent.withOpacity(0.12)
                          : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: current ? _accent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: current ? _accent : Colors.grey.shade400,
                          ),
                        ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.asMap().entries.map((e) {
              final active = e.key <= _currentStep;
              return Text(
                e.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? const Color(0xFF1C1C1E) : Colors.grey.shade400,
                  letterSpacing: 0.2,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Steps ──────────────────────────────────────────────────────────────────
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildReasonStep();
      case 1: return _buildSeverityStep();
      case 2: return _buildDescriptionStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildReasonStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Usuário denunciado
          _buildReportedUserCard(),
          const SizedBox(height: 20),

          _buildStepHeader(
            'Qual é o motivo?',
            'Selecione a opção que melhor descreve o problema.',
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.6,
            ),
            itemCount: _reasons.length,
            itemBuilder: (_, i) {
              final r        = _reasons[i];
              final selected = _selectedReason == r.label;
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = r.label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? _accent.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _accent : Colors.grey.shade200,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Icon(r.icon, size: 16,
                          color: selected ? _accent : Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? _accent : const Color(0xFF1C1C1E),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSeverityStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Qual a gravidade?',
            'Isso nos ajuda a priorizar a análise da denúncia.',
          ),
          const SizedBox(height: 16),
          ..._severities.map((s) {
            final selected = _selectedSeverity == s.label;
            return GestureDetector(
              onTap: () => setState(() => _selectedSeverity = s.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: selected ? s.color.withOpacity(0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? s.color : Colors.grey.shade200,
                    width: selected ? 1.5 : 1,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: s.color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
                      : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s.icon, size: 20, color: s.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: selected ? s.color : const Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.subtitle,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? s.color : Colors.transparent,
                        border: Border.all(
                          color: selected ? s.color : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDescriptionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Descreva o problema',
            'Quanto mais detalhes, mais rápida será a análise.',
          ),
          const SizedBox(height: 16),

          // Resumo das seleções anteriores
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                _buildSummaryChip(_selectedReason ?? '', _accent),
                const SizedBox(width: 8),
                _buildSummaryChip(
                  _selectedSeverity ?? '',
                  _severities.firstWhere(
                    (s) => s.label == _selectedSeverity,
                    orElse: () => _severities.first,
                  ).color,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Campo de texto
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _descriptionController,
              maxLines: 8,
              maxLength: 500,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1C1C1E),
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: 'Descreva detalhadamente o comportamento inadequado do usuário...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _accent.withOpacity(0.4), width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Mínimo de 20 caracteres',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Reported user card ─────────────────────────────────────────────────────
  Widget _buildReportedUserCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_off_rounded, size: 22, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reportedName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.reportedEmail,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Denunciado',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary chip ───────────────────────────────────────────────────────────
  Widget _buildSummaryChip(String label, Color color) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isLast    = _currentStep == 2;
    final canSubmit = _descriptionController.text.trim().length >= 20;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: _prevStep,
                child: Container(
                  height: 52,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF1C1C1E)),
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: isLast
                  ? (canSubmit && !_isSubmitting ? _submit : null)
                  : _nextStep,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: isLast
                      ? (canSubmit ? _accent : Colors.grey.shade300)
                      : _accent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    if (!isLast || canSubmit)
                      BoxShadow(
                        color: _accent.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Enviar Denúncia' : 'Continuar',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isLast ? Icons.send_rounded : Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success ────────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 44,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Denúncia enviada!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C1E),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Nossa equipe vai analisar o caso em breve. Obrigado por ajudar a manter a plataforma segura.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C1E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Voltar ao início',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildStepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────
class _ReasonOption {
  final String   label;
  final IconData icon;
  const _ReasonOption(this.label, this.icon);
}

class _SeverityOption {
  final String   label;
  final String   subtitle;
  final Color    color;
  final IconData icon;
  const _SeverityOption(this.label, this.subtitle, this.color, this.icon);
}