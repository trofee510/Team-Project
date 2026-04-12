import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../models/wardrobe_item.dart';
import '../widgets/outfit_share_card.dart';

final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService();
});

class ShareService {
  /// Generates a share card image from widget and shares it
  Future<void> shareOutfitCard({
    required String occasion,
    required List<WardrobeItem> items,
    int? fitCheckScore,
    bool isPro = false,
  }) async {
    // Create the widget to render
    final widget = OutfitShareCard(
      occasion: occasion,
      items: items,
      fitCheckScore: fitCheckScore,
      showWatermark: !isPro,
    );

    // Render widget to image bytes
    final bytes = await _renderWidgetToImage(widget, width: 390);
    if (bytes == null) return;

    // Save to temp file and share
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/grwm_outfit_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'My outfit styled by GRWM',
    );
  }

  Future<Uint8List?> _renderWidgetToImage(Widget widget, {required double width}) async {
    final repaintBoundary = RenderRepaintBoundary();

    final renderView = RenderView(
      view: ui.PlatformDispatcher.instance.implicitView!,
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: repaintBoundary,
      ),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints(maxWidth: width, maxHeight: 800),
        devicePixelRatio: 3.0,
      ),
    );

    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(child: widget),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final image = await repaintBoundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }
}
