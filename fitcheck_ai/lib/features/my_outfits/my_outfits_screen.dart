import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/fit_check.dart';
import '../../services/image_service.dart';
import '../../services/streak_service.dart';
import '../../widgets/share_score_card.dart';

// ── State ────────────────────────────────────────────────

final outfitHistoryProvider =
    StateNotifierProvider<OutfitHistoryNotifier, List<_ScoredOutfit>>(
  (ref) => OutfitHistoryNotifier(),
);

class _ScoredOutfit {
  final FitCheck fitCheck;
  final Uint8List? photo;
  _ScoredOutfit({required this.fitCheck, this.photo});
}

class OutfitHistoryNotifier extends StateNotifier<List<_ScoredOutfit>> {
  OutfitHistoryNotifier() : super([]);
  void add(_ScoredOutfit o) => state = [o, ...state];
}

// ── Screen ───────────────────────────────────────────────

class MyOutfitsScreen extends ConsumerStatefulWidget {
  const MyOutfitsScreen({super.key});

  @override
  ConsumerState<MyOutfitsScreen> createState() => _MyOutfitsScreenState();
}

class _MyOutfitsScreenState extends ConsumerState<MyOutfitsScreen>
    with SingleTickerProviderStateMixin {
  Uint8List? _photo;
  FitCheck? _result;
  bool _scoring = false;
  String? _error;
  late AnimationController _scoreAnim;
  final _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scoreAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _scoreAnim.dispose();
    super.dispose();
  }

  bool get _hasApiKey {
    try {
      final key = AppConstants.openaiApiKey;
      return key.isNotEmpty && !key.contains('placeholder') && !key.contains('demo');
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickPhoto(bool fromCamera) async {
    final imgService = ref.read(imageServiceProvider);
    final bytes = fromCamera
        ? await imgService.pickFromCamera()
        : await imgService.pickFromGallery();
    if (bytes == null) return;

    setState(() {
      _photo = bytes;
      _result = null;
      _error = null;
    });
  }

  Future<void> _scoreOutfit() async {
    if (_photo == null) return;

    if (!_hasApiKey) {
      setState(() => _error =
          'Add your OPENAI_API_KEY to .env to enable AI scoring.');
      return;
    }

    setState(() {
      _scoring = true;
      _error = null;
    });

    try {
      final b64 = base64Encode(_photo!);

      final response = await http.post(
        Uri.parse(AppConstants.openaiApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.openaiApiKey}',
        },
        body: jsonEncode({
          'model': AppConstants.openaiModel,
          'max_tokens': 1024,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$b64',
                  },
                },
                {
                  'type': 'text',
                  'text': '''You are a brutally honest but supportive fashion stylist rating this outfit photo.

Analyze the outfit in this full-body photo. Consider:
- Color coordination and harmony
- Style cohesion (do the pieces work together?)
- Fit and proportions
- Occasion appropriateness (casual everyday)
- Overall vibe and confidence factor

Respond with ONLY valid JSON in this exact format:
{
  "score": <number 0-100>,
  "feedback": "<2-3 sentences of real, specific feedback about THIS outfit. Be honest — mention what works, what clashes, and one concrete suggestion. Have personality, be direct but encouraging.>",
  "color_harmony": <number 0-100>,
  "style_cohesion": <number 0-100>,
  "occasion_fit": <number 0-100>,
  "overall_fit": <number 0-100>,
  "tips": ["<specific tip 1>", "<specific tip 2>", "<specific tip 3>"]
}'''
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('API error ${response.statusCode}: ${response.body}');
      }

      final body = jsonDecode(response.body);
      final text = body['choices'][0]['message']['content'] as String;

      // Extract JSON
      String jsonStr = text;
      final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
      if (codeBlock != null) {
        jsonStr = codeBlock.group(1)!.trim();
      } else {
        final s = text.indexOf('{');
        final e = text.lastIndexOf('}');
        if (s != -1 && e != -1) jsonStr = text.substring(s, e + 1);
      }

      final r = jsonDecode(jsonStr) as Map<String, dynamic>;

      final fc = FitCheck(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'user',
        score: (r['score'] as num).toInt(),
        feedback: r['feedback'] as String,
        colorHarmonyScore: (r['color_harmony'] as num?)?.toInt(),
        styleCohesionScore: (r['style_cohesion'] as num?)?.toInt(),
        occasionScore: (r['occasion_fit'] as num?)?.toInt(),
        fitScore: (r['overall_fit'] as num?)?.toInt(),
        improvementTips: (r['tips'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        createdAt: DateTime.now(),
      );

      ref.read(outfitHistoryProvider.notifier)
          .add(_ScoredOutfit(fitCheck: fc, photo: _photo));

      // Record streak
      ref.read(streakServiceProvider.notifier).recordScore(fc.score);

      setState(() => _result = fc);
      _scoreAnim.forward(from: 0);
    } catch (e) {
      setState(() => _error = 'Scoring failed: $e');
    } finally {
      setState(() => _scoring = false);
    }
  }

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF00C853);
    if (s >= 60) return const Color(0xFFFFC107);
    return const Color(0xFFFF5252);
  }

  String _scoreLabel(int s) {
    if (s >= 90) return 'FIRE';
    if (s >= 80) return 'GREAT';
    if (s >= 70) return 'SOLID';
    if (s >= 60) return 'OK';
    return 'MEH';
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(outfitHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0b0d10),
      appBar: AppBar(
        title: const Text('My Outfits'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_result != null || _photo != null) {
              setState(() {
                _result = null;
                _photo = null;
                _error = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _result != null
          ? _buildResult()
          : _photo != null
              ? _buildPreview()
              : _buildMain(history),
    );
  }

  // ── Main: capture button + history ──

  Widget _buildMain(List<_ScoredOutfit> history) {
    final streak = ref.watch(streakServiceProvider);

    return Column(
      children: [
        // Streak banner
        if (streak.currentStreak > 0 || streak.scoredToday)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: streak.scoredToday
                    ? [const Color(0xFF00C853), const Color(0xFF00E676)]
                    : [AppTheme.primary, const Color(0xFF8B7CF7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(streak.scoredToday ? '✅' : '🔥',
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streak.scoredToday
                            ? 'Done for today! ${streak.currentStreak} day streak'
                            : '${streak.currentStreak} day streak — score a fit to keep it!',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      if (streak.avgScore > 0)
                        Text('Avg: ${streak.avgScore.toStringAsFixed(0)} • Target: ${streak.dailyTarget}+',
                            style: const TextStyle(color: Colors.white70,
                                fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Capture area
        GestureDetector(
          onTap: () => _showPickerSheet(),
          child: Container(
            margin: const EdgeInsets.all(20),
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 40, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 12),
                  const Text('Take a Full Body Pic',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                          color: AppTheme.primary)),
                  const SizedBox(height: 4),
                  const Text('Get your fit scored by AI',
                      style: TextStyle(fontSize: 13, color: Colors.white38)),
                ],
              ),
            ),
          ),
        ),

        // History header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text('History',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const Spacer(),
              Text('${history.length} fits',
                  style: const TextStyle(fontSize: 14, color: Colors.white38)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // History list
        Expanded(
          child: history.isEmpty
              ? const Center(
                  child: Text('No outfits scored yet.\nTake your first pic!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 15)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: history.length,
                  itemBuilder: (ctx, i) => _HistoryTile(entry: history[i]),
                ),
        ),
      ],
    );
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1d24),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Your Outfit Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
                title: const Text('Take a Photo',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.primary),
                title: const Text('Choose from Gallery',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Photo preview before scoring ──

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(_photo!, fit: BoxFit.cover,
                  width: double.infinity),
            ),
          ),
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error!,
                style: const TextStyle(color: Color(0xFFFF5252), fontSize: 13),
                textAlign: TextAlign.center),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scoring ? null : () => setState(() {
                    _photo = null;
                    _error = null;
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _scoring ? null : _scoreOutfit,
                  icon: _scoring
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_scoring ? 'Scoring...' : 'Score My Fit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Score result ──

  Widget _buildResult() {
    final fc = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Photo thumbnail
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_photo!, height: 200,
                  width: 150, fit: BoxFit.cover),
            ),
          const SizedBox(height: 20),

          // Animated score
          AnimatedBuilder(
            animation: _scoreAnim,
            builder: (ctx, _) {
              final animScore = (_scoreAnim.value * fc.score).toInt();
              return Column(
                children: [
                  Text('$animScore',
                      style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900,
                          color: _scoreColor(fc.score))),
                  Text(_scoreLabel(fc.score),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                          color: _scoreColor(fc.score), letterSpacing: 1.5)),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // AI Feedback
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1d24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    const Text('AI Stylist',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: Colors.white54, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(fc.feedback,
                    style: const TextStyle(fontSize: 15, height: 1.6,
                        color: Colors.white)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Sub-scores
          _SubScoreRow(label: 'Color Harmony', value: fc.colorHarmonyScore ?? 0),
          _SubScoreRow(label: 'Style Cohesion', value: fc.styleCohesionScore ?? 0),
          _SubScoreRow(label: 'Occasion Fit', value: fc.occasionScore ?? 0),
          _SubScoreRow(label: 'Overall Fit', value: fc.fitScore ?? 0),

          const SizedBox(height: 16),

          // Tips
          if (fc.improvementTips != null && fc.improvementTips!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1d24),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Style Tips',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 8),
                  ...fc.improvementTips!.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              size: 18, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t,
                              style: const TextStyle(fontSize: 14,
                                  color: Colors.white70))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Share card (hidden, used for capture)
          Offstage(
            offstage: true,
            child: ShareScoreCard(
              fitCheck: fc,
              photo: _photo,
              repaintKey: _shareCardKey,
            ),
          ),

          // Share + Score Another buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final bytes = await ShareScoreCard.capture(_shareCardKey);
                    if (bytes != null) {
                      await Share.shareXFiles(
                        [XFile.fromData(bytes, mimeType: 'image/png',
                            name: 'grwm_score.png')],
                        text: 'My fit scored ${fc.score}! 🔥 #GRWM',
                      );
                    }
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _result = null;
                    _photo = null;
                  }),
                  child: const Text('Score Another Fit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── History tile ──

class _HistoryTile extends StatelessWidget {
  final _ScoredOutfit entry;
  const _HistoryTile({required this.entry});

  Color _color(int s) {
    if (s >= 80) return const Color(0xFF00C853);
    if (s >= 60) return const Color(0xFFFFC107);
    return const Color(0xFFFF5252);
  }

  @override
  Widget build(BuildContext context) {
    final fc = entry.fitCheck;
    final ago = DateTime.now().difference(fc.createdAt);
    String when;
    if (ago.inMinutes < 5) {
      when = 'Just now';
    } else if (ago.inDays == 0) {
      when = 'Today';
    } else if (ago.inDays == 1) {
      when = 'Yesterday';
    } else {
      when = '${ago.inDays}d ago';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1d24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Photo thumbnail
          if (entry.photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(entry.photo!, width: 52, height: 68,
                  fit: BoxFit.cover),
            )
          else
            Container(
              width: 52, height: 68,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.checkroom, color: Colors.white24),
            ),
          const SizedBox(width: 12),

          // Score badge
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _color(fc.score).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('${fc.score}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                      color: _color(fc.score))),
            ),
          ),
          const SizedBox(width: 12),

          // Feedback preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fc.feedback, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w500, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(when,
                    style: const TextStyle(fontSize: 11, color: Colors.white30)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-score bar ──

class _SubScoreRow extends StatelessWidget {
  final String label;
  final int value;
  const _SubScoreRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 80
        ? const Color(0xFF00C853)
        : value >= 60
            ? const Color(0xFFFFC107)
            : const Color(0xFFFF5252);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3,
              child: Text(label, style: const TextStyle(fontSize: 14,
                  color: Colors.white70))),
          Expanded(flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 100,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 32,
            child: Text('$value', textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w700, color: color))),
        ],
      ),
    );
  }
}
