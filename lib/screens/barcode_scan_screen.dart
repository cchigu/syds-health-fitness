import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/food.dart';
import '../models/meal.dart';
import '../services/barcode_lookup_service.dart';
import 'custom_food_screen.dart';
import 'food_detail_screen.dart';
import 'food_search_screen.dart';

/// Point the camera at a barcode; the food opens ready to log.
/// Pops with true when something was added.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key, required this.meal, required this.day});

  final Meal meal;
  final DateTime day;

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final MobileScannerController _camera = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _busy = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final b in capture.barcodes) {
      final code = b.rawValue;
      if (code != null && code.isNotEmpty) {
        _handle(code);
        return;
      }
    }
  }

  Future<void> _typeBarcode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Type the barcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'The numbers under the bars',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Look up'),
          ),
        ],
      ),
    );
    if (code != null && code.trim().isNotEmpty) _handle(code.trim());
  }

  Future<void> _handle(String code) async {
    setState(() => _busy = true);
    await _camera.stop();

    FoodItem? food;
    var offline = false;
    try {
      food = await BarcodeLookupService.lookup(code);
    } on BarcodeLookupException {
      offline = true;
    }
    if (!mounted) return;

    bool? added;
    if (food != null) {
      added = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => FoodDetailScreen.add(
          food: food!,
          meal: widget.meal,
          day: widget.day,
        ),
      ));
    } else {
      added = await _notFound(code, offline: offline);
    }
    if (!mounted) return;
    if (added == true) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = false);
    await _camera.start();
  }

  /// Shown when a barcode isn't in any database (or there's no internet).
  Future<bool?> _notFound(String code, {required bool offline}) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  offline ? 'No internet connection' : 'Barcode not found',
                  style: text.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  offline
                      ? 'Couldn\'t reach the food databases. Check your '
                          'connection and try again.'
                      : '$code isn\'t in the USDA or Open Food Facts '
                          'databases yet. Add it from the label once and '
                          'it\'ll be found instantly next time.',
                ),
                const SizedBox(height: 20),
                if (!offline)
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'create'),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Add it from the label'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'search'),
                  icon: const Icon(Icons.search),
                  label: const Text('Search by name instead'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'retry'),
                  child: const Text('Scan again'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return null;

    switch (choice) {
      case 'create':
        return Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => CustomFoodScreen(
            barcode: code,
            meal: widget.meal,
            day: widget.day,
          ),
        ));
      case 'search':
        return Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) =>
              FoodSearchScreen(meal: widget.meal, day: widget.day),
        ));
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Flashlight',
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _camera.toggleTorch();
              if (mounted) setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _camera, onDetect: _onDetect),

          // Aiming frame
          Center(
            child: Container(
              width: 280,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(color: colors.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          if (_busy)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Looking it up…',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),

          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Line up the barcode inside the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _typeBarcode,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Type the numbers instead'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
