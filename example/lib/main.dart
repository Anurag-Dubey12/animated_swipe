import 'package:flutter/material.dart';
import 'package:echo_animated_swipe/echo_animated_swipe.dart';

void main() => runApp(const AnimatedSwipeExampleApp());

class AnimatedSwipeExampleApp extends StatelessWidget {
  const AnimatedSwipeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Echo Animated Swipe example',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
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

enum _ActionContent {
  text('Text only'),
  icon('Icon only'),
  iconAndText('Icon and text'),
  custom('Custom widget');

  const _ActionContent(this.title);

  final String title;
}

class _MailInboxPageState extends State<MailInboxPage> {
  final _controller = SwipeController();
  bool _insetActions = false;
  double _cornerRadius = 16;
  bool _enableHaptics = true;
  _ActionContent _actionContent = _ActionContent.iconAndText;

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
      const SnackBar(content: Text('Archived'), duration: Duration(seconds: 1)),
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
      const SnackBar(content: Text('Flagged'), duration: Duration(seconds: 1)),
    );
    _controller.close(id);
  }

  void _changeLayout(bool inset) {
    _controller.closeAll();
    setState(() => _insetActions = inset);
  }

  SwipeAction _action({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return SwipeAction(
      id: id,
      backgroundColor: color,
      semanticLabel: label,
      onTap: onTap,
      isPrimary: isPrimary,
      icon:
          _actionContent == _ActionContent.icon ||
              _actionContent == _ActionContent.iconAndText
          ? Icon(
              icon,
              semanticLabel: _actionContent == _ActionContent.icon
                  ? label
                  : null,
            )
          : null,
      label:
          _actionContent == _ActionContent.text ||
              _actionContent == _ActionContent.iconAndText
          ? label
          : null,
      customWidget: _actionContent == _ActionContent.custom
          ? Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'Action layout',
            initialValue: _insetActions,
            onSelected: _changeLayout,
            itemBuilder: (context) => const [
              PopupMenuItem(value: false, child: Text('Full-height actions')),
              PopupMenuItem(value: true, child: Text('Inset action')),
            ],
          ),
          PopupMenuButton<_ActionContent>(
            tooltip: 'Action content',
            icon: const Icon(Icons.widgets_outlined),
            initialValue: _actionContent,
            onSelected: (content) => setState(() => _actionContent = content),
            itemBuilder: (context) => [
              for (final content in _ActionContent.values)
                CheckedPopupMenuItem(
                  value: content,
                  checked: _actionContent == content,
                  child: Text(content.title),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.phone_android),
            selectedIcon: const Icon(Icons.vibration),
            isSelected: _enableHaptics,
            tooltip: _enableHaptics ? 'Turn haptics off' : 'Turn haptics on',
            onPressed: () => setState(() => _enableHaptics = !_enableHaptics),
          ),
          PopupMenuButton<double>(
            tooltip: 'Corner radius',
            icon: const Icon(Icons.rounded_corner),
            initialValue: _cornerRadius,
            onSelected: (radius) => setState(() => _cornerRadius = radius),
            itemBuilder: (context) => [
              for (final radius in [0.0, 8.0, 16.0, 24.0])
                CheckedPopupMenuItem(
                  value: radius,
                  checked: _cornerRadius == radius,
                  child: Text('${radius.toInt()} px'),
                ),
            ],
          ),
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
            cornerRadius: _cornerRadius,
            leftActions: _insetActions
                ? [
                    _action(
                      id: 'hide_${msg.id}',
                      label: 'Hide',
                      icon: Icons.visibility_off,
                      color: Colors.red,
                      onTap: () => setState(
                        () => _messages.removeWhere((m) => m.id == msg.id),
                      ),
                    ),
                  ]
                : [
                    _action(
                      id: 'delete_${msg.id}',
                      icon: Icons.delete,
                      label: 'Delete',
                      color: Colors.red,
                      isPrimary: true,
                      onTap: () => _deleteMessage(msg.id),
                    ),
                    _action(
                      id: 'archive_${msg.id}',
                      icon: Icons.archive,
                      label: 'Archive',
                      color: const Color(0xFF5856D6),
                      onTap: () => _archiveMessage(msg.id),
                    ),
                  ],
            rightActions: [
              _action(
                id: 'read_${msg.id}',
                icon: Icons.mark_email_read,
                label: 'Read',
                color: Colors.blue,
                isPrimary: true,
                onTap: () => _markRead(msg.id),
              ),
              if (!_insetActions)
                _action(
                  id: 'flag_${msg.id}',
                  icon: Icons.flag,
                  label: 'Flag',
                  color: Colors.orange,
                  onTap: () => _flagMessage(msg.id),
                ),
            ],
            configuration: SwipeConfiguration(
              enableHaptics: _enableHaptics,
              actionWidth: _insetActions ? 64 : 96,
              actionInsets: _insetActions
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
                  : EdgeInsets.zero,
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
