// lib/widgets/chat_input.dart

import 'package:flutter/material.dart';
import 'dart:async';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(bool)? onTypingChanged;
  final bool isEnabled;
  final String hintText;

  const ChatInput({
    Key? key,
    required this.onSendMessage,
    this.onTypingChanged,
    this.isEnabled = true,
    this.hintText = 'Digite uma mensagem...',
  }) : super(key: key);

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;
  Timer? _typingTimer;
  late AnimationController _buttonAnimController;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    
    _buttonAnimController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    
    _buttonScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonAnimController,
        curve: Curves.easeOut,
      ),
    );
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    
    if (hasText != _isComposing) {
      setState(() {
        _isComposing = hasText;
      });
      
      if (hasText) {
        _buttonAnimController.forward();
      } else {
        _buttonAnimController.reverse();
      }
    }

    // Typing indicator
    if (widget.onTypingChanged != null) {
      _typingTimer?.cancel();
      
      if (hasText) {
        widget.onTypingChanged!(true);
        
        // Para de indicar digitação após 3s sem mudança
        _typingTimer = Timer(Duration(seconds: 3), () {
          widget.onTypingChanged!(false);
        });
      } else {
        widget.onTypingChanged!(false);
      }
    }
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    
    if (text.isEmpty || !widget.isEnabled) return;

    widget.onSendMessage(text);
    _controller.clear();
    
    if (widget.onTypingChanged != null) {
      widget.onTypingChanged!(false);
    }
    
    setState(() {
      _isComposing = false;
    });
    
    _buttonAnimController.reverse();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _buttonAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Botão de anexo (opcional)
              IconButton(
                icon: Icon(Icons.add_circle_outline),
                color: Theme.of(context).primaryColor,
                onPressed: widget.isEnabled ? _handleAttachment : null,
              ),

              // Campo de texto
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.isEnabled,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _handleSubmit(),
                  ),
                ),
              ),

              SizedBox(width: 8),

              // Botão de enviar (animado)
              ScaleTransition(
                scale: _buttonScale,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isComposing
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send),
                    color: Colors.white,
                    onPressed: _isComposing && widget.isEnabled
                        ? _handleSubmit
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAttachment() {
    // Implementar lógica de anexo (imagem, arquivo, etc)
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.purple),
              title: Text('Galeria'),
              onTap: () {
                Navigator.pop(context);
                // Implementar seleção de imagem
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.blue),
              title: Text('Câmera'),
              onTap: () {
                Navigator.pop(context);
                // Implementar câmera
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_file, color: Colors.orange),
              title: Text('Arquivo'),
              onTap: () {
                Navigator.pop(context);
                // Implementar seleção de arquivo
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Versão simplificada sem anexos
class SimpleChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isEnabled;

  const SimpleChatInput({
    Key? key,
    required this.onSendMessage,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  State<SimpleChatInput> createState() => _SimpleChatInputState();
}

class _SimpleChatInputState extends State<SimpleChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    widget.onSendMessage(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.isEnabled,
              decoration: InputDecoration(
                hintText: 'Digite uma mensagem...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: _hasText && widget.isEnabled ? _handleSubmit : null,
            child: Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
