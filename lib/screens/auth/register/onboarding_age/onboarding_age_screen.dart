import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dartobra_new/screens/auth/register/completed_signup/completed_signup_screen.dart';

class OnboardingAge extends StatefulWidget {
  final String email;
  final String password;

  const OnboardingAge({
    Key? key,
    required this.email,
    required this.password,
  }) : super(key: key);

  @override
  State<OnboardingAge> createState() => _OnboardingAgeState();
}

class _OnboardingAgeState extends State<OnboardingAge>
    with SingleTickerProviderStateMixin {
  // Data de nascimento
  int? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;

  bool _termsAccepted = false;
  bool _isAgeValid = false;
  bool _ageChecked = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<int> _days = List.generate(31, (i) => i + 1);
  final List<Map<String, dynamic>> _months = [
    {'label': 'Janeiro', 'value': 1},
    {'label': 'Fevereiro', 'value': 2},
    {'label': 'Março', 'value': 3},
    {'label': 'Abril', 'value': 4},
    {'label': 'Maio', 'value': 5},
    {'label': 'Junho', 'value': 6},
    {'label': 'Julho', 'value': 7},
    {'label': 'Agosto', 'value': 8},
    {'label': 'Setembro', 'value': 9},
    {'label': 'Outubro', 'value': 10},
    {'label': 'Novembro', 'value': 11},
    {'label': 'Dezembro', 'value': 12},
  ];

  List<int> get _years {
    final current = DateTime.now().year;
    return List.generate(100, (i) => current - i);
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkAge() {
    if (_selectedDay == null ||
        _selectedMonth == null ||
        _selectedYear == null) return;

    final birthDate =
        DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
    final today = DateTime.now();

    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    setState(() {
      _ageChecked = true;
      _isAgeValid = age >= 18;
    });
  }

  bool get _canProceed =>
      _isAgeValid && _termsAccepted && _ageChecked;

  Future<void> _openTermsOfUse() async {
    final uri = Uri.parse(
        'https://maodeobraoficial.com/secundary-pages-html/privacy.html');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('Não foi possível abrir o link.')),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(
        'https://maodeobraoficial.com/secundary-pages-html/privacy.html');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('Não foi possível abrir o link.')),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  void _proceed() {
    if (!_canProceed) return;

    final birthDate =
        DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CompletedSignup(
          email: widget.email,
          password: widget.password,
          age: age,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1F36),
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Progress Indicator — passo 2 de 3 ───────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenHeight * 0.01,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade600]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Conteúdo ─────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.06),
                    child: Column(
                      children: [
                        SizedBox(height: screenHeight * 0.035),

                        // ─── Ícone ─────────────────────────────────
                        Container(
                          width: screenWidth * 0.24,
                          height: screenWidth * 0.24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.deepOrange.shade500,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.35),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.cake_rounded,
                            size: screenWidth * 0.11,
                            color: Colors.white,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.025),

                        Text(
                          'Verificação de Idade',
                          style: TextStyle(
                            fontSize: screenHeight * 0.034,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1F36),
                            letterSpacing: -0.5,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.008),

                        Text(
                          'É necessário ter 18 anos ou mais\npara usar a plataforma.',
                          style: TextStyle(
                            fontSize: screenHeight * 0.018,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: screenHeight * 0.035),

                        // ─── Seletores de data ─────────────────────
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.05),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data de nascimento',
                                style: TextStyle(
                                  fontSize: screenHeight * 0.018,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1F36),
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.018),
                              Row(
                                children: [
                                  // Dia
                                  Expanded(
                                    flex: 2,
                                    child: _buildDropdown<int>(
                                      value: _selectedDay,
                                      hint: 'Dia',
                                      items: _days,
                                      itemLabel: (v) => v.toString().padLeft(2, '0'),
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedDay = v;
                                          _ageChecked = false;
                                          _isAgeValid = false;
                                        });
                                        if (_selectedDay != null &&
                                            _selectedMonth != null &&
                                            _selectedYear != null) {
                                          _checkAge();
                                        }
                                      },
                                      screenHeight: screenHeight,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Mês
                                  Expanded(
                                    flex: 3,
                                    child: _buildDropdown<int>(
                                      value: _selectedMonth,
                                      hint: 'Mês',
                                      items: _months
                                          .map((m) => m['value'] as int)
                                          .toList(),
                                      itemLabel: (v) => _months.firstWhere(
                                          (m) => m['value'] == v)['label'],
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedMonth = v;
                                          _ageChecked = false;
                                          _isAgeValid = false;
                                        });
                                        if (_selectedDay != null &&
                                            _selectedMonth != null &&
                                            _selectedYear != null) {
                                          _checkAge();
                                        }
                                      },
                                      screenHeight: screenHeight,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Ano
                                  Expanded(
                                    flex: 3,
                                    child: _buildDropdown<int>(
                                      value: _selectedYear,
                                      hint: 'Ano',
                                      items: _years,
                                      itemLabel: (v) => v.toString(),
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedYear = v;
                                          _ageChecked = false;
                                          _isAgeValid = false;
                                        });
                                        if (_selectedDay != null &&
                                            _selectedMonth != null &&
                                            _selectedYear != null) {
                                          _checkAge();
                                        }
                                      },
                                      screenHeight: screenHeight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ─── Feedback de idade ─────────────────────
                        if (_ageChecked) ...[
                          SizedBox(height: screenHeight * 0.018),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.05,
                              vertical: screenHeight * 0.018,
                            ),
                            decoration: BoxDecoration(
                              color: _isAgeValid
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isAgeValid
                                    ? Colors.green.shade200
                                    : Colors.red.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _isAgeValid
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isAgeValid
                                        ? Icons.check_circle_rounded
                                        : Icons.block_rounded,
                                    color: _isAgeValid
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isAgeValid
                                            ? 'Idade confirmada!'
                                            : 'Acesso não permitido',
                                        style: TextStyle(
                                          fontSize: screenHeight * 0.018,
                                          fontWeight: FontWeight.w700,
                                          color: _isAgeValid
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _isAgeValid
                                            ? 'Você tem mais de 18 anos. Pode continuar!'
                                            : 'É necessário ter 18 anos ou mais para se cadastrar.',
                                        style: TextStyle(
                                          fontSize: screenHeight * 0.015,
                                          color: _isAgeValid
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: screenHeight * 0.025),

                        // ─── Documentos para leitura ────────────────
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Leia antes de continuar',
                            style: TextStyle(
                              fontSize: screenHeight * 0.017,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1F36),
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.012),

                        // Botão — Termos de Uso
                        _buildDocumentButton(
                          icon: Icons.description_rounded,
                          iconColor: Colors.blue.shade600,
                          iconBg: Colors.blue.shade50,
                          title: 'Termos de Uso',
                          subtitle: 'Regras e condições de uso da plataforma',
                          onTap: _openTermsOfUse,
                          screenHeight: screenHeight,
                          screenWidth: screenWidth,
                        ),

                        SizedBox(height: screenHeight * 0.012),

                        // Botão — Política de Privacidade
                        _buildDocumentButton(
                          icon: Icons.privacy_tip_rounded,
                          iconColor: Colors.purple.shade600,
                          iconBg: Colors.purple.shade50,
                          title: 'Política de Privacidade',
                          subtitle: 'Como seus dados são coletados e usados',
                          onTap: _openPrivacyPolicy,
                          screenHeight: screenHeight,
                          screenWidth: screenWidth,
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        // ─── Checkbox de aceite ──────────────────────
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.04,
                            vertical: screenHeight * 0.016,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: _termsAccepted
                                ? Border.all(
                                    color: Colors.blue.shade300, width: 1.5)
                                : Border.all(
                                    color: Colors.grey.shade200, width: 1),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Checkbox customizado
                              GestureDetector(
                                onTap: () => setState(
                                    () => _termsAccepted = !_termsAccepted),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 26,
                                  height: 26,
                                  margin: const EdgeInsets.only(top: 1),
                                  decoration: BoxDecoration(
                                    gradient: _termsAccepted
                                        ? LinearGradient(
                                            colors: [
                                              Colors.blue.shade400,
                                              Colors.blue.shade700,
                                            ],
                                          )
                                        : null,
                                    color: _termsAccepted
                                        ? null
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(7),
                                    border: _termsAccepted
                                        ? null
                                        : Border.all(
                                            color: Colors.grey.shade400,
                                            width: 2),
                                  ),
                                  child: _termsAccepted
                                      ? const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 17)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: screenHeight * 0.016,
                                      color: Colors.grey[700],
                                      height: 1.6,
                                    ),
                                    children: [
                                      const TextSpan(
                                          text: 'Li e concordo com os '),
                                      TextSpan(
                                        text: 'Termos de Uso',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w700,
                                          decoration:
                                              TextDecoration.underline,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = _openTermsOfUse,
                                      ),
                                      const TextSpan(text: ' e a '),
                                      TextSpan(
                                        text: 'Política de Privacidade',
                                        style: TextStyle(
                                          color: Colors.purple.shade700,
                                          fontWeight: FontWeight.w700,
                                          decoration:
                                              TextDecoration.underline,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = _openPrivacyPolicy,
                                      ),
                                      const TextSpan(
                                          text:
                                              ' da Mão de Obra Oficial.'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.035),

                        // ─── Botão Finalizar Cadastro ───────────────
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.065,
                          child: ElevatedButton(
                            onPressed: _canProceed ? _proceed : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: _canProceed
                                    ? LinearGradient(
                                        colors: [
                                          Colors.orange.shade400,
                                          Colors.deepOrange.shade500,
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.grey.shade300,
                                          Colors.grey.shade300,
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _canProceed
                                    ? [
                                        BoxShadow(
                                          color:
                                              Colors.orange.withOpacity(0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                          spreadRadius: -5,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.how_to_reg_rounded,
                                      color: _canProceed
                                          ? Colors.white
                                          : Colors.grey[500],
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Finalizar Cadastro',
                                      style: TextStyle(
                                        fontSize: screenHeight * 0.022,
                                        fontWeight: FontWeight.bold,
                                        color: _canProceed
                                            ? Colors.white
                                            : Colors.grey[500],
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.04),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentButton({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required double screenHeight,
    required double screenWidth,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.015,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: screenHeight * 0.017,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1F36),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: screenHeight * 0.014,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ler',
                    style: TextStyle(
                      fontSize: screenHeight * 0.014,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded, color: iconColor, size: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
    required double screenHeight,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: screenHeight * 0.016,
            ),
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[500], size: 20),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                style: TextStyle(
                  fontSize: screenHeight * 0.016,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A1F36),
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}