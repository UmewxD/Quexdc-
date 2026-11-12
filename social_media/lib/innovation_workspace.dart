import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum InnovationStage { idea, preparing, filingReported }

extension InnovationStageLabel on InnovationStage {
  String get label => switch (this) {
    InnovationStage.idea => 'Idea draft',
    InnovationStage.preparing => 'Preparing to seek advice',
    InnovationStage.filingReported => 'Filing reported by creator',
  };
}

enum InnovationFundingChoice { selfFunded, optionalDonation, supportRequest }

extension InnovationFundingLabel on InnovationFundingChoice {
  String get label => switch (this) {
    InnovationFundingChoice.selfFunded => 'Self-funded',
    InnovationFundingChoice.optionalDonation => 'Optional donation only',
    InnovationFundingChoice.supportRequest => 'Request support (not a promise)',
  };
}

class InnovationIdea {
  const InnovationIdea({
    required this.id,
    required this.title,
    required this.summary,
    required this.stage,
    required this.fundingChoice,
    required this.donationPercent,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String summary;
  final InnovationStage stage;
  final InnovationFundingChoice fundingChoice;
  final int donationPercent;
  final DateTime createdAt;

  InnovationIdea copyWith({InnovationStage? stage}) => InnovationIdea(
    id: id,
    title: title,
    summary: summary,
    stage: stage ?? this.stage,
    fundingChoice: fundingChoice,
    donationPercent: donationPercent,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'stage': stage.name,
    'fundingChoice': fundingChoice.name,
    'donationPercent': donationPercent,
    'createdAt': createdAt.toIso8601String(),
  };

  factory InnovationIdea.fromJson(Map<String, dynamic> json) {
    final stage = InnovationStage.values
        .where((item) => item.name == json['stage'])
        .firstOrNull;
    final funding = InnovationFundingChoice.values
        .where((item) => item.name == json['fundingChoice'])
        .firstOrNull;
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final donationPercent = json['donationPercent'] as int?;
    if (stage == null ||
        funding == null ||
        createdAt == null ||
        donationPercent == null ||
        donationPercent < 0 ||
        donationPercent > 25) {
      throw const FormatException('Saved innovation idea data is invalid.');
    }
    return InnovationIdea(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      stage: stage,
      fundingChoice: funding,
      donationPercent: donationPercent,
      createdAt: createdAt,
    );
  }
}

class InnovationWorkspaceStore {
  static const storageKey = 'innovation_workspace_v1';

  static Future<List<InnovationIdea>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(storageKey);
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Saved innovation ideas must be a list.');
    }
    return decoded
        .map(
          (item) =>
              InnovationIdea.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  static Future<void> save(List<InnovationIdea> ideas) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      storageKey,
      jsonEncode(ideas.map((idea) => idea.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('The device declined to save your idea notes.');
    }
  }
}

class InnovationWorkspaceScreen extends StatefulWidget {
  const InnovationWorkspaceScreen({super.key});

  @override
  State<InnovationWorkspaceScreen> createState() =>
      _InnovationWorkspaceScreenState();
}

class _InnovationWorkspaceScreenState extends State<InnovationWorkspaceScreen> {
  List<InnovationIdea> _ideas = const [];
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ideas = await InnovationWorkspaceStore.load();
      if (!mounted) return;
      setState(() {
        _ideas = ideas;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error;
      });
    }
  }

  Future<void> _createIdea() async {
    final idea = await showDialog<InnovationIdea>(
      context: context,
      builder: (_) => const _NewInnovationIdeaDialog(),
    );
    if (idea == null) return;
    try {
      final updated = [..._ideas, idea];
      await InnovationWorkspaceStore.save(updated);
      if (mounted) setState(() => _ideas = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your idea note: $error')),
      );
    }
  }

