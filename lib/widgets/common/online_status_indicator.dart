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

/// Versão animada com pulsação para status online
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
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.participant.isOnline) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedOnlineStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.participant.isOnline != oldWidget.participant.isOnline) {
      if (widget.participant.isOnline) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.participant.isOnline ? Colors.green : Colors.grey,
              boxShadow: widget.participant.isOnline
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        if (widget.showText) ...[
          SizedBox(width: 6),
          Text(
            ChatDateUtils.formatLastSeen(
              widget.participant.lastSeen,
              widget.participant.isOnline,
            ),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: widget.participant.isOnline
                  ? FontWeight.w600
                  : FontWeight.normal,
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
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.green : Colors.grey,
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