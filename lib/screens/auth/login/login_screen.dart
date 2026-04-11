import 'package:dartobra_new/screens/auth/login/password_recovery_screen.dart';
import 'package:flutter/material.dart';
import 'login_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool canEnter = false;
  bool emailValid = false;
  bool obscurePassword = true;
  bool _isLoading = false;

  final controller = LoginController();
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    controller.emailController.addListener(_validateFields);
    controller.passwordController.addListener(_validateFields);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ── Validação ──────────────────────────────────────────────────────────────

  void _validateFields() {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final emailFormatValid =
        emailRegex.hasMatch(controller.emailController.text);

    setState(() {
      emailValid = emailFormatValid;
      canEnter = controller.emailController.text.isNotEmpty &&
          controller.passwordController.text.isNotEmpty &&
          emailFormatValid;
    });
  }

  // ── Feedback visual ────────────────────────────────────────────────────────

  void _showErrorSnackBar(String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isWarning
                  ? Icons.warning_amber_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isWarning ? Colors.orange.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 4),
        elevation: 8,
      ),
    );
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    final result = await controller.signIn(
      email: controller.emailController.text.trim(),
      password: controller.passwordController.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final User? user = result['user'] as User?;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Busca UserModel e navega para a tela correta (ban / suspensão / advertência / home)
      await controller.loadUserAndNavigate(context, user.uid);
    } else {
      setState(() => _isLoading = false);
      _showErrorSnackBar(
        result['message'] as String,
        isWarning: result['errorType'] == 'network',
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final showEmailFormatError =
        controller.emailController.text.isNotEmpty && !emailValid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.02),

                    // Logo
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: SizedBox(
                        width: screenWidth * 0.7 * 0.95,
                        height: screenHeight * 0.25,
                        child: Image.asset(
                          'assets/logo_no_bg.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.007),

                    // Título e subtítulo
                    SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Bem-vindo de volta!',
                            style: TextStyle(
                              fontSize: screenHeight * 0.034,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1F36),
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            'Entre com suas credenciais para continuar',
                            style: TextStyle(
                              fontSize: screenHeight * 0.018,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.04),

                    // Formulário
                    SlideTransition(
                      position: _slideAnimation,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Email ────────────────────────────────────
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'Email',
                                style: TextStyle(
                                  fontSize: screenHeight * 0.017,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A1F36),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: showEmailFormatError
                                        ? Colors.red.withOpacity(0.08)
                                        : Colors.blue.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: controller.emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(
                                  fontSize: screenHeight * 0.019,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1A1F36),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'seu@email.com',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: screenHeight * 0.018,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(12),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: showEmailFormatError
                                            ? [
                                                Colors.red.shade400,
                                                Colors.red.shade600
                                              ]
                                            : [
                                                Colors.blue.shade500,
                                                Colors.blue.shade700
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.email_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  suffixIcon: controller
                                          .emailController.text.isNotEmpty
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(right: 12),
                                          child: Icon(
                                            emailValid
                                                ? Icons.check_circle_rounded
                                                : Icons.error_rounded,
                                            color: emailValid
                                                ? Colors.green[500]
                                                : Colors.red[500],
                                            size: 22,
                                          ),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: showEmailFormatError
                                      ? Colors.red[50]
                                      : Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: showEmailFormatError
                                          ? Colors.red.shade200
                                          : Colors.grey.shade200,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: showEmailFormatError
                                          ? Colors.red
                                          : Colors.blue.shade600,
                                      width: 2.5,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.04,
                                    vertical: screenHeight * 0.02,
                                  ),
                                ),
                              ),
                            ),
                            if (showEmailFormatError)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        size: 15, color: Colors.red[600]),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Digite um email válido',
                                      style: TextStyle(
                                        color: Colors.red[600],
                                        fontSize: screenHeight * 0.014,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            SizedBox(height: screenHeight * 0.025),

                            // ── Senha ────────────────────────────────────
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'Senha',
                                style: TextStyle(
                                  fontSize: screenHeight * 0.017,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A1F36),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: controller.passwordController,
                                obscureText: obscurePassword,
                                style: TextStyle(
                                  fontSize: screenHeight * 0.019,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1A1F36),
                                ),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: screenHeight * 0.022,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(12),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade500,
                                          Colors.blue.shade700,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey[600],
                                      size: 22,
                                    ),
                                    onPressed: () => setState(() =>
                                        obscurePassword = !obscurePassword),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.blue.shade600,
                                      width: 2.5,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.04,
                                    vertical: screenHeight * 0.02,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.015),

                            // ── Esqueci minha senha ───────────────────────
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () async {
                                  if (controller.emailController.text.isEmpty) {
                                    _showErrorSnackBar(
                                      'Insira seu email antes de recuperar a senha.',
                                      isWarning: true,
                                    );
                                    return;
                                  }
                                  if (!emailValid) {
                                    _showErrorSnackBar(
                                      'Insira um email válido.',
                                      isWarning: true,
                                    );
                                    return;
                                  }

                                  try {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => const Center(
                                          child: CircularProgressIndicator()),
                                    );

                                    await FirebaseAuth.instance
                                        .sendPasswordResetEmail(
                                      email: controller.emailController.text
                                          .trim(),
                                    );

                                    if (mounted) {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PasswordRecoveryInfoScreen(
                                            email: controller
                                                .emailController.text
                                                .trim(),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) Navigator.pop(context);
                                    _showErrorSnackBar(
                                        'Erro ao enviar email de recuperação.');
                                  }
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                                ),
                                child: Text(
                                  'Esqueci minha senha',
                                  style: TextStyle(
                                    fontSize: screenHeight * 0.016,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.03),

                            // ── Botão Entrar ──────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: screenHeight * 0.065,
                              child: ElevatedButton(
                                onPressed: (canEnter && !_isLoading)
                                    ? _handleLogin
                                    : null,
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
                                    gradient: (canEnter && !_isLoading)
                                        ? LinearGradient(
                                            colors: [
                                              Colors.blue.shade600,
                                              Colors.blue.shade800,
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          )
                                        : LinearGradient(
                                            colors: [
                                              Colors.grey.shade300,
                                              Colors.grey.shade400,
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: (canEnter && !_isLoading)
                                        ? [
                                            BoxShadow(
                                              color: Colors.blue.shade600
                                                  .withOpacity(0.4),
                                              blurRadius: 16,
                                              offset: const Offset(0, 8),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
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
                                                'Entrar',
                                                style: TextStyle(
                                                  fontSize:
                                                      screenHeight * 0.021,
                                                  fontWeight: FontWeight.bold,
                                                  color: canEnter
                                                      ? Colors.white
                                                      : Colors.grey[600],
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                color: canEnter
                                                    ? Colors.white
                                                    : Colors.grey[600],
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.025),

                            // ── Divider ───────────────────────────────────
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: Colors.grey[300], thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    'ou',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: screenHeight * 0.015,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: Colors.grey[300], thickness: 1)),
                              ],
                            ),

                            SizedBox(height: screenHeight * 0.025),

                            // ── Botão Criar Conta ─────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: screenHeight * 0.065,
                              child: OutlinedButton(
                                onPressed: () => controller.nextScreen(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: Colors.blue.shade700, width: 2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  backgroundColor:
                                      Colors.blue.shade50.withOpacity(0.3),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add_outlined,
                                        color: Colors.blue.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Criar nova conta',
                                      style: TextStyle(
                                        fontSize: screenHeight * 0.021,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                        letterSpacing: 0.5,
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

                    SizedBox(height: screenHeight * 0.04),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
