import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartobra_new/core/providers/block_provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BlockedUsersScreen extends StatefulWidget {
  final String myUserId;

  const BlockedUsersScreen({super.key, required this.myUserId});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _db = FirebaseDatabase.instance.ref();

  // IDs que o usuário bloqueou ativamente (não quem bloqueou ele)
  // Só esses aparecem na lista — não faz sentido mostrar quem te bloqueou
  List<String> _blockedByMeIds = [];
  Map<String, _UserInfo> _usersInfo = {};

  bool _loading = true;
  // Controla loading individual por botão
  final Set<String> _unblocking = {};

  static const _indigo = Color(0xFF2563EB);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);
  static const _bg = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  // Busca os IDs bloqueados ativamente pelo usuário via onValue (sem cache iOS)
  Future<void> _loadBlockedUsers() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final ids = await _fetchViaListener('Users/${widget.myUserId}/blocked_users');

      final List<String> blockedIds = [];
      if (ids is Map) {
        for (final entry in ids.entries) {
          final v = entry.value;
          final isTruthy = v == true || v == 1 || v == 'true' || v == '1';
          if (isTruthy) blockedIds.add(entry.key.toString());
        }
      }

      // Busca nome + avatar de cada usuário em paralelo
      final infoFutures = blockedIds.map((id) => _fetchUserInfo(id));
      final infoList = await Future.wait(infoFutures);

      if (!mounted) return;
      setState(() {
        _blockedByMeIds = blockedIds;
        _usersInfo = {
          for (var i = 0; i < blockedIds.length; i++)
            blockedIds[i]: infoList[i],
        };
        _loading = false;
      });
    } catch (e) {
      print('❌ _loadBlockedUsers: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // onValue com Completer — evita cache iOS
  Future<dynamic> _fetchViaListener(String path) async {
    final completer = Completer<dynamic>();
    late StreamSubscription<DatabaseEvent> sub;
    sub = _db.child(path).onValue.listen(
      (event) {
        if (!completer.isCompleted) {
          completer.complete(event.snapshot.value);
          sub.cancel();
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.complete(null);
          sub.cancel();
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () { sub.cancel(); return null; },
    );
  }

  Future<_UserInfo> _fetchUserInfo(String userId) async {
    try {
      final data = await _fetchViaListener('Users/$userId');
      if (data is Map) {
        return _UserInfo(
          name: data['Name']?.toString() ?? 'Usuário',
          avatar: data['avatar']?.toString() ?? '',
        );
      }
    } catch (_) {}
    return _UserInfo(name: 'Usuário', avatar: '');
  }

  Future<void> _unblock(String targetId) async {
    if (_unblocking.contains(targetId)) return;

    setState(() => _unblocking.add(targetId));

    try {
      final blockProvider = context.read<BlockProvider>();
      final success = await blockProvider.unblockUser(targetId);

      if (!mounted) return;

      if (success) {
        setState(() {
          _blockedByMeIds.remove(targetId);
          _usersInfo.remove(targetId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Usuário desbloqueado com sucesso'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Falha ao desbloquear. Tente novamente.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('❌ _unblock: $e');
    } finally {
      if (mounted) setState(() => _unblocking.remove(targetId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Usuários Bloqueados',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _blockedByMeIds.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block_outlined, size: 52, color: _indigo),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nenhum usuário bloqueado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Usuários que você bloquear aparecerão aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: _blockedByMeIds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final id = _blockedByMeIds[index];
        final info = _usersInfo[id] ?? _UserInfo(name: 'Usuário', avatar: '');
        final isUnblocking = _unblocking.contains(id);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: _border, width: 1.5),
                  ),
                  child: ClipOval(
                    child: info.avatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: info.avatar,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Icon(
                              Icons.person_rounded,
                              color: _indigo,
                              size: 26,
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              color: _indigo,
                              size: 26,
                            ),
                            memCacheWidth: 100,
                            memCacheHeight: 100,
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: _indigo,
                            size: 26,
                          ),
                  ),
                ),

                const SizedBox(width: 14),

                // Nome
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Bloqueado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Botão desbloquear
                SizedBox(
                  height: 36,
                  child: isUnblocking
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _indigo,
                              ),
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () => _showUnblockConfirmation(id, info.name),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _indigo,
                            side: const BorderSide(color: _indigo, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text(
                            'Desbloquear',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUnblockConfirmation(String userId, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Desbloquear usuário?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          '$userName poderá ver seu perfil e entrar em contato novamente.',
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unblock(userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              'Desbloquear',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfo {
  final String name;
  final String avatar;
  const _UserInfo({required this.name, required this.avatar});
}