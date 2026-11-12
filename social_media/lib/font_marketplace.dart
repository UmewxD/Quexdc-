import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _fontBucket = 'community-fonts';
const _maxFontSizeBytes = 5 * 1024 * 1024;

class FontMarketplaceService {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  static bool _ready = false;
  static String? configurationError;

  static bool get isReady => _ready;

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => _ready ? client.auth.currentUser : null;

  static Future<void> initialize() async {
    if (_url.isEmpty && _publishableKey.isEmpty) return;
    if (_url.isEmpty || _publishableKey.isEmpty) {
      configurationError =
          'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required.';
      return;
    }
    final projectUri = Uri.tryParse(_url);
    if (projectUri == null ||
        projectUri.scheme != 'https' ||
        projectUri.host.isEmpty ||
        _url.toLowerCase().contains('your_project') ||
        _url.contains('<') ||
        _url.contains('>')) {
      configurationError = 'Replace the SUPABASE_URL placeholder with your real Supabase Project URL (https://<project-ref>.supabase.co).';
      return;
    }
    if (_publishableKey.toLowerCase().contains('your_public') ||
        _publishableKey.contains('<') ||
        _publishableKey.contains('>')) {
      configurationError = 'Replace the SUPABASE_PUBLISHABLE_KEY placeholder with the public key from your Supabase project.';
      return;
    }

    try {
      await Supabase.initialize(url: _url, publishableKey: _publishableKey);
      _ready = true;
    } catch (error) {
      configurationError = 'Supabase could not start: $error';
    }
  }

  static Future<List<FontListing>> listFonts({String? creatorName}) async {
    _requireReady();
    final rows = creatorName == null
        ? await client
              .from('font_listings')
              .select()
              .order('created_at', ascending: false)
        : await client
              .from('font_listings')
              .select()
              .eq('creator_name', creatorName)
              .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => FontListing.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<FontListing?> getFont(String id) async {
    _requireReady();
    final row = await client
        .from('font_listings')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : FontListing.fromJson(row);
  }

  static Future<Uint8List> downloadFont(FontListing listing) async {
    _requireReady();
    return client.storage.from(_fontBucket).download(listing.objectPath);
  }

  static Future<void> sendMagicLink(String email) async {
    _requireReady();
    final currentUri = Uri.base;
    final redirectTo =
        currentUri.scheme == 'http' || currentUri.scheme == 'https'
        ? currentUri.origin
        : null;
    await client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: redirectTo,
    );
  }

  static Future<FontListing> publishFont({
    required String name,
    required String creatorName,
    required String description,
    required String licenseName,
    required String licenseTerms,
    required PlatformFile file,
  }) async {
    _requireReady();
    final user = currentUser;
    if (user == null) throw StateError('Sign in before publishing a font.');

    final bytes = await file.readAsBytes();
    validateFontFile(file.name, bytes);
    final extension = file.name.split('.').last.toLowerCase();
    final objectPath =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final contentType = extension == 'otf' ? 'font/otf' : 'font/ttf';
    final storage = client.storage.from(_fontBucket);

    await storage.uploadBinary(
      objectPath,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        cacheControl: '3600',
        upsert: false,
      ),
    );

    try {
      final row = await client
          .from('font_listings')
          .insert({
            'creator_id': user.id,
            'creator_name': creatorName.trim(),
            'name': name.trim(),
            'description': description.trim(),
            'object_path': objectPath,
            'license_name': licenseName,
            'license_terms': licenseTerms.trim(),
          })
          .select()
          .single();
      return FontListing.fromJson(row);
    } catch (error) {
      try {
        await storage.remove([objectPath]);
      } catch (cleanupError) {
        throw StateError(
          'The listing could not be saved ($error), and its uploaded file could not be removed ($cleanupError).',
        );
      }
      rethrow;
    }
  }

  static Future<void> requestLicense({
    required FontListing listing,
    required String requesterName,
    required String message,
  }) async {
    _requireReady();
    final user = currentUser;
    if (user == null) throw StateError('Sign in before requesting a license.');
    await client.from('font_license_requests').insert({
      'font_id': listing.id,
      'requester_id': user.id,
      'requester_name': requesterName.trim(),
      'message': message.trim(),
    });
  }

  static Future<List<FontLicenseRequest>> listMyRequests() async {
    _requireReady();
    final rows = await client
        .from('font_license_requests')
        .select('*, font_listings(name, creator_id)')
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) => FontLicenseRequest.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<void> respondToRequest(
    FontLicenseRequest request, {
    required String status,
    required String response,
  }) async {
    _requireReady();
    if (status != 'approved' && status != 'declined') {
      throw ArgumentError.value(status, 'status', 'Must approve or decline.');
    }
    final updated = await client
        .from('font_license_requests')
        .update({'status': status, 'response': response.trim()})
        .eq('id', request.id)
        .eq('status', 'open')
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('This request has already been answered or removed.');
    }
  }

  static Future<void> signOut() async {
    _requireReady();
    await client.auth.signOut();
  }

  static void _requireReady() {
    if (!_ready) {
      throw StateError(
        configurationError ?? 'Configure Supabase to use the font marketplace.',
      );
    }
  }

  static void validateFontFile(String filename, Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > _maxFontSizeBytes) {
      throw const FormatException(
        'Font files must be between 1 byte and 5 MB.',
      );
    }
    final extension = filename.split('.').last.toLowerCase();
    final isTrueType =
        bytes.length >= 4 &&
        bytes[0] == 0x00 &&
        bytes[1] == 0x01 &&
        bytes[2] == 0x00 &&
        bytes[3] == 0x00;
    final isOpenType =
        bytes.length >= 4 &&
        bytes[0] == 0x4f &&
        bytes[1] == 0x54 &&
        bytes[2] == 0x54 &&
        bytes[3] == 0x4f;
    if ((extension != 'ttf' && extension != 'otf') ||
        (extension == 'ttf' && !isTrueType) ||
        (extension == 'otf' && !isOpenType)) {
      throw const FormatException(
        'Choose a valid TrueType (.ttf) or OpenType (.otf) font file.',
      );
    }
  }
}

class FontListing {
  const FontListing({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.name,
    required this.description,
    required this.objectPath,
    required this.licenseName,
    required this.licenseTerms,
  });

  final String id;
  final String creatorId;
  final String creatorName;
  final String name;
  final String description;
  final String objectPath;
  final String licenseName;
  final String licenseTerms;

  factory FontListing.fromJson(Map<String, dynamic> json) => FontListing(
    id: json['id'] as String,
    creatorId: json['creator_id'] as String,
    creatorName: json['creator_name'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    objectPath: json['object_path'] as String,
    licenseName: json['license_name'] as String,
    licenseTerms: json['license_terms'] as String? ?? '',
  );

  String get family => 'CommunityFont${id.replaceAll('-', '')}';
}

class FontLicenseRequest {
  const FontLicenseRequest({
    required this.id,
    required this.fontId,
    required this.requesterId,
    required this.requesterName,
    required this.message,
    required this.status,
    required this.response,
    required this.fontName,
    required this.fontCreatorId,
  });

  final String id;
  final String fontId;
  final String requesterId;
  final String requesterName;
  final String message;
  final String status;
  final String response;
  final String fontName;
  final String fontCreatorId;

  factory FontLicenseRequest.fromJson(Map<String, dynamic> json) {
    final font = Map<String, dynamic>.from(json['font_listings'] as Map);
    return FontLicenseRequest(
      id: json['id'] as String,
      fontId: json['font_id'] as String,
      requesterId: json['requester_id'] as String,
      requesterName: json['requester_name'] as String,
      message: json['message'] as String,
      status: json['status'] as String,
      response: json['response'] as String? ?? '',
      fontName: font['name'] as String,
      fontCreatorId: font['creator_id'] as String,
    );
  }
}

class FontMarketplaceScreen extends StatefulWidget {
  const FontMarketplaceScreen({super.key, required this.onApplyFont});

  final Future<void> Function(FontListing listing) onApplyFont;

  @override
  State<FontMarketplaceScreen> createState() => _FontMarketplaceScreenState();
}

class _FontMarketplaceScreenState extends State<FontMarketplaceScreen> {
  List<FontListing> _listings = [];
  List<FontLicenseRequest> _requests = [];
  bool _loading = false;
  String? _error;
  int _tabIndex = 0;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (FontMarketplaceService.isReady) {
      _authSubscription = FontMarketplaceService.client.auth.onAuthStateChange
          .listen((_) {
            if (mounted) {
              setState(() {});
              _loadMarketplace();
            }
          });
      _loadMarketplace();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMarketplace() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listings = await FontMarketplaceService.listFonts();
      final requests = FontMarketplaceService.currentUser == null
          ? <FontLicenseRequest>[]
          : await FontMarketplaceService.listMyRequests();
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _requests = requests;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _uploadFont() async {
    if (FontMarketplaceService.currentUser == null) {
      _showMessage('Sign in with email before publishing.');
      return;
    }
    final draft = await showDialog<_FontUploadDraft>(
      context: context,
      builder: (context) => const _FontUploadDialog(),
    );
    if (draft == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FontMarketplaceService.publishFont(
        name: draft.name,
        creatorName: draft.creatorName,
        description: draft.description,
        licenseName: draft.licenseName,
        licenseTerms: draft.licenseTerms,
        file: draft.file,
      );
      await _loadMarketplace();
      _showMessage('Font published to the community marketplace.');
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _applyFont(FontListing listing) async {
    try {
      await widget.onApplyFont(listing);
      _showMessage('${listing.name} is now your app font.');
    } catch (error) {
      _showMessage('Could not apply font: $error');
    }
  }

  Future<void> _requestLicense(FontListing listing) async {
    final draft = await showDialog<_LicenseRequestDraft>(
      context: context,
      builder: (context) => const _LicenseRequestDialog(),
    );
    if (draft == null) return;
    try {
      await FontMarketplaceService.requestLicense(
        listing: listing,
        requesterName: draft.name,
        message: draft.message,
      );
      await _loadMarketplace();
      _showMessage('Your license request was sent to the creator.');
    } catch (error) {
      _showMessage('Could not send request: $error');
    }
  }

  Future<void> _respondToRequest(
    FontLicenseRequest request,
    String status,
  ) async {
    final response = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          status == 'approved'
              ? 'Approve license request'
              : 'Decline license request',
        ),
        content: TextField(
          controller: response,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reply to the requester',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send reply'),
          ),
        ],
      ),
    );
    final reply = response.text.trim();
    response.dispose();
    if (approved != true) return;
    try {
      await FontMarketplaceService.respondToRequest(
        request,
        status: status,
        response: reply,
      );
      await _loadMarketplace();
    } catch (error) {
      _showMessage('Could not update request: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FontMarketplaceService.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Font Market'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await FontMarketplaceService.signOut();
                if (mounted) await _loadMarketplace();
              },
              icon: const Icon(Icons.logout),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: FontMarketplaceService.isReady ? _loadMarketplace : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: FontMarketplaceService.isReady
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Center(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Fonts'),
                        selected: _tabIndex == 0,
                        onSelected: (_) => setState(() => _tabIndex = 0),
                      ),
                      ChoiceChip(
                        label: const Text('License requests'),
                        selected: _tabIndex == 1,
                        onSelected: (_) => setState(() => _tabIndex = 1),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: user == null || !FontMarketplaceService.isReady
          ? null
          : FloatingActionButton.extended(
              onPressed: _loading ? null : _uploadFont,
              icon: const Icon(Icons.upload_file),
              label: const Text('Publish a font'),
            ),
      body: !FontMarketplaceService.isReady
          ? _SupabaseSetupMessage(
              error: FontMarketplaceService.configurationError,
            )
          : Column(
              children: [
                if (user == null) const _EmailSignInPanel(),
                if (_error != null)
                  MaterialBanner(
                    content: Text(_error!),
                    actions: [
                      TextButton(
                        onPressed: _loadMarketplace,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                if (_loading) const LinearProgressIndicator(),
                Expanded(
                  child: _tabIndex == 0
                      ? _listings.isEmpty && !_loading
                            ? const Center(
                                child: Text(
                                  'No community fonts yet. Publish the first one!',
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadMarketplace,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    88,
                                  ),
                                  itemCount: _listings.length,
                                  itemBuilder: (context, index) =>
                                      _FontListingCard(
                                        listing: _listings[index],
                                        onApply: () =>
                                            _applyFont(_listings[index]),
                                        onRequest: user == null
                                            ? null
                                            : () => _requestLicense(
                                                _listings[index],
                                              ),
                                      ),
                                ),
                              )
                      : _requests.isEmpty
                      ? const Center(child: Text('No license requests yet.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final request = _requests[index];
                            final isCreator = request.fontCreatorId == user?.id;
                            return Card(
                              child: ListTile(
                                title: Text(
                                  '${request.fontName} · ${request.status}',
                                ),
                                subtitle: Text(
                                  '${isCreator ? request.requesterName : 'Your request'}: ${request.message}'
                                  '${request.response.isEmpty ? '' : '\nReply: ${request.response}'}',
                                ),
                                trailing: isCreator && request.status == 'open'
                                    ? PopupMenuButton<String>(
                                        onSelected: (status) =>
                                            _respondToRequest(request, status),
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'approved',
                                            child: Text('Approve'),
                                          ),
                                          PopupMenuItem(
                                            value: 'declined',
                                            child: Text('Decline'),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class CreatorFontsSection extends StatefulWidget {
  const CreatorFontsSection({
    super.key,
    required this.creatorName,
    required this.onApplyFont,
  });

  final String creatorName;
  final Future<void> Function(FontListing listing) onApplyFont;

  @override
  State<CreatorFontsSection> createState() => _CreatorFontsSectionState();
}

class _CreatorFontsSectionState extends State<CreatorFontsSection> {
  late Future<List<FontListing>> _fonts;

  @override
  void initState() {
    super.initState();
    _fonts = _load();
  }

  @override
  void didUpdateWidget(covariant CreatorFontsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.creatorName != widget.creatorName) _fonts = _load();
  }

  Future<List<FontListing>> _load() {
    if (!FontMarketplaceService.isReady) return Future.value(const []);
    return FontMarketplaceService.listFonts(creatorName: widget.creatorName);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FontListing>>(
      future: _fonts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ListTile(
            leading: Icon(Icons.font_download_outlined),
            title: Text('Community fonts'),
            subtitle: Text('Could not load this creator’s fonts.'),
          );
        }
        final fonts = snapshot.data ?? const <FontListing>[];
        if (fonts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Fonts by this creator',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...fonts.map(
              (font) => ListTile(
                leading: const Icon(Icons.text_fields),
                title: Text(font.name),
                subtitle: Text(font.licenseName),
                trailing: IconButton(
                  tooltip: 'Use font',
                  onPressed: () async {
                    try {
                      await widget.onApplyFont(font);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${font.name} is now your app font.'),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not apply font: $error'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FontListingCard extends StatelessWidget {
  const _FontListingCard({
    required this.listing,
    required this.onApply,
    required this.onRequest,
  });

  final FontListing listing;
  final VoidCallback onApply;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(listing.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('by ${listing.creatorName} · ${listing.licenseName}'),
            if (listing.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(listing.description),
            ],
            if (listing.licenseTerms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                listing.licenseTerms,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onApply,
                  icon: const Icon(Icons.text_fields),
                  label: const Text('Apply font'),
                ),
                if (onRequest != null)
                  OutlinedButton.icon(
                    onPressed: onRequest,
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Request license'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailSignInPanel extends StatefulWidget {
  const _EmailSignInPanel();

  @override
  State<_EmailSignInPanel> createState() => _EmailSignInPanelState();
}

class _EmailSignInPanelState extends State<_EmailSignInPanel> {
  final _email = TextEditingController();
  bool _sending = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    final email = _email.text.trim();
    if (!email.contains('@') || email.endsWith('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _message = null;
    });
    try {
      await FontMarketplaceService.sendMagicLink(email);
      if (!mounted) return;
      setState(() {
        _message = 'Check your email and open the sign-in link to continue.';
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sign in to publish fonts or request licenses.'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sending ? null : _sendLink,
                  child: Text(_sending ? 'Sending' : 'Email me a link'),
                ),
              ],
            ),
            if (_message != null)
              Text(_message!, style: const TextStyle(color: Colors.green)),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

class _FontUploadDraft {
  const _FontUploadDraft({
    required this.name,
    required this.creatorName,
    required this.description,
    required this.licenseName,
    required this.licenseTerms,
    required this.file,
  });

  final String name;
  final String creatorName;
  final String description;
  final String licenseName;
  final String licenseTerms;
  final PlatformFile file;
}

class _FontUploadDialog extends StatefulWidget {
  const _FontUploadDialog();

  @override
  State<_FontUploadDialog> createState() => _FontUploadDialogState();
}

class _FontUploadDialogState extends State<_FontUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _creator = TextEditingController();
  final _description = TextEditingController();
  final _terms = TextEditingController();
  PlatformFile? _file;
  String _license = 'Free with attribution';
  bool _confirmsRights = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _creator.dispose();
    _description.dispose();
    _terms.dispose();
    super.dispose();
  }

  Future<void> _pickFont() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['ttf', 'otf'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      FontMarketplaceService.validateFontFile(file.name, bytes);
      if (mounted) {
        setState(() {
          _file = file;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_file == null) {
      setState(() => _error = 'Choose a .ttf or .otf font file.');
      return;
    }
    if (!_confirmsRights) {
      setState(
        () => _error = 'Confirm that you have the right to share this font.',
      );
      return;
    }
    Navigator.pop(
      context,
      _FontUploadDraft(
        name: _name.text.trim(),
        creatorName: _creator.text.trim(),
        description: _description.text.trim(),
        licenseName: _license,
        licenseTerms: _terms.text.trim(),
        file: _file!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Publish a community font'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Font name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a font name.'
                      : null,
                ),
                TextFormField(
                  controller: _creator,
                  maxLength: 32,
                  decoration: const InputDecoration(
                    labelText: 'Creator name / profile handle',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a creator name.'
                      : null,
                ),
                TextFormField(
                  controller: _description,
                  maxLength: 240,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _license,
                  decoration: const InputDecoration(labelText: 'License'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Free with attribution',
                      child: Text('Free with attribution'),
                    ),
                    DropdownMenuItem(
                      value: 'Free for personal use',
                      child: Text('Free for personal use'),
                    ),
                    DropdownMenuItem(
                      value: 'Custom terms - request permission',
                      child: Text('Custom terms - request permission'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _license = value);
                  },
                ),
                TextFormField(
                  controller: _terms,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'License details / attribution',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _pickFont,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_file?.name ?? 'Choose TTF / OTF (up to 5 MB)'),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmsRights,
                  onChanged: (value) =>
                      setState(() => _confirmsRights = value == true),
                  title: const Text(
                    'I created this font or have permission to share it.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Publish free')),
      ],
    );
  }
}

class _LicenseRequestDraft {
  const _LicenseRequestDraft({required this.name, required this.message});

  final String name;
  final String message;
}

class _LicenseRequestDialog extends StatefulWidget {
  const _LicenseRequestDialog();

  @override
  State<_LicenseRequestDialog> createState() => _LicenseRequestDialogState();
}

class _LicenseRequestDialogState extends State<_LicenseRequestDialog> {
  final _name = TextEditingController();
  final _message = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _message.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name and how you plan to use it.');
      return;
    }
    Navigator.pop(
      context,
      _LicenseRequestDraft(
        name: _name.text.trim(),
        message: _message.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request a license'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            maxLength: 32,
            decoration: const InputDecoration(labelText: 'Your creator name'),
          ),
          TextField(
            controller: _message,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'How do you want to use this font?',
            ),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send request')),
      ],
    );
  }
}

class _SupabaseSetupMessage extends StatelessWidget {
  const _SupabaseSetupMessage({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 44),
            const SizedBox(height: 12),
            const Text('Connect Supabase to use the shared font marketplace.'),
            const SizedBox(height: 8),
            Text(
              error ?? 'Set SUPABASE_URL and SUPABASE_ANON_KEY when running the app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
