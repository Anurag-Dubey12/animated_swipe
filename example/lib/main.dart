import 'package:flutter/material.dart';
import 'package:animated_swipe/animated_swipe.dart';

void main() => runApp(const AnimatedSwipeExampleApp());

class AnimatedSwipeExampleApp extends StatelessWidget {
  const AnimatedSwipeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'animated_swipe example',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const MailInboxPage(),
    );
  }
}

class MailMessage {
  const MailMessage({
    required this.id,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.time,
    this.isRead = false,
  });

  final String id;
  final String sender;
  final String subject;
  final String preview;
  final String time;
  final bool isRead;

  MailMessage copyWith({bool? isRead}) => MailMessage(
        id: id,
        sender: sender,
        subject: subject,
        preview: preview,
        time: time,
        isRead: isRead ?? this.isRead,
      );
}

class MailInboxPage extends StatefulWidget {
  const MailInboxPage({super.key});

  @override
  State<MailInboxPage> createState() => _MailInboxPageState();
}

class _MailInboxPageState extends State<MailInboxPage> {
  final _controller = SwipeController();

  late List<MailMessage> _messages = List.generate(
    20,
    (i) => MailMessage(
      id: 'msg_$i',
      sender: _senders[i % _senders.length],
      subject: _subjects[i % _subjects.length],
      preview: _previews[i % _previews.length],
      time: '${i + 1}h ago',
      isRead: i % 3 == 0,
    ),
  );

  static const _senders = [
    'Apple',
    'GitHub',
    'Figma',
    'Notion',
    'Linear',
    'Slack',
  ];

  static const _subjects = [
    'Your receipt from the App Store',
    'New pull request opened',
    'Design handoff ready',
    'Weekly digest',
    'Issue assigned to you',
    'You have unread messages',
  ];

  static const _previews = [
    'Thank you for your purchase of...',
    'Someone opened a new PR in your repo...',
    'Figma file has been shared with you...',
    "Here's what happened this week...",
    'A new issue has been assigned to you...',
    'You have 3 unread messages in #general...',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _deleteMessage(String id) {
    setState(() => _messages.removeWhere((m) => m.id == id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message deleted'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _archiveMessage(String id) {
    setState(() => _messages.removeWhere((m) => m.id == id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archived'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _markRead(String id) {
    setState(() {
      _messages = _messages.map((m) {
        if (m.id == id) return m.copyWith(isRead: true);
        return m;
      }).toList();
    });
    _controller.close(id);
  }

  void _flagMessage(String id) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flagged'),
        duration: Duration(seconds: 1),
      ),
    );
    _controller.close(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_fullscreen),
            tooltip: 'Close all',
            onPressed: _controller.closeAll,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          return SwipeableListItem(
            key: ValueKey(msg.id),
            itemId: msg.id,
            controller: _controller,
            itemHeight: 80,
            cornerRadius: 0,
            leftActions: [
              SwipeAction(
                id: 'delete_${msg.id}',
                icon: const Icon(Icons.delete),
                label: 'Delete',
                backgroundColor: Colors.red,
                isPrimary: true,
                onTap: () => _deleteMessage(msg.id),
              ),
              SwipeAction(
                id: 'archive_${msg.id}',
                icon: const Icon(Icons.archive),
                label: 'Archive',
                backgroundColor: const Color(0xFF5856D6),
                onTap: () => _archiveMessage(msg.id),
              ),
            ],
            rightActions: [
              SwipeAction(
                id: 'read_${msg.id}',
                icon: const Icon(Icons.mark_email_read),
                label: 'Read',
                backgroundColor: Colors.blue,
                isPrimary: true,
                onTap: () => _markRead(msg.id),
              ),
              SwipeAction(
                id: 'flag_${msg.id}',
                icon: const Icon(Icons.flag),
                label: 'Flag',
                backgroundColor: Colors.orange,
                onTap: () => _flagMessage(msg.id),
              ),
            ],
            configuration: const SwipeConfiguration(
              enableHaptics: true,
              actionWidth: 88,
              springDamping: 0.7,
              springResponse: 0.38,
            ),
            child: _MailTile(message: msg),
          );
        },
      ),
    );
  }
}

class _MailTile extends StatelessWidget {
  const _MailTile({required this.message});

  final MailMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: message.isRead
                  ? Colors.transparent
                  : theme.colorScheme.primary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.sender,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: message.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      message.time,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message.subject,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: message.isRead
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  message.preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
