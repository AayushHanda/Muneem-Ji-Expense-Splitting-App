import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../utils/theme.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.brand.withOpacity(0.12),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.brand, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Muneem Ji Chat'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => chatProvider.clearChat(),
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear chat history',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatProvider.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatProvider.messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),
          if (chatProvider.isTyping)
            _buildTypingIndicator(),
          _buildInputSection(chatProvider),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined, size: 48, color: AppColors.brand),
          ),
          const SizedBox(height: 16),
          const Text('Your Smart Financial Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Ask about your balances, spending trends,\nor bill summaries!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          _buildSuggestionChip('How much do I owe total?'),
          _buildSuggestionChip('Summary for travel expenses 2025'),
          _buildSuggestionChip('Am I within budget this month?'),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        final prov = Provider.of<ChatProvider>(context, listen: false);
        prov.sendMessage(text, context);
        _scrollToBottom();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brand.withOpacity(0.2)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.brand)),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isAssistant = msg.role == MessageRole.assistant;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isAssistant 
              ? (isDark ? AppColors.surfaceDark : Colors.white)
              : AppColors.brand,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isAssistant ? 0 : 20),
            bottomRight: Radius.circular(isAssistant ? 20 : 0),
          ),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          border: isAssistant && isDark ? Border.all(color: Colors.white12) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isAssistant 
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('hh:mm a').format(msg.timestamp),
              style: TextStyle(
                fontSize: 9,
                color: isAssistant ? Colors.grey : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.brand)),
          ),
          SizedBox(width: 8),
          Text('Muneem Ji is thinking...', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInputSection(ChatProvider chatProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type your question...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onSubmitted: (_) {
                chatProvider.sendMessage(_controller.text, context);
                _controller.clear();
                _scrollToBottom();
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              chatProvider.sendMessage(_controller.text, context);
              _controller.clear();
              _scrollToBottom();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
