// lib/widgets/vacancy/vacancy_card_with_expiration.dart

import 'package:dartobra_new/services/expiration_service.dart';
import 'package:dartobra_new/services/services_vacancy/vacancy_service.dart';
import 'package:dartobra_new/widgets/expiration_widget.dart';
import 'package:flutter/material.dart';

class VacancyCardWithExpiration extends StatefulWidget {
  final Map<String, dynamic> vacancy;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onStatusToggle;
  final bool isOwn;

  const VacancyCardWithExpiration({
    Key? key,
    required this.vacancy,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onStatusToggle,
    this.isOwn = false,
  }) : super(key: key);

  @override
  State<VacancyCardWithExpiration> createState() =>
      _VacancyCardWithExpirationState();
}

class _VacancyCardWithExpirationState
    extends State<VacancyCardWithExpiration> {
  final VacancyService _vacancyService = VacancyService();
  final ExpirationService _expirationService = ExpirationService();
  bool _isRenewing = false;

  // ── Lê campos ────────────────────────────────────────────
  String get _title      => widget.vacancy['title']?.toString() ?? '';
  String get _profession => widget.vacancy['profession']?.toString() ?? '';
  String get _city       => widget.vacancy['city']?.toString() ?? '';
  String get _state      => widget.vacancy['state']?.toString() ?? '';
  String get _salaryRaw  => widget.vacancy['salary']?.toString() ?? '';
  String get _salaryType => widget.vacancy['salary_type']?.toString() ?? '';
  String get _status     => widget.vacancy['status']?.toString() ?? '';
  String get _expiresAt  => widget.vacancy['expires_at']?.toString() ?? '';
  String get _createdAt  => widget.vacancy['created_at']?.toString() ?? '';
  int    get _candidates => widget.vacancy['stats']?['total_applications'] ?? 0;

  List<String> get _images {
    final midia = widget.vacancy['midia'];
    if (midia is Map) {
      final imgs = midia['images'];
      if (imgs is List) return imgs.map((e) => e.toString()).toList();
    }
    return [];
  }

  String get _location =>
      [_city, _state].where((e) => e.isNotEmpty).join(', ');

  bool get _isExpired => _expirationService.isExpired(widget.vacancy['expires_at']);
  bool get _isNear    => _expirationService.isNearExpiration(widget.vacancy['expires_at']);
  bool get _hasActions =>
      widget.onStatusToggle != null ||
      widget.onEdit != null ||
      widget.onDelete != null;

  // ── Paleta dinâmica ──────────────────────────────────────
  Color get _primary {
    if (widget.isOwn) return const Color(0xFF059669);
    if (_isExpired)   return const Color(0xFF9CA3AF);
    return _professionColor(_profession);
  }

  Color get _soft {
    if (widget.isOwn) return const Color(0xFFECFDF5);
    if (_isExpired)   return const Color(0xFFF9FAFB);
    return _professionSoft(_profession);
  }

  Color get _softMid {
    if (widget.isOwn) return const Color(0xFFA7F3D0);
    if (_isExpired)   return const Color(0xFFE5E7EB);
    return _professionSoftMid(_profession);
  }

  Color get _badgeBg {
    if (widget.isOwn) return const Color(0xFFD1FAE5);
    if (_isExpired)   return const Color(0xFFF3F4F6);
    return _professionBadgeBg(_profession);
  }

  Color get _badgeFg {
    if (widget.isOwn) return const Color(0xFF065F46);
    if (_isExpired)   return const Color(0xFF6B7280);
    return _professionBadgeFg(_profession);
  }

  // ── Cor por profissão ────────────────────────────────────
  static const _profColors = {
    'pedreiro':    [Color(0xFF2563EB), Color(0xFFEFF6FF), Color(0xFFDBEAFE), Color(0xFFDBEAFE), Color(0xFF1E40AF)],
    'encanador':   [Color(0xFF2563EB), Color(0xFFEFF6FF), Color(0xFFDBEAFE), Color(0xFFDBEAFE), Color(0xFF1E40AF)],
    'eletricista': [Color(0xFFD97706), Color(0xFFFFFBEB), Color(0xFFFDE68A), Color(0xFFFEF3C7), Color(0xFF92400E)],
    'pintor':      [Color(0xFF7C3AED), Color(0xFFF5F3FF), Color(0xFFEDE9FE), Color(0xFFEDE9FE), Color(0xFF4C1D95)],
    'carpinteiro': [Color(0xFF92400E), Color(0xFFFFF7ED), Color(0xFFFED7AA), Color(0xFFFEF3C7), Color(0xFF7C2D12)],
    'asfaltador':  [Color(0xFF374151), Color(0xFFF9FAFB), Color(0xFFE5E7EB), Color(0xFFF3F4F6), Color(0xFF111827)],
    'arquiteto':   [Color(0xFF0E7490), Color(0xFFECFEFF), Color(0xFFA5F3FC), Color(0xFFCFFAFE), Color(0xFF164E63)],
    'armador':     [Color(0xFF9D174D), Color(0xFFFDF2F8), Color(0xFFFBCFE8), Color(0xFFFCE7F3), Color(0xFF831843)],
    'soldador':    [Color(0xFFB45309), Color(0xFFFFFBEB), Color(0xFFFCD34D), Color(0xFFFEF3C7), Color(0xFF78350F)],
  };

  Color _professionColor(String p) {
    final key = _normProf(p);
    return _profColors[key]?[0] ?? const Color(0xFF2563EB);
  }
  Color _professionSoft(String p) {
    final key = _normProf(p);
    return _profColors[key]?[1] ?? const Color(0xFFEFF6FF);
  }
  Color _professionSoftMid(String p) {
    final key = _normProf(p);
    return _profColors[key]?[2] ?? const Color(0xFFDBEAFE);
  }
  Color _professionBadgeBg(String p) {
    final key = _normProf(p);
    return _profColors[key]?[3] ?? const Color(0xFFDBEAFE);
  }
  Color _professionBadgeFg(String p) {
    final key = _normProf(p);
    return _profColors[key]?[4] ?? const Color(0xFF1E40AF);
  }

  String _normProf(String p) {
    final lower = p.toLowerCase();
    for (final key in _profColors.keys) {
      if (lower.contains(key)) return key;
    }
    return '';
  }

  // ── Formata salário ──────────────────────────────────────
  String get _salaryFormatted {
    final raw = _salaryRaw.trim();
    if (raw.isEmpty) return 'A combinar';

    // Casos texto
    final lower = raw.toLowerCase();
    if (lower == 'a combinar') return 'A combinar';
    if (lower == 'por empreitada') return 'Por empreitada';

    // Remove tudo que não é dígito ou vírgula/ponto
    final digitsOnly = raw.replaceAll(RegExp(r'[^\d.,]'), '').trim();
    if (digitsOnly.isEmpty) return raw;

    // Tenta parse como número
    final normalized = digitsOnly
        .replaceAll('.', '')   // remove separador de milhar
        .replaceAll(',', '.'); // vírgula decimal → ponto
    final number = double.tryParse(normalized);
    if (number == null) return raw;

    // Formata como moeda BR
    if (number == 0) return 'A combinar';

    // Se for número inteiro, formata sem casas decimais
    if (number % 1 == 0) {
      final intValue = number.toInt().toString();
      // Adiciona separadores de milhar (ponto)
      final formatted = intValue.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
      return 'R\$ $formatted';
    }
    
    // Se tiver centavos, formata com vírgula decimal
    final formatted = number.toStringAsFixed(2);
    final parts = formatted.split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'R\$ $integerPart,${parts[1]}';
  }

  String get _salarySubtitle {
    final type = _salaryType.toLowerCase();
    if (type == 'mensal' || type == 'monthly') return 'Por mês';
    if (type == 'diário' || type == 'diario' || type == 'daily') return 'Por dia trabalhado';
    if (type == 'semanal') return 'Por semana';
    if (type == 'por empreitada') return 'Por empreitada';
    if (type == 'a combinar') return '';
    return _salaryType;
  }

  bool get _salaryIsText =>
      _salaryFormatted == 'A combinar' ||
      _salaryFormatted == 'Por empreitada';

  // ── Renovar ───────────────────────────────────────────────
  Future<void> _renewVacancy() async {
    showDialog(
      context: context,
      builder: (_) => RenewConfirmationDialog(
        title: 'Renovar Vaga',
        message: 'Deseja renovar esta vaga por mais 2 dias?',
        onConfirm: () async {
          setState(() => _isRenewing = true);
          final ok = await _vacancyService.renewVacancy(widget.vacancy['id']);
          if (mounted) {
            setState(() => _isRenewing = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? 'Vaga renovada por mais 2 dias!' : 'Erro ao renovar'),
              backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(12),
            ));
          }
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: _primary.withOpacity(0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Imagens ─────────────────────────────
                if (_images.isNotEmpty) _buildImages(),

                // ── Barra de cor ─────────────────────────
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primary, _primary.withOpacity(0.7)],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Header ────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _soft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              _isExpired
                                  ? Icons.work_off_rounded
                                  : Icons.work_rounded,
                              color: _primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_profession.isNotEmpty)
                                  Text(
                                    _profession.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: _primary,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                const SizedBox(height: 3),
                                Text(
                                  _title.isNotEmpty ? _title : _profession,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _isExpired
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF111827),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (_location.isNotEmpty)
                                  Row(children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 11, color: Color(0xFFD1D5DB)),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        _location,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ]),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (widget.isOwn)
                                _Badge(
                                  label: 'Minha vaga',
                                  bg: const Color(0xFFD1FAE5),
                                  fg: const Color(0xFF065F46),
                                ),
                              if (widget.isOwn) const SizedBox(height: 5),
                              _Badge(
                                label: _isExpired ? 'Expirada' : _status,
                                bg: _badgeBg,
                                fg: _badgeFg,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      const SizedBox(height: 16),

                      // ── Alert expirado ────────────────
                      if (_isExpired) ...[
                        _AlertBanner(
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFFD97706),
                          bg: const Color(0xFFFEF3C7),
                          text:
                              'Esta vaga expirou e pode não estar mais disponível. '
                              'Confirme com o anunciante antes de entrar em contato.',
                          textColor: const Color(0xFF92400E),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Bloco salário ─────────────────
                      if (!_isExpired) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _soft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _softMid,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                _salaryIsText
                                    ? Icons.help_outline_rounded
                                    : Icons.payments_rounded,
                                color: _primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SALÁRIO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF9CA3AF),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _salaryFormatted,
                                    style: TextStyle(
                                      fontSize: _salaryIsText ? 18 : 22,
                                      fontWeight: FontWeight.w900,
                                      color: _primary,
                                      height: 1,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (_salarySubtitle.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      _salarySubtitle,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Candidatos (somente minhas vagas)
                            if (widget.isOwn)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'CANDIDATOS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF9CA3AF),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    '$_candidates',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: _primary,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                          ]),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Banner próximo ao vencimento ──
                      if (_isNear && !_isExpired && widget.isOwn) ...[
                        ExpirationWarningWidget(
                          expiresAt: widget.vacancy['expires_at'],
                          onRenew: !_isRenewing ? _renewVacancy : null,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Chips ─────────────────────────
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _Chip(
                            icon: Icons.calendar_today_rounded,
                            label: _ageLabel(_createdAt),
                          ),
                          if (widget.isOwn &&
                              _expiresAt.isNotEmpty &&
                              !_isExpired)
                            _Chip(
                              icon: Icons.event_rounded,
                              label: 'Expira em ${_daysUntil(_expiresAt)}',
                              highlight: _isNear,
                            ),
                          if (_isExpired)
                            _Chip(
                              icon: Icons.error_outline_rounded,
                              label: 'Expirou em ${_formatDate(_expiresAt)}',
                              danger: true,
                            ),
                          if (!widget.isOwn && !_isExpired)
                            const _Chip(
                              icon: Icons.phone_rounded,
                              label: 'Contato disponível',
                            ),
                          if (_images.isNotEmpty)
                            _Chip(
                              icon: Icons.photo_library_rounded,
                              label:
                                  '${_images.length} ${_images.length == 1 ? "foto" : "fotos"}',
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── CTA / Ações ────────────────────
                      _hasActions
                          ? _ActionRow(
                              isExpired: _isExpired,
                              status: _status,
                              primary: _primary,
                              onStatusToggle: widget.onStatusToggle,
                              onEdit: widget.onEdit,
                              onDelete: widget.onDelete,
                            )
                          : _CtaButton(
                              label: widget.isOwn
                                  ? 'Gerenciar minha vaga'
                                  : _isExpired
                                      ? 'Ver detalhes mesmo assim'
                                      : 'Ver detalhes e candidatar-se',
                              primary: _primary,
                              muted: _isExpired,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Imagens ───────────────────────────────────────────────
  Widget _buildImages() {
    if (_images.length == 1) {
      return Stack(children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: Image.network(
            _images.first,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 180,
              color: const Color(0xFFF3F4F6),
              child: const Icon(Icons.broken_image_rounded,
                  color: Color(0xFFD1D5DB), size: 40),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 10,
          child: _ImgCountBadge(count: 1),
        ),
      ]);
    }

    return Stack(children: [
      SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: _images.length,
          separatorBuilder: (_, __) =>
              const SizedBox(width: 3),
          itemBuilder: (_, i) => SizedBox(
            width: 240,
            child: Image.network(
              _images[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 240,
                color: const Color(0xFFF3F4F6),
                child: const Icon(Icons.broken_image_rounded,
                    color: Color(0xFFD1D5DB), size: 36),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 8,
        right: 10,
        child: _ImgCountBadge(count: _images.length),
      ),
    ]);
  }

  // ── Helpers de data ────────────────────────────────────────
  String _ageLabel(String iso) {
    // usa updatedAt se disponível, senão createdAt
    final updatedAt = widget.vacancy['updatedAt']?.toString() ?? '';
    final dateStr = updatedAt.isNotEmpty ? updatedAt : iso;
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt).inDays;
      if (diff == 0) return 'Renovada hoje';
      if (diff == 1) return 'Renovada ontem';
      if (diff < 7) return 'Há $diff dias';
      return 'Há ${(diff / 7).floor()} sem.';
    } catch (_) {
      return 'Recente';
    }
  }

  String _daysUntil(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = dt.difference(DateTime.now()).inDays;
      if (diff <= 0) return 'hoje';
      if (diff == 1) return 'amanhã';
      return '$diff dias';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ── Sub-widgets reutilizáveis ─────────────────────────────────────────────────

class _ImgCountBadge extends StatelessWidget {
  final int count;
  const _ImgCountBadge({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_rounded,
              size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text('$count ${count == 1 ? "foto" : "fotos"}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: 0.3)),
      );
}

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bg, textColor;
  final String text;
  const _AlertBanner({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.55)),
          ),
        ]),
      );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final bool danger;
  const _Chip({
    required this.icon,
    required this.label,
    this.highlight = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFFEF2F2)
        : highlight
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFF9FAFB);
    final border = danger
        ? const Color(0xFFFECACA)
        : highlight
            ? const Color(0xFFFDE68A)
            : const Color(0xFFE5E7EB);
    final fg = danger
        ? const Color(0xFF991B1B)
        : highlight
            ? const Color(0xFF92400E)
            : const Color(0xFF4B5563);
    final ic = danger
        ? const Color(0xFFDC2626)
        : highlight
            ? const Color(0xFFD97706)
            : const Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: ic),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final Color primary;
  final bool muted;
  const _CtaButton(
      {required this.label, required this.primary, this.muted = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: muted ? const Color(0xFFF3F4F6) : primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: muted ? const Color(0xFF6B7280) : Colors.white)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded,
              size: 16,
              color: muted ? const Color(0xFF6B7280) : Colors.white),
        ]),
      );
}

class _ActionRow extends StatelessWidget {
  final bool isExpired;
  final String status;
  final Color primary;
  final VoidCallback? onStatusToggle, onEdit, onDelete;
  const _ActionRow({
    required this.isExpired,
    required this.status,
    required this.primary,
    this.onStatusToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final btns = <Widget>[];
    void add(IconData icon, String label, Color color, VoidCallback fn) {
      if (btns.isNotEmpty) btns.add(const SizedBox(width: 8));
      btns.add(Expanded(
          child: _ActionBtn(
              icon: icon, label: label, color: color, onTap: fn)));
    }
    if (!isExpired && onStatusToggle != null) {
      final open = status.toLowerCase() == 'aberta';
      add(open ? Icons.pause_rounded : Icons.play_arrow_rounded,
          open ? 'Pausar' : 'Reativar', primary, onStatusToggle!);
    }
    if (onEdit != null && !isExpired)
      add(Icons.edit_rounded, 'Editar', const Color(0xFF6B7280), onEdit!);
    if (onDelete != null)
      add(Icons.delete_rounded, 'Excluir', const Color(0xFFEF4444),
          onDelete!);
    return Row(children: btns);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ]),
        ),
      );
}