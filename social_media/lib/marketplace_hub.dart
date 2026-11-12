import 'package:flutter/material.dart';

import 'easter_shop.dart';
import 'font_marketplace.dart';
import 'innovation_workspace.dart';

class MarketplaceHubScreen extends StatelessWidget {
  const MarketplaceHubScreen({
    super.key,
    required this.onApplyFont,
    required this.onOpenEasterShop,
    required this.onApplyAccent,
  });

  final Future<void> Function(FontListing listing) onApplyFont;
  final VoidCallback onOpenEasterShop;
  final ValueChanged<Color> onApplyAccent;

  void _openFonts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FontMarketplaceScreen(onApplyFont: onApplyFont),
      ),
    );
  }

  void _openThemes(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AestheticMarketplaceScreen(onApplyAccent: onApplyAccent),
      ),
    );
  }

  void _openInnovationWorkspace(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const InnovationWorkspaceScreen(),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String category) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$category Market'),
        content: Text('$category are planned for a future marketplace update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.storefront_outlined)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Explore creator-made customizations.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MarketplaceCategoryTile(
            icon: Icons.text_fields,
            title: 'Fonts',
            description: 'Browse community fonts and license options.',
            available: true,
            onTap: () => _openFonts(context),
          ),
          _MarketplaceCategoryTile(
            icon: Icons.egg_outlined,
            title: 'Easter Shop',
            description: 'Spend earned Easter Points on Quexdc cosmetics.',
            available: true,
            onTap: onOpenEasterShop,
          ),
          _MarketplaceCategoryTile(
            icon: Icons.palette_outlined,
            title: 'Themes',
            description:
                'Frutiger Aero, Weirdcore, Mysticule, seasonal styles.',
            available: true,
            onTap: () => _openThemes(context),
          ),
          _MarketplaceCategoryTile(
            icon: Icons.verified_outlined,
            title: 'Badges',
            description: 'Profile decorations and creator badges.',
            available: false,
            onTap: () => _showComingSoon(context, 'Badges'),
          ),
          _MarketplaceCategoryTile(
            icon: Icons.lightbulb_outline,
            title: 'Inventor Workspace',
            description: 'Organize local idea notes and planning checklists.',
            available: true,
            onTap: () => _openInnovationWorkspace(context),
          ),
        ],
      ),
    );
  }
}

class AestheticPack {
  const AestheticPack({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.accent,
    required this.secondary,
    this.cost = 0,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final Color accent;
  final Color secondary;
  final int cost;
}

const aestheticPacks = [
  AestheticPack(
    id: 'frutiger_aero',
    name: 'Frutiger Aero',
    category: 'Creator gift',
    description: 'Aqua glass, clear skies, and bright nature-tech colors.',
    accent: Color(0xFF00A8B5),
    secondary: Color(0xFF7BE0D3),
  ),
  AestheticPack(
    id: 'weirdcore',
    name: 'Weirdcore',
    category: 'Creator gift',
    description: 'Liminal violet, offbeat details, and dreamlike contrast.',
    accent: Color(0xFF8A65F2),
    secondary: Color(0xFFDB8BDD),
  ),
  AestheticPack(
    id: 'mysticule',
    name: 'Mysticule',
    category: 'Creator gift',
    description: 'A mystic glow of deep space and electric blue.',
    accent: Color(0xFF6D4AFF),
    secondary: Color(0xFF2ED4E8),
  ),
  AestheticPack(
    id: 'sakura_spring',
    name: 'Sakura Spring',
    category: 'Seasonal',
    description: 'Soft blossom pink with a quiet spring-green accent.',
    accent: Color(0xFFD85F9B),
    secondary: Color(0xFF79BFA5),
    cost: 40,
  ),
  AestheticPack(
    id: 'lantern_festival',
    name: 'Lantern Festival',
    category: 'Festival',
    description: 'Warm lantern gold against vivid festival violet.',
    accent: Color(0xFFE9A23B),
    secondary: Color(0xFF9B5DE5),
    cost: 55,
  ),
  AestheticPack(
    id: 'tokyo_afterglow',
    name: 'Tokyo Afterglow',
    category: 'Regional-inspired',
    description: 'A neon city palette, available everywhere.',
    accent: Color(0xFFFF4F9A),
    secondary: Color(0xFF5D6BFF),
    cost: 60,
  ),
];

class AestheticMarketplaceScreen extends StatefulWidget {
  const AestheticMarketplaceScreen({
    super.key,
    required this.onApplyAccent,
    this.store,
  });

  final ValueChanged<Color> onApplyAccent;
  final EasterEconomyStore? store;

  @override
  State<AestheticMarketplaceScreen> createState() =>
      _AestheticMarketplaceScreenState();
}

class _AestheticMarketplaceScreenState
    extends State<AestheticMarketplaceScreen> {
  late final EasterEconomyStore _store = widget.store ?? EasterEconomyStore();
  EasterEconomySnapshot _snapshot = const EasterEconomySnapshot();
  bool _isLoading = true;
  final Set<String> _workingIds = {};
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _store.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _equip(AestheticPack pack) async {
    if (_workingIds.contains(pack.id)) return;
    final itemId = 'aesthetic_${pack.id}';
    final owned = pack.cost == 0 || _snapshot.ownedItemIds.contains(itemId);
    setState(() => _workingIds.add(pack.id));
    try {
      final updated = owned
          ? _snapshot
          : await _store.purchase(itemId: itemId, cost: pack.cost);
      widget.onApplyAccent(pack.accent);
      if (!mounted) return;
      setState(() => _snapshot = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pack.name} applied to your app colors.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not apply ${pack.name}: $error')),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _workingIds.remove(pack.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aesthetics & themes')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load theme ownership.'),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text('${_snapshot.points} Easter Points'),
                  subtitle: const Text(
                    'Local demo points only. Theme costs are not cash prices.',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Creator starter styles',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...aestheticPacks.map(_buildPackCard),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'This prototype applies each pack’s accent color across '
                    'the app. Custom backgrounds, animated effects, creator '
                    'uploads, licenses, and real-money purchases are not '
                    'included. Seasonal and regional-inspired packs do not '
                    'expire and are not restricted by location.',
                  ),
                ),
              ),
            ],
          ),
  );

  Widget _buildPackCard(AestheticPack pack) {
    final itemId = 'aesthetic_${pack.id}';
    final owned = pack.cost == 0 || _snapshot.ownedItemIds.contains(itemId);
    final working = _workingIds.contains(pack.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [pack.accent, pack.secondary],
                begin: Alignment.centerLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.auto_awesome,
                  size: 34,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          ListTile(
            title: Text(pack.name),
            subtitle: Text('${pack.category} · ${pack.description}'),
            trailing: Text(owned ? 'Free' : '${pack.cost} pts'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: OutlinedButton(
              key: ValueKey('theme-action-${pack.id}'),
              onPressed: working ? null : () => _equip(pack),
              child: Text(
                working
                    ? 'Applying…'
                    : owned
                    ? 'Apply'
                    : 'Unlock & apply',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceCategoryTile extends StatelessWidget {
  const _MarketplaceCategoryTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.available,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(description),
        trailing: available
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : const Chip(label: Text('Coming soon')),
        onTap: onTap,
      ),
    );
  }
}