  Future<void> _updateStage(InnovationIdea idea, InnovationStage stage) async {
    final updated = _ideas
        .map((item) => item.id == idea.id ? item.copyWith(stage: stage) : item)
        .toList();
    try {
      await InnovationWorkspaceStore.save(updated);
      if (mounted) setState(() => _ideas = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update idea status: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inventor workspace')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _isLoading || _error != null ? null : _createIdea,
      icon: const Icon(Icons.add),
      label: const Text('New idea note'),
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load local idea notes.'),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'A place to organize early ideas. These notes stay on this '
                    'device and are not encrypted, shared, or a proof-of-origin '
                    'record. Avoid entering trade secrets or anything you need '
                    'to keep confidential.',
                  ),
                ),
              ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Patent progress is self-reported: Quexdc does not file, '
                    'review, or grant patents. Crowdfunding campaign notes are '
                    'not sent to Kickstarter, Indiegogo, governments, or any '
                    'other service. This prototype provides no funding, debt, '
                    'payment, or royalty agreement.',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_ideas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No idea notes yet. Add one to organize your next steps.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ..._ideas.map(_buildIdeaCard),
              const SizedBox(height: 12),
              const Text(
                'Campaign checklist (not connected)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const ListTile(
                leading: Icon(Icons.public),
                title: Text('Kickstarter · Indiegogo · other platforms'),
                subtitle: Text(
                  'Check each platform’s current country, eligibility, and payout rules directly.',
                ),
              ),
            ],
          ),
  );

  Widget _buildIdeaCard(InnovationIdea idea) => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.lightbulb_outline),
      title: Text(idea.title),
      subtitle: Text(
        '${idea.stage.label} · ${idea.fundingChoice.label}'
        '${idea.donationPercent > 0 ? ' · ${idea.donationPercent}% preference' : ''}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (idea.summary.isNotEmpty)
          Align(alignment: Alignment.centerLeft, child: Text(idea.summary)),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<InnovationStage>(
            tooltip: 'Change self-reported progress',
            onSelected: (stage) => _updateStage(idea, stage),
            itemBuilder: (context) => InnovationStage.values
                .map(
                  (stage) =>
                      PopupMenuItem(value: stage, child: Text(stage.label)),
                )
                .toList(),
            child: const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Edit self-reported progress'),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _NewInnovationIdeaDialog extends StatefulWidget {
  const _NewInnovationIdeaDialog();

  @override
  State<_NewInnovationIdeaDialog> createState() =>
      _NewInnovationIdeaDialogState();
}

class _NewInnovationIdeaDialogState extends State<_NewInnovationIdeaDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  InnovationStage _stage = InnovationStage.idea;
  InnovationFundingChoice _fundingChoice = InnovationFundingChoice.selfFunded;
  int _donationPercent = 0;
  bool _acknowledgedLocalStorage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty || !_acknowledgedLocalStorage) return;
    final now = DateTime.now();
    Navigator.pop(
      context,
      InnovationIdea(
        id: now.microsecondsSinceEpoch.toString(),
        title: title,
        summary: _summaryController.text.trim(),
        stage: _stage,
        fundingChoice: _fundingChoice,
        donationPercent:
            _fundingChoice == InnovationFundingChoice.optionalDonation
            ? _donationPercent
            : 0,
        createdAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New invention / idea note'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _summaryController,
            maxLength: 800,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Describe the idea or next steps.',
            ),
          ),
          DropdownButtonFormField<InnovationStage>(
            initialValue: _stage,
            decoration: const InputDecoration(
              labelText: 'Progress (self-reported)',
            ),
            items: InnovationStage.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _stage = value);
            },
          ),
          DropdownButtonFormField<InnovationFundingChoice>(
            initialValue: _fundingChoice,
            decoration: const InputDecoration(labelText: 'Funding preference'),
            items: InnovationFundingChoice.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _fundingChoice = value);
            },
          ),
          if (_fundingChoice == InnovationFundingChoice.optionalDonation)
            Column(
              children: [
                Text('Optional contribution: $_donationPercent%'),
                Slider(
                  value: _donationPercent.toDouble(),
                  min: 0,
                  max: 25,
                  divisions: 25,
                  label: '$_donationPercent%',
                  onChanged: (value) =>
                      setState(() => _donationPercent = value.round()),
                ),
                const Text(
                  'This records a preference only. No money or ownership is transferred.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acknowledgedLocalStorage,
            onChanged: (value) =>
                setState(() => _acknowledgedLocalStorage = value ?? false),
            title: const Text(
              'I understand these notes are stored locally without encryption.',
              style: TextStyle(fontSize: 13),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save note')),
    ],
  );
}
