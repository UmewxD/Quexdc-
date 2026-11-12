import 'package:flutter/material.dart';

class MoodOption {
  const MoodOption(this.emoji, this.label, this.category);

  final String emoji;
  final String label;
  final String category;
}

class MoodStatus {
  const MoodStatus({
    required this.emoji,
    required this.text,
    required this.updatedAt,
    required this.anonymousVaultOnly,
    this.expiresAt,
  });

  final String emoji;
  final String text;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final bool anonymousVaultOnly;

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'text': text,
    'updatedAt': updatedAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'anonymousVaultOnly': anonymousVaultOnly,
  };

  factory MoodStatus.fromJson(Map<String, dynamic> json) => MoodStatus(
    emoji: json['emoji'] as String? ?? '🌌',
    text: json['text'] as String? ?? '',
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    anonymousVaultOnly: json['anonymousVaultOnly'] as bool? ?? false,
  );
}

class StatusMoodManager extends StatefulWidget {
  const StatusMoodManager({
    super.key,
    required this.currentStatus,
    required this.onUpdateStatus,
  });

  final MoodStatus? currentStatus;
  final Future<void> Function(MoodStatus) onUpdateStatus;

  @override
  State<StatusMoodManager> createState() => _StatusMoodManagerState();
}

class _StatusMoodManagerState extends State<StatusMoodManager> {
  static const _moods = [
    MoodOption('🌌', 'Wandering', 'Cosmic'),
    MoodOption('🎧', "Vibing to L'Amour Toujours", 'Audio'),
    MoodOption('⚡', 'Building Quexdc', 'Creative'),
    MoodOption('🌙', 'Late-Night Sanctuary', 'Escape'),
    MoodOption('🔍', 'Egg Hunting', 'Gamified'),
    MoodOption('👾', 'Alien Mode', 'Multiverse'),
  ];

  late final TextEditingController _statusController;
  late String _selectedEmoji;
  int _durationHours = 24;
  bool _anonymousVaultOnly = false;

  @override
  void initState() {
    super.initState();
    final status = widget.currentStatus;
    _selectedEmoji = status?.emoji ?? '🌌';
    _statusController = TextEditingController(text: status?.text ?? '');
    _anonymousVaultOnly = status?.anonymousVaultOnly ?? false;
    if (status?.expiresAt == null && status != null) {
      _durationHours = 0;
    } else if (status?.expiresAt != null) {
      final remaining = status!.expiresAt!.difference(DateTime.now());
      _durationHours = remaining.inHours <= 1
          ? 1
          : remaining.inHours <= 4
          ? 4
          : remaining.inHours <= 12
          ? 12
          : 24;
    }
  }

  @override
  void didUpdateWidget(covariant StatusMoodManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStatus?.updatedAt != widget.currentStatus?.updatedAt) {
      final status = widget.currentStatus;
      _selectedEmoji = status?.emoji ?? '🌌';
      _statusController.text = status?.text ?? '';
      _anonymousVaultOnly = status?.anonymousVaultOnly ?? false;
    }
  }

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _saveStatus() async {
    final now = DateTime.now();
    final status = MoodStatus(
      emoji: _selectedEmoji,
      text: _statusController.text.trim(),
      updatedAt: now,
      expiresAt: _durationHours == 0
          ? null
          : now.add(Duration(hours: _durationHours)),
      anonymousVaultOnly: _anonymousVaultOnly,
    );
    try {
      await widget.onUpdateStatus(status);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your status: $error')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your status has been saved on this device.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleStatus = widget.currentStatus;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set your presence & mood',
              style: theme.textTheme.titleMedium,
            ),
            if (visibleStatus != null &&
                !visibleStatus.isExpired &&
                !visibleStatus.anonymousVaultOnly) ...[
              const SizedBox(height: 8),
              Text(
                '${visibleStatus.emoji}  ${visibleStatus.text.isEmpty ? 'No status message' : visibleStatus.text}',
              ),
              if (!visibleStatus.anonymousVaultOnly &&
                  visibleStatus.expiresAt != null)
                Text(
                  'Clears ${_formatExpiry(visibleStatus.expiresAt!)}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _moods.map((mood) {
                final selected = _selectedEmoji == mood.emoji;
                return ChoiceChip(
                  avatar: Text(mood.emoji),
                  label: Text(mood.label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedEmoji = mood.emoji;
                      if (_statusController.text.trim().isEmpty) {
                        _statusController.text = mood.label;
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _statusController,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: 'Status',
                hintText: "What's on your mind?",
                prefixText: '$_selectedEmoji  ',
                border: const OutlineInputBorder(),
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: _durationHours,
              decoration: const InputDecoration(labelText: 'Auto-clear status'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 hour')),
                DropdownMenuItem(value: 4, child: Text('4 hours')),
                DropdownMenuItem(value: 12, child: Text('12 hours')),
                DropdownMenuItem(value: 24, child: Text('24 hours')),
                DropdownMenuItem(value: 0, child: Text('Until I change it')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _durationHours = value);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _anonymousVaultOnly,
              title: const Text('Show only in Escape Dimensions'),
              subtitle: const Text(
                'This keeps the status out of your profile; the Escape Dimensions feature is not connected yet.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) =>
                  setState(() => _anonymousVaultOnly = value ?? false),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveStatus,
                icon: const Icon(Icons.send),
                label: const Text('Save status'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatExpiry(DateTime expiry) {
    final remaining = expiry.difference(DateTime.now());
    if (remaining.inMinutes <= 0) return 'soon';
    if (remaining.inHours == 0) return 'in ${remaining.inMinutes} minutes';
    return 'in ${remaining.inHours} hours';
  }
}
