// lib/screens/chat_room_screen.dart - VERSÃO OTIMIZADA (ZERO ESPAÇO DESNECESSÁRIO)

import 'package:dartobra_new/controllers/chat_controller.dart';
import 'package:dartobra_new/services/badge/badge_service.dart';
import 'package:dartobra_new/screens/complaints/complaint_chat_screen.dart';
import 'package:dartobra_new/services/chat/chat_service.dart';
import 'package:dartobra_new/widgets/common/online_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dartobra_new/widgets/chat/message_bubble.dart';
import 'package:dartobra_new/core/utils/date_utils.dart';
import 'package:dartobra_new/models/chat/message_model.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String contractorId;
  final String employeeId;
  final String userRole;
  final String userId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatRoomScreen({
    Key? key,
    required this.chatId,
    required this.contractorId,
    required this.employeeId,
    required this.userId,
    required this.userRole,
    required this.otherUserName,
    this.otherUserAvatar,
  }) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _inputKey = GlobalKey();

  bool _showScrollToBottom = false;
  bool _isLoadingMore = false;
  int _previousMessageCount = 0;
  bool _initialScrollDone = false;
  bool _isTyping = false;
  bool _isScreenActive = true;
  double _inputHeight = 56.0;

  String get _recipientRole =>
      widget.userRole == 'contractor' ? 'employee' : 'contractor';

  // ══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
      _setupScrollListener();
      _measureInputHeight();
    });

    _textController.addListener(_onTextChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    _isScreenActive = state == AppLifecycleState.resumed;

    if (state == AppLifecycleState.resumed && mounted) {
      _markAsRead();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    if (keyboardHeight > 0) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _scrollController.hasClients) {
          _scrollToBottom();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    try {
      context.read<ChatControllerFinal>().leaveChat();
    } catch (e) {
      debugPrint('❌ Erro ao sair do chat: $e');
    }
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INPUT HEIGHT TRACKING
  // ══════════════════════════════════════════════════════════════════════════

  void _measureInputHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final RenderBox? renderBox =
          _inputKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox != null) {
        final newHeight = renderBox.size.height;

        if ((newHeight - _inputHeight).abs() > 1.0) {
          setState(() {
            _inputHeight = newHeight;
          });
        }
      }
    });
  }

  void _onTextChanged() {
    _measureInputHeight();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SCROLL HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    final maxExtent = _scrollController.position.maxScrollExtent;

    if (animated) {
      _scrollController.animateTo(
        maxExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(maxExtent);
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    return (_scrollController.position.maxScrollExtent -
            _scrollController.position.pixels) <=
        200;
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!mounted) return;

      final isAtBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100;

      if (_showScrollToBottom != !isAtBottom) {
        setState(() => _showScrollToBottom = !isAtBottom);
      }

      if (_scrollController.position.pixels <= 100 && !_isLoadingMore) {
        _isLoadingMore = true;
        Future.microtask(() {
          if (mounted) {
            context
                .read<ChatControllerFinal>()
                .loadMoreMessages()
                .then((_) => _isLoadingMore = false);
          }
        });
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CHAT INIT / READ
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _initializeChat() async {
    if (!mounted) return;

    final controller = context.read<ChatControllerFinal>();
    await controller.initializeChat(
      chatId: widget.chatId,
      contractorId: widget.contractorId,
      employeeId: widget.employeeId,
      userRole: widget.userRole,
    );

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollToBottom(animated: false);
      _initialScrollDone = true;
    }
  }

  Future<void> _markAsRead() async {
    if (!mounted || !_isScreenActive) return;

    try {
      final controller = context.read<ChatControllerFinal>();
      await controller.markAsRead();
    } catch (e) {
      debugPrint('❌ Erro ao marcar como lido: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Consumer<ChatControllerFinal>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.error != null) {
            return _buildErrorWidget(controller.error!);
          }

          final currentCount = controller.messages.length;
          if (_initialScrollDone && currentCount > _previousMessageCount) {
            _previousMessageCount = currentCount;

            if (_isNearBottom) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });
            }

            if (_isScreenActive) {
              Future.delayed(const Duration(milliseconds: 500), () {
                _markAsRead();
              });
            }
          } else {
            _previousMessageCount = currentCount;
          }

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: _buildMessagesList(controller),
                  ),
                  _buildChatInput(controller),
                ],
              ),
              if (_showScrollToBottom) _buildScrollToBottomButton(),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      titleSpacing: 0,
      title: Consumer<ChatControllerFinal>(
        builder: (context, controller, child) {
          final status = controller.otherParticipantStatus;
          return Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.otherUserAvatar != null
                    ? NetworkImage(widget.otherUserAvatar!)
                    : null,
                child: widget.otherUserAvatar == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUserName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (status != null)
                      AnimatedOnlineStatusIndicator(
                        participant: status,
                        showText: true,
                        size: 8,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'denunciar',
              child: Row(children: [
                Icon(Icons.warning, size: 20),
                SizedBox(width: 8),
                Text('Denunciar'),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  /// ✅ Padding fixo e mínimo — o Column já posiciona o TextField corretamente
  Widget _buildMessagesList(ChatControllerFinal controller) {
    if (controller.messages.isEmpty) return _buildEmptyState();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(
        bottom: 8, // ✅ Mínimo absoluto — sem espaço desnecessário
        left: 8,
        right: 8,
        top: 8,
      ),
      itemCount:
          controller.messages.length + (controller.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (controller.isLoadingMore && index == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final messageIndex = controller.isLoadingMore ? index - 1 : index;
        final message = controller.messages[messageIndex];
        final isSentByMe = controller.isSentByMe(message);

        Widget? dateSeparator;
        if (messageIndex == 0 ||
            _shouldShowDateSeparator(
              controller.messages[messageIndex - 1].timestamp,
              message.timestamp,
            )) {
          dateSeparator = _buildDateSeparator(message.timestamp);
        }

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            AnimatedMessageBubble(
              message: message,
              isSentByMe: isSentByMe,
              myRole: widget.userRole,
              avatarUrl: isSentByMe ? null : widget.otherUserAvatar,
              onLongPress: () => _showMessageOptions(message, isSentByMe),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatInput(ChatControllerFinal controller) {
    return Container(
      key: _inputKey,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: null,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Digite uma mensagem...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    onChanged: (text) {
                      setState(() => _isTyping = text.isNotEmpty);
                    },
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) _scrollToBottom();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: controller.isSending ||
                        _textController.text.trim().isEmpty
                    ? null
                    : () async {
                        final text = _textController.text.trim();
                        if (text.isNotEmpty) {
                          await controller.sendMessage(text);
                          _textController.clear();
                          setState(() => _isTyping = false);

                          _measureInputHeight();

                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted && _scrollController.hasClients) {
                              _scrollToBottom();
                            }
                          });

                          Future.delayed(const Duration(milliseconds: 300), () {
                            _markAsRead();
                          });
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isTyping && !controller.isSending
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.send,
                    color: _isTyping && !controller.isSending
                        ? Colors.white
                        : Colors.grey[500],
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowDateSeparator(int prevTimestamp, int currentTimestamp) {
    final prev = DateTime.fromMillisecondsSinceEpoch(prevTimestamp);
    final curr = DateTime.fromMillisecondsSinceEpoch(currentTimestamp);
    return prev.day != curr.day ||
        prev.month != curr.month ||
        prev.year != curr.year;
  }

  Widget _buildDateSeparator(int timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            ChatDateUtils.getDateSeparator(timestamp),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Nenhuma mensagem ainda',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Envie a primeira mensagem!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    // ✅ Offset dinâmico baseado na altura real do input
    final double bottomPosition = _inputHeight + 16;

    return Positioned(
      right: 16,
      bottom: bottomPosition,
      child: FloatingActionButton.small(
        onPressed: _scrollToBottom,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.arrow_downward, color: Colors.white),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeChat,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  void _showMessageOptions(Message message, bool isSentByMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mensagem copiada'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            if (isSentByMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Deletar',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(message.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar mensagem'),
        content: const Text('Tem certeza que deseja deletar esta mensagem?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Deletar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'clear':
        break;
      case 'denunciar':
        final reportedId = widget.userRole == 'employee'
            ? widget.contractorId
            : widget.employeeId;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComplaintChat(
              chatId: widget.chatId,
              reportId: widget.userId,
              reportedId: reportedId,
            ),
          ),
        );
        break;
    }
  }
}