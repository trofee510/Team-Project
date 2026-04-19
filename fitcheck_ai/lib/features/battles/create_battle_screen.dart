import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/extensions.dart';
import '../../core/theme.dart';
import '../../models/fit_battle.dart';
import '../../services/battle_service.dart';
import '../../services/fit_check_engine.dart';

class CreateBattleScreen extends ConsumerStatefulWidget {
  final Uint8List? initialImage;
  const CreateBattleScreen({super.key, this.initialImage});

  @override
  ConsumerState<CreateBattleScreen> createState() => _CreateBattleScreenState();
}

class _CreateBattleScreenState extends ConsumerState<CreateBattleScreen> {
  final _captionCtrl = TextEditingController();
  Uint8List? _bytes;
  bool _creating = false;
  FitBattle? _created;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialImage;
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource src) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: src, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  Future<void> _createBattle() async {
    if (_bytes == null || _creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final engine = ref.read(fitCheckEngineProvider);
      final battles = ref.read(battleServiceProvider);

      // Score first so friends can compare to the AI number.
      final scored = await engine.score(_bytes!, persist: false);
      final battle = await battles.create(
        imageBytes: scored.normalizedBytes,
        caption: _captionCtrl.text,
        aiScore: scored.result.score,
        aiFeedback: scored.result.feedback,
      );
      if (!mounted) return;
      setState(() {
        _created = battle;
        _creating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _creating = false;
      });
    }
  }

  Future<void> _shareLink() async {
    final battle = _created!;
    final url = ref.read(battleServiceProvider).shareUrl(battle.code);
    await Share.share(
      'Rate my fit — 1 tap, no signup needed 👀\n$url',
      subject: 'GRWM fit check',
    );
  }

  void _copyLink() {
    final battle = _created!;
    final url = ref.read(battleServiceProvider).shareUrl(battle.code);
    Clipboard.setData(ClipboardData(text: url));
    context.showSnackBar('Link copied');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friend-mode')),
      body: _created != null ? _postCreateView() : _preCreateView(),
    );
  }

  Widget _preCreateView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Let your friends rate it',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Send a link. No signup needed for them. Live results roll in.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: _bytes != null
                  ? Image.memory(_bytes!, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.add_a_photo,
                          size: 48, color: AppTheme.textSecondary),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _captionCtrl,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Caption (optional)',
              hintText: 'E.g., First-date fit — honest scores only',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _bytes == null || _creating ? null : _createBattle,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.rocket_launch),
              label: Text(_creating ? 'Creating...' : 'Create battle'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _postCreateView() {
    final battle = _created!;
    final url = ref.read(battleServiceProvider).shareUrl(battle.code);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Icon(Icons.celebration, size: 64, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Battle live!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Expires in 48 hours',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Text('YOUR CODE',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Text(
                  battle.code,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(url,
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _shareLink,
              icon: const Icon(Icons.ios_share),
              label: const Text('Share link'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _copyLink,
            icon: const Icon(Icons.link),
            label: const Text('Copy link'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.go('/battle/${battle.code}'),
            child: const Text('View live results'),
          ),
        ],
      ),
    );
  }
}
