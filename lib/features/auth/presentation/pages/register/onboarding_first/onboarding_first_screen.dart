import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dartobra_new/features/auth/presentation/pages/register/onboarding_age/onboarding_age_screen.dart';

class OnboardingFirst extends StatefulWidget {
  const OnboardingFirst({Key? key}) : super(key: key);

  @override
  State<OnboardingFirst> createState() => _OnboardingFirstState();
}

class _OnboardingFirstState extends State<OnboardingFirst>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isChecking = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isPasswordValid = false;
  bool _passwordsMatch = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validatePassword);

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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _hasLettersAndNumbers(String text) {
    if (text.isEmpty) return false;
    return RegExp(r'[a-zA-Z]').hasMatch(text) &&
        RegExp(r'[0-9]').hasMatch(text);
  }

  bool _isObviousPassword(String text) {
    if (text.isEmpty) return false;
    final obvious = ['123456', 'password', '123123', 'abc123', 'qwerty'];
    return obvious.any((pwd) => text.toLowerCase().contains(pwd));
  }

  void _validatePassword() {
    final pwd = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    setState(() {
      _isPasswordValid = pwd.length >= 6 &&
          _hasLettersAndNumbers(pwd) &&
          !_isObviousPassword(pwd);
      _passwordsMatch = confirm.isNotEmpty && pwd == confirm;
    });
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      final url = Uri.parse(
        'https://obra-7ebd9-default-rtdb.firebaseio.com/Users.json?auth=7Dc5jIxoKXWRbDJZaJ7IFahIfMTB5JcKnSjxTMsm',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data is Map) {
          for (var userData in data.values) {
            if (userData is Map && userData['email'] == email) return true;
          }
        }
        return false;
      } else {
        throw Exception('Erro ao verificar email');
      }
    } catch (e) {
      throw Exception('Erro ao verificar email');
    }
  }

  Future<void> _continueToNextScreen() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (email.isEmpty) {
      _showSnackBar('Digite um email válido', isError: true);
      return;
    }
    if (!_isValidEmail(email)) {
      _showSnackBar('Email inválido. Verifique o formato.', isError: true);
      return;
    }
    if (password.isEmpty || !_isPasswordValid) {
      _showSnackBar('A senha não atende aos requisitos.', isError: true);
      return;
    }
    if (!_passwordsMatch) {
      _showSnackBar('As senhas não coincidem.', isError: true);
      return;
    }

    setState(() => _isChecking = true);

    try {
      final emailExists = await _checkEmailExists(email);
      setState(() => _isChecking = false);

      if (emailExists) {
        _showSnackBar(
          'Este email já está cadastrado. Tente fazer login.',
          isError: true,
        );
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                OnboardingAge(email: email, password: password),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
    } catch (e) {
      setState(() => _isChecking = false);
      _showSnackBar('Erro ao verificar email. Tente novamente.', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(20),
          elevation: 8,
        ),
      );
    }
  }

  Widget _buildRequirement(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isValid ? Colors.green.shade500 : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isValid ? Icons.check_rounded : Icons.close_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isValid ? Colors.green[700] : Colors.grey[600],
              fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool canProceed =
        _isPasswordValid && _passwordsMatch && !_isChecking;

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
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/LoginScreen'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator — passo 1 de 3
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
                          colors: [
                            Colors.blue.shade400,
                            Colors.blue.shade600,
                          ],
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

            // Conteúdo
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                    child: Column(
                      children: [
                        SizedBox(height: screenHeight * 0.035),

                        // Ícone
                        Container(
                          width: screenWidth * 0.24,
                          height: screenWidth * 0.24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade700,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            size: screenWidth * 0.11,
                            color: Colors.white,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.028),

                        Text(
                          'Criar sua conta',
                          style: TextStyle(
                            fontSize: screenHeight * 0.034,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1F36),
                            letterSpacing: -0.5,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.008),

                        Text(
                          'Preencha seus dados para começar.',
                          style: TextStyle(
                            fontSize: screenHeight * 0.018,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: screenHeight * 0.035),

                        // ─── Campo de Email ───────────────────────────────
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'seuemail@exemplo.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          screenHeight: screenHeight,
                          screenWidth: screenWidth,
                        ),

                        SizedBox(height: screenHeight * 0.018),

                        // ─── Campo de Senha ───────────────────────────────
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Senha',
                          hint: 'Mínimo 6 caracteres',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          isVisible: _isPasswordVisible,
                          onToggleVisibility: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible),
                          screenHeight: screenHeight,
                          screenWidth: screenWidth,
                        ),

                        SizedBox(height: screenHeight * 0.018),

                        // ─── Confirmar Senha ──────────────────────────────
                        _buildTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirmar senha',
                          hint: 'Repita a senha',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          isVisible: _isConfirmPasswordVisible,
                          onToggleVisibility: () => setState(() =>
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible),
                          screenHeight: screenHeight,
                          screenWidth: screenWidth,
                          suffixIcon: _confirmPasswordController.text.isNotEmpty
                              ? Icon(
                                  _passwordsMatch
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: _passwordsMatch
                                      ? Colors.green
                                      : Colors.red,
                                  size: 22,
                                )
                              : null,
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        // ─── Requisitos de senha ─────────────────────────
                        if (_passwordController.text.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.grey[200]!, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Requisitos da senha',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildRequirement('Mínimo 6 caracteres',
                                    _passwordController.text.length >= 6),
                                _buildRequirement(
                                    'Letras e números',
                                    _hasLettersAndNumbers(
                                        _passwordController.text)),
                                _buildRequirement(
                                    'Não use senhas óbvias',
                                    !_isObviousPassword(
                                        _passwordController.text)),
                              ],
                            ),
                          ),

                        SizedBox(height: screenHeight * 0.035),

                        // ─── Botão Continuar ──────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.065,
                          child: ElevatedButton(
                            onPressed:
                                canProceed ? _continueToNextScreen : null,
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
                                gradient: canProceed
                                    ? LinearGradient(
                                        colors: [
                                          Colors.blue.shade400,
                                          Colors.blue.shade700,
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.grey.shade300,
                                          Colors.grey.shade300,
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: canProceed
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                          spreadRadius: -5,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: _isChecking
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Continuar',
                                            style: TextStyle(
                                              fontSize: screenHeight * 0.022,
                                              fontWeight: FontWeight.bold,
                                              color: canProceed
                                                  ? Colors.white
                                                  : Colors.grey[500],
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: canProceed
                                                ? Colors.white
                                                : Colors.grey[500],
                                            size: 22,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.025),

                        // Info de segurança
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.blue.shade100, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Seus dados estão seguros e protegidos',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: screenHeight * 0.015,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.03),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required double screenHeight,
    required double screenWidth,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword && !isVisible,
        enabled: !_isChecking,
        style: TextStyle(
          fontSize: screenHeight * 0.019,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1A1F36),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.grey[400], fontSize: screenHeight * 0.017),
          labelText: label,
          labelStyle:
              TextStyle(color: Colors.grey[600], fontSize: screenHeight * 0.017),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          suffixIcon: isPassword
              ? (suffixIcon != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        suffixIcon,
                        IconButton(
                          icon: Icon(
                            isVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.grey[400],
                            size: 22,
                          ),
                          onPressed: onToggleVisibility,
                        ),
                      ],
                    )
                  : IconButton(
                      icon: Icon(
                        isVisible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.grey[400],
                        size: 22,
                      ),
                      onPressed: onToggleVisibility,
                    ))
              : null,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.022,
          ),
        ),
      ),
    );
  }
}