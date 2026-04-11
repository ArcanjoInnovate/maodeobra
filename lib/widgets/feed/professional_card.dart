import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/screens/search/my_professional_profile_screen.dart';
import 'package:dartobra_new/screens/search/professional_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';


class ProfessionalCard extends StatelessWidget {
  final ProfessionalModel professional;
  final Function(int)? onNavigateToTab;

  const ProfessionalCard({
    Key? key,
    required this.professional,
    this.onNavigateToTab,
  }) : super(key: key);

  // ── Paleta ──────────────────────────────────────────────────
  static const _indigo     = Colors.blue;
  static const _indigoSoft = Color(0xFFEEF2FF);
  static const _green      = Color(0xFF10B981);
  static const _greenSoft  = Color(0xFFECFDF5);
  static const _greenBorder = Color(0xFF6EE7B7);
  static const _ink        = Color(0xFF0F172A);
  static const _muted      = Color(0xFF64748B);
  static const _border     = Color(0xFFE2E8F0);

  bool get _isOwn {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && professional.localId == uid;
  }

  Color get _primary => _isOwn ? _green  : _indigo;
  Color get _soft    => _isOwn ? _greenSoft : _indigoSoft;

  @override
  Widget build(BuildContext context) {
    final p = professional;
    final String userId = FirebaseAuth.instance.currentUser!.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _indigo.withOpacity(_isOwn ? 0.40 : 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _isOwn
              ? _goMyProfile(context)
              : _goProfile(context, userId),
          borderRadius: BorderRadius.circular(16),
          splashColor: _primary.withOpacity(0.06),
          child: Column(
            children: [
              // ── Barra de accent no topo ──────────────────────
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header com Avatar e Info ─────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar melhorado
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: _soft,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _primary.withOpacity(0.35),
                                  width: _isOwn ? 2.5 : 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: p.avatar.isEmpty
                                    ? Icon(Icons.person_rounded,
                                        size: 28, color: _primary)
                                    : CachedNetworkImage(
                                        imageUrl: p.avatar,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            Icon(Icons.person_rounded,
                                                size: 28, color: _primary),
                                        errorWidget: (_, __, ___) =>
                                            Icon(Icons.person_rounded,
                                                size: 28, color: _primary),
                                        memCacheWidth: 120,
                                        memCacheHeight: 120,
                                      ),
                              ),
                            ),
                            // Check verde para perfil próprio
                            if (_isOwn)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: _primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2.5),
                                  ),
                                  child: const Icon(Icons.check,
                                      size: 9, color: Colors.white),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(width: 12),

                        // ── Info ──────────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nome
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 4),

                              // Chip de profissão
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _soft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.profession,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Localização
                              Row(children: [
                                Icon(Icons.location_on_rounded,
                                    size: 12,
                                    color: _primary.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${p.city}, ${p.state}',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: _muted,
                                        fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // ── Badge Meu/Novo ────────────────────────
                        _isOwn ? _ownBadge() : _newBadge(),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Chips de informação ───────────────────────
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (p.company.isNotEmpty)
                          _infoChip(p.company, Icons.apartment_rounded),
                        if (p.legalType.isNotEmpty)
                          _infoChip(p.legalType, Icons.badge_rounded),
                      ],
                    ),

                    // ── Skills ────────────────────────────────────
                    if (p.skills.isNotEmpty &&
                        !p.skills.contains('Nenhuma habilidade definida')) ...[
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: p.skills.take(4).map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stars_rounded,
                                    size: 10,
                                    color: _primary.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  s,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: _muted,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // ── Resumo ────────────────────────────────────
                    if (p.summary.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        p.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, height: 1.45, color: _muted),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // ── Botão CTA ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(11),
                        border:
                            Border.all(color: _primary.withOpacity(0.22)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isOwn ? 'Ver meu perfil' : 'Ver perfil completo',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _primary),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _isOwn
                                ? Icons.visibility_rounded
                                : Icons.arrow_forward_rounded,
                            size: 15,
                            color: _primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navegação ──────────────────────────────────────────────

  void _goProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfessionalProfilePage(
          professional: professional,
          vacancyId: professional.id,
          reportedId: professional.localId,
          reportId: userId,
        ),
      ),
    );
  }

  void _goMyProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyProfessionalProfilePage(
          professional: professional,
          onEditProfile: () {
            if (onNavigateToTab != null) {
              Navigator.pop(context);
              onNavigateToTab!(3);
            } else {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Acesse a aba "Vagas" para editar seu perfil'),
                  backgroundColor: Color(0xFFF59E0B),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // ── Widgets auxiliares ─────────────────────────────────────

  Widget _ownBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _greenSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _greenBorder.withOpacity(0.6)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded, size: 10, color: _green),
          SizedBox(width: 4),
          Text('MEU',
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: _green,
                  letterSpacing: 0.6)),
        ]),
      );

  Widget _newBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _indigoSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('NOVO',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: _indigo,
                letterSpacing: 0.6)),
      );

  Widget _infoChip(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: _primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    color: _primary,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}