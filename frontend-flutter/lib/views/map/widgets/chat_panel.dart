import 'package:flutter/material.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/network/socket_client.dart';

class ChatPanel extends StatefulWidget {
  final String driverId;
  final String driverName;
  final List<Map<String, dynamic>> messages;
  final void Function(String message) onSend;
  final String? peerName;

  const ChatPanel({
    super.key,
    required this.driverId,
    required this.driverName,
    required this.messages,
    required this.onSend,
    this.peerName,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  static const List<String> _quickEmojis = [
    '🚨', '📷', '👍', '🙏', '🤝', '😂', '🤣', '❤️',
    '🔥', '💯', '👀', '😎', '🎉', '🫶', '✅', '⭐',
    '😡', '🐂', '⛽', '🛑',
  ];

  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  late final List<Map<String, dynamic>> _messages;
  late final SocketClient _socket;
  late final void Function(dynamic) _onMessage;

  @override
  void initState() {
    super.initState();
    _messages = [...widget.messages];
    _socket = SocketClient();
    _onMessage = (data) {
      if (!mounted) return;
      setState(() => _messages.add(Map<String, dynamic>.from(data)));
      _scrollToBottom();
    };
    _socket.onReceiveChatMessage(_onMessage);
  }

  @override
  void dispose() {
    _socket.socket.off('receive_chat_message', _onMessage);
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _send() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _msgController.clear();
  }

  void _sendEmoji(String emoji) {
    widget.onSend(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.peerName == null
        ? 'RÁDIO PX • CHAT DA VIA'
        : 'RÁDIO PX • ${widget.peerName}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 15,
        right: 15,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1C0303),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _messages.isEmpty
                ? const Center(
                    child: Text('Nenhuma mensagem por perto...',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final name = (msg['driverName'] ?? '?').toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: kEmergencyRed,
                              child: Text(
                                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    msg['message'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickEmojis.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final emoji = _quickEmojis[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _sendEmoji(emoji),
                  child: Container(
                    width: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C0303),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA80000)),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: widget.peerName == null
                        ? 'Digite a mensagem para a rodovia...'
                        : 'Mensagem para ${widget.peerName}...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kEmergencyRed)),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.red),
                onPressed: _send,
              )
            ],
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }
}
