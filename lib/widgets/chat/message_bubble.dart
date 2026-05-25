// lib/widgets/message_bubble.dart

import 'package:flutter/material.dart';
import 'package:dartobra_new/models/chat/message_model.dart';
import 'package:dartobra_new/core/utils/date_utils.dart';

class AnimatedMessageBubble extends StatefulWidget {
  final Message message;
  final bool isSentByMe;
  final String? avatarUrl;
  final VoidCallback? onLongPress;

  /// 'contractor' ou 'employee' — quem está logado e vendo o chat
  final String myRole;

  const AnimatedMessageBubble({
    Key? key,
    required this.message,
    required this.isSentByMe,
    required this.myRole,
    this.avatarUrl,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.isSentByMe ? const Offset(0.3, 0) : const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Verifica se o DESTINATÁRIO leu a mensagem.
  ///
  /// Banco: read_by_contractor / read_by_employee
  ///
  /// Se sou contractor → destinatário é employee → verifico readByEmployee
  /// Se sou employee   → destinatário é contractor → verifico readByContractor
  bool get _isReadByRecipient {
    final isRead = widget.myRole == 'contractor'
        ? widget.message.readByEmployee
        : widget.message.readByContractor;

    // Log para debug — remova após confirmar funcionamento
    debugPrint(
      '🔍 bubble | id=${widget.message.id} | myRole=${widget.myRole} | '
      'isSentByMe=${widget.isSentByMe} | '
      'readByContractor=${widget.message.readByContractor} | '
      'readByEmployee=${widget.message.readByEmployee} | '
      'isReadByRecipient=$isRead',
    );

    return isRead;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildMessageContent(context),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: widget.isSentByMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar só nas mensagens recebidas
            if (!widget.isSentByMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.avatarUrl != null
                    ? NetworkImage(widget.avatarUrl!)
                    : null,
                child: widget.avatarUrl == null
                    ? const Icon(Icons.person, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
            ],

            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isSentByMe
                      ? Theme.of(context).primaryColor
                      : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft:
                        Radius.circular(widget.isSentByMe ? 18 : 4),
                    bottomRight:
                        Radius.circular(widget.isSentByMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: widget.isSentByMe
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Hora
                        Text(
                          ChatDateUtils.formatMessageTime(
                              widget.message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isSentByMe
                                ? Colors.white.withOpacity(0.7)
                                : Colors.grey[600],
                          ),
                        ),

                        // Ícone de leitura — APENAS em mensagens que EU enviei
                        if (widget.isSentByMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            // ✅ done_all azul = destinatário leu
                            // ✅ done cinza   = destinatário NÃO leu
                            _isReadByRecipient
                                ? Icons.done_all
                                : Icons.done,
                            size: 14,
                            color: _isReadByRecipient
                                ? Colors.lightBlueAccent
                                : Colors.white.withOpacity(0.5),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}