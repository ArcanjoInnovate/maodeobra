// lib/widgets/online_status_indicator.dart

import 'package:flutter/material.dart';
import '../../models/chat/participant_model.dart';
import '../../core/utils/date_utils.dart';

/// Indicador visual de status online/offline
class OnlineStatusIndicator extends StatelessWidget {
  final ParticipantData participant;
  final bool showText;
  final double size;

  const OnlineStatusIndicator({
    Key? key,
    required this.participant,
    this.showText = true,
    this.size = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(),
        if (showText) ...[
          SizedBox(width: 6),
          Text(
            ChatDateUtils.formatLastSeen(
              participant.lastSeen,
              participant.isOnline,
            ),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDot() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: participant.isOnline ? Colors.green : Colors.grey,
        boxShadow: participant.isOnline
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Versão animada com pulsação sutil e transição suave entre estados
class AnimatedOnlineStatusIndicator extends StatefulWidget {
  final ParticipantData participant;
  final bool showText;
  final double size;

  const AnimatedOnlineStatusIndicator({
    Key? key,
    required this.participant,
    this.showText = true,
    this.size = 10,
  }) : super(key: key);

  @override
  State<AnimatedOnlineStatusIndicator> createState() =>
      _AnimatedOnlineStatusIndicatorState();
}

class _AnimatedOnlineStatusIndicatorState
    extends State<AnimatedOnlineStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const _onlineColor = Color(0xFF25D366);
  static const _offlineColor = Color(0xFFB0B0B0);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.participant.isOnline) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedOnlineStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.participant.isOnline != oldWidget.participant.isOnline) {
      if (widget.participant.isOnline) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.participant.isOnline;
    final statusText = ChatDateUtils.formatLastSeen(
      widget.participant.lastSeen,
      isOnline,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size + 6,
          height: widget.size + 6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isOnline)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: widget.size + (4 * _pulseAnimation.value),
                      height: widget.size + (4 * _pulseAnimation.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _onlineColor.withOpacity(
                          0.25 * (1.0 - _pulseAnimation.value),
                        ),
                      ),
                    );
                  },
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? _onlineColor : _offlineColor,
                  boxShadow: isOnline
                      ? [
                          BoxShadow(
                            color: _onlineColor.withOpacity(0.35),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
        if (widget.showText) ...[
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              statusText,
              key: ValueKey(isOnline ? 'online' : statusText),
              style: TextStyle(
                color: isOnline ? _onlineColor : Colors.grey[500],
                fontSize: 12,
                fontWeight: isOnline ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Badge de status para avatar
class OnlineStatusBadge extends StatelessWidget {
  final bool isOnline;
  final double size;
  final Widget child;

  const OnlineStatusBadge({
    Key? key,
    required this.isOnline,
    required this.child,
    this.size = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          right: 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline
                  ? const Color(0xFF25D366)
                  : const Color(0xFFB0B0B0),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Typing indicator (3 pontinhos animados)
class TypingIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const TypingIndicator({
    Key? key,
    this.color = Colors.grey,
    this.size = 8,
  }) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = index * 0.2;
              final value = (_controller.value - delay) % 1.0;
              final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;

              return Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}