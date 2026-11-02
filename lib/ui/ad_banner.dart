import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ads.dart';
import '../core/notifications/notification_service.dart';
import 'providers.dart';
import 'theme.dart';

/// Alt menünün üstündeki banner. Reklam yokken (kapalı, çevrimdışı, kilitli)
/// yer kaplamaz.
class AdBanner extends ConsumerWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(adsEnabledProvider) ? const _Banner() : const SizedBox.shrink();
}

class _Banner extends StatefulWidget {
  const _Banner();

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  late final AppLifecycleListener _lifecycle;
  BannerAd? _ad;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ad?.dispose();
    super.dispose();
  }

  /// Alarm uygulamayı kilit ekranının üstünde açabilir; orada reklam
  /// gösterilemez (Play politikası). Kilit açılınca sonraki öne gelişte döner.
  Future<void> _refresh() async {
    final locked = await NotificationService.deviceLocked();
    if (!mounted) return;
    if (locked) {
      final ad = _ad;
      if (ad != null) {
        setState(() => _ad = null);
        await ad.dispose();
      }
    } else if (_ad == null && !_loading) {
      // Çevrimdışıyken başarısız olan istek öne gelişte yeniden denenir.
      await _load();
    }
  }

  Future<void> _load() async {
    final unit = bannerAdUnit(defaultTargetPlatform);
    if (unit == null) return;
    _loading = true;
    try {
      if (!await gatherAdConsent() || !mounted) {
        _loading = false;
        return;
      }
      await BannerAd(
        adUnitId: unit,
        request: adRequest,
        // Standart 320×50: uyarlanabilir "large" boyut 126 pt ile doz listesini
        // fazla kapatıyor.
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _loading = false;
            if (mounted) {
              setState(() => _ad = ad as BannerAd);
            } else {
              ad.dispose();
            }
          },
          onAdFailedToLoad: (ad, e) {
            _loading = false;
            debugPrint('Reklam yüklenemedi: ${e.message}');
            ad.dispose();
          },
        ),
      ).load();
    } catch (e) {
      _loading = false;
      debugPrint('Reklam yüklenemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return ColoredBox(
      color: context.c.bg,
      // Menüye yanlışlıkla dokunup reklama basılmasın.
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Center(
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
