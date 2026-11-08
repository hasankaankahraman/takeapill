import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeapill/core/ads.dart';

void main() {
  test('debug yalnızca Google test birimlerini kullanır', () {
    for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
      expect(bannerAdUnit(p, debug: true), contains('3940256099942544'));
    }
  });

  test('release birimi boşsa reklam yok, doluysa test birimi değil', () {
    for (final (p, unit) in [
      (TargetPlatform.android, androidBannerUnit),
      (TargetPlatform.iOS, iosBannerUnit),
    ]) {
      expect(bannerAdUnit(p, debug: false), unit.isEmpty ? isNull : unit);
      expect(unit, isNot(contains('3940256099942544')));
    }
  });

  test('desteklenmeyen platformda reklam yok', () {
    expect(bannerAdUnit(TargetPlatform.macOS, debug: true), isNull);
  });

  test('reklamlar kişiselleştirilmez', () {
    expect(adRequest.nonPersonalizedAds, isTrue);
    expect(adRequest.keywords, isNull);
    expect(adRequest.contentUrl, isNull);
  });

  test('gerçek birimle test App ID yayımlanamaz', () {
    const testAppId = 'ca-app-pub-3940256099942544~';
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final plist = File('ios/Runner/Info.plist');
    if (androidBannerUnit.isNotEmpty) {
      expect(manifest.readAsStringSync(), isNot(contains(testAppId)));
    }
    if (iosBannerUnit.isNotEmpty) {
      expect(plist.readAsStringSync(), isNot(contains(testAppId)));
    }
  });
}
