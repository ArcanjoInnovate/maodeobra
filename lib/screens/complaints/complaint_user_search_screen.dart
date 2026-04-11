import 'package:dartobra_new/screens/complaints/complaint_user_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SearchUserToComplaint extends StatefulWidget {
  final String UserEmailContact;
  final String Company;

  const SearchUserToComplaint({
    Key? key,
    required this.UserEmailContact,
    required this.Company,
  }) : super(key: key);

  @override
  State<SearchUserToComplaint> createState() => _SearchUserToComplaintState();
}

class _SearchUserToComplaintState extends State<SearchUserToComplaint>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _searchController = TextEditingController();
  final _formKey          = GlobalKey<FormState>();
  late final AnimationController _resultCtrl;
  late final Animation<double>   _resultFade;

  // ── State ─────────────────────────────────────────────────────────────────
  bool                   _isLoading    = false;
  Map<String, dynamic>?  _foundUser;
  String?                _foundUserId;
  String                 _searchType   = 'email';
  bool                   _isSelfReport = false;

  // ── Theme ─────────────────────────────────────────────────────────────────
  static const _accent = Color(0xFFDC2626);

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _resultCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _resultFade = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  // ── Logic ─────────────────────────────────────────────────────────────────
  bool _checkIfSelfReport(Map<String, dynamic> userData) {
    final foundEmailContact =
        (userData['email_contact'] ?? '').toString().toLowerCase();
    final foundEmail  = (userData['email'] ?? '').toString().toLowerCase();
    final currentEmail = widget.UserEmailContact.toLowerCase();

    if (foundEmailContact == currentEmail || foundEmail == currentEmail) {
      return true;
    }

    final contractorCompany =
        (userData['data_contractor']?['company'] ?? '').toString().toLowerCase();
    final workerCompany =
        (userData['data_worker']?['company'] ?? '').toString().toLowerCase();
    final currentCompany = widget.Company.toLowerCase();

    return (contractorCompany.isNotEmpty && contractorCompany == currentCompany) ||
        (workerCompany.isNotEmpty && workerCompany == currentCompany);
  }

  Future<void> _searchUser() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    _resultCtrl.reverse();
    setState(() {
      _isLoading    = true;
      _foundUser    = null;
      _foundUserId  = null;
      _isSelfReport = false;
    });

    try {
      final snapshot = await FirebaseDatabase.instance.ref('Users').get();

      if (snapshot.exists) {
        final usersData =
            Map<String, dynamic>.from(snapshot.value as Map);
        final searchValue = _searchController.text.trim().toLowerCase();

        for (final entry in usersData.entries) {
          final userId   = entry.key;
          final userData = Map<String, dynamic>.from(entry.value as Map);

          bool found = false;
          if (_searchType == 'email') {
            final emailContact =
                (userData['email_contact'] ?? '').toString().toLowerCase();
            final email =
                (userData['email'] ?? '').toString().toLowerCase();
            found = emailContact == searchValue || email == searchValue;
          } else {
            final contractorCompany =
                (userData['data_contractor']?['company'] ?? '')
                    .toString()
                    .toLowerCase();
            final workerCompany =
                (userData['data_worker']?['company'] ?? '')
                    .toString()
                    .toLowerCase();
            found = contractorCompany.contains(searchValue) ||
                workerCompany.contains(searchValue);
          }

          if (found) {
            setState(() {
              _foundUser    = userData;
              _foundUserId  = userId;
              _isSelfReport = _checkIfSelfReport(userData);
            });
            _resultCtrl.forward();
            break;
          }
        }

        if (_foundUser == null) _toast('Usuário não encontrado');
      } else {
        _toast('Nenhum usuário encontrado no banco de dados');
      }
    } catch (e) {
      _toast('Erro ao buscar usuário: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearResult() {
    _resultCtrl.reverse().then((_) {
      setState(() {
        _foundUser    = null;
        _foundUserId  = null;
        _isSelfReport = false;
        _searchController.clear();
      });
    });
  }

  void _confirmAndProceed() {
    if (_foundUser == null || _foundUserId == null || _isSelfReport) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintUser(
          reportedId:    _foundUserId!,
          reportedName:  _foundUser!['Name'] ?? 'Não definido',
          reportedEmail: _foundUser!['email_contact'] ?? 'Não definido',
        ),
      ),
    );
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
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, MediaQuery.of(context).padding.bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchTypeToggle(),
              const SizedBox(height: 16),
              _buildSearchField(),
              const SizedBox(height: 12),
              _buildSearchButton(),
              const SizedBox(height: 24),
              if (_foundUser != null)
                FadeTransition(
                  opacity: _resultFade,
                  child: _isSelfReport
                      ? _buildSelfReportCard()
                      : _buildFoundUserCard(),
                ),
            ],
          ),
        ),
      ),
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
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: Color(0xFF1C1C1E)),
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

  // ── Search type toggle ─────────────────────────────────────────────────────
  Widget _buildSearchTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buscar por',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTypeChip('Email',   'email',   Icons.email_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _buildTypeChip('Empresa', 'company', Icons.business_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String type, IconData icon) {
    final selected = _searchType == type;
    return GestureDetector(
      onTap: () {
        if (_searchType == type) return;
        setState(() {
          _searchType = type;
          _searchController.clear();
          _foundUser    = null;
          _foundUserId  = null;
          _isSelfReport = false;
        });
        _resultCtrl.reset();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _accent : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _accent : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: _accent.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16,
                color: selected ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search field ───────────────────────────────────────────────────────────
  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: TextFormField(
        controller: _searchController,
        keyboardType: _searchType == 'email'
            ? TextInputType.emailAddress
            : TextInputType.text,
        style: const TextStyle(
            fontSize: 14, color: Color(0xFF1C1C1E), height: 1.4),
        decoration: InputDecoration(
          hintText: _searchType == 'email'
              ? 'Digite o e-mail do usuário'
              : 'Digite o nome da empresa',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(
            _searchType == 'email' ? Icons.email_outlined : Icons.business_outlined,
            size: 20,
            color: Colors.grey.shade400,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: _accent.withOpacity(0.4), width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return _searchType == 'email'
                ? 'Digite um e-mail para buscar'
                : 'Digite uma empresa para buscar';
          }
          if (_searchType == 'email' && !value.contains('@')) {
            return 'Digite um e-mail válido';
          }
          return null;
        },
      ),
    );
  }

  // ── Search button ──────────────────────────────────────────────────────────
  Widget _buildSearchButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _searchUser,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: _accent.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Buscar Usuário',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Found user card ────────────────────────────────────────────────────────
  Widget _buildFoundUserCard() {
    final name    = _foundUser!['Name'] ?? 'Não definido';
    final email   = _foundUser!['email_contact'] ?? 'Não definido';
    final avatar  = _foundUser!['avatar'] ??
        'https://res.cloudinary.com/dsmgwupky/image/upload/v1731970845/image_3_uiwlog.png';
    final city    = _foundUser!['city'] ?? 'Não definido';
    final state   = _foundUser!['state'] ?? '';
    final mode    = _foundUser!['activeMode'];
    final company = mode == 'contractor'
        ? (_foundUser!['data_contractor']?['company'] ?? 'Não definido')
        : (_foundUser!['data_worker']?['company'] ?? 'Não definido');
    final profession = mode == 'contractor'
        ? (_foundUser!['data_contractor']?['profession'] ?? 'Não definido')
        : (_foundUser!['data_worker']?['profession'] ?? 'Não definido');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // ── Header do card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 14, color: Color(0xFF16A34A)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Usuário encontrado',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),

          // ── Perfil ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(avatar),
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(email,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                          Icons.location_city_outlined, 'Cidade',
                          '$city${state.isNotEmpty ? ', $state' : ''}'),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1),
                      ),
                      _buildInfoRow(
                          Icons.business_outlined, 'Empresa', company),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1),
                      ),
                      _buildInfoRow(
                          Icons.work_outline_rounded, 'Profissão', profession),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Confirmação ──
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.help_outline_rounded,
                          size: 18, color: Color(0xFFD97706)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Este é o usuário que deseja denunciar?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Botões ──
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _clearResult,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Não',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _confirmAndProceed,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: _accent.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sim, continuar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded,
                                    size: 16, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Self-report card ───────────────────────────────────────────────────────
  Widget _buildSelfReportCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.block_rounded,
                size: 36, color: Color(0xFFEA580C)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Não permitido',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Você não pode denunciar a si mesmo.\nO usuário encontrado possui o mesmo e-mail ou empresa que você.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _clearResult,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Fazer nova busca',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Text(
                '$label  ',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}