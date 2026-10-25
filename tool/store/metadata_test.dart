// Mağaza metinlerinin (store/*/metadata) konsol sınırlarına uyduğunu denetler:
//
//   flutter test tool/store/metadata_test.dart
//
// Klasör yapısı fastlane deliver/supply ile uyumludur.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _ios = 'store/app-store/metadata/tr';
const _play = 'store/google-play/metadata/tr-TR';

String _read(String path) => File(path).readAsStringSync().trim();

/// Türkçe büyük/küçük harf: Dart'ın toLowerCase'i "İ"yi "i̇" yapar.
String _lower(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

Set<String> _words(String s) =>
    _lower(s)
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.isNotEmpty)
        .toSet();

void main() {
  test('App Store sınırları', () {
    final name = _read('$_ios/name.txt');
    final subtitle = _read('$_ios/subtitle.txt');
    final keywords = _read('$_ios/keywords.txt');

    expect(name.length, lessThanOrEqualTo(30));
    expect(subtitle.length, lessThanOrEqualTo(30));
    // Anahtar kelime sınırı bayt cinsinden; Türkçe harfler 2 bayt.
    expect(utf8.encode(keywords).length, lessThanOrEqualTo(100));
    expect(_read('$_ios/promotional_text.txt').length, lessThanOrEqualTo(170));
    expect(_read('$_ios/description.txt').length, lessThanOrEqualTo(4000));

    final list = keywords.split(',');
    expect(list.where((k) => k.trim() != k || k.isEmpty), isEmpty);
    expect(list.toSet().length, list.length, reason: 'tekrarlanan kelime');
    // Ad ve alt başlıktaki kelimeler zaten aranır; burada yer harcamasın.
    final shown = _words('$name $subtitle');
    expect(list.map(_lower).where(shown.contains), isEmpty);
  });

  test('Google Play sınırları', () {
    expect(_read('$_play/title.txt').length, lessThanOrEqualTo(30));
    expect(_read('$_play/short_description.txt').length, lessThanOrEqualTo(80));
    expect(
      _read('$_play/full_description.txt').length,
      lessThanOrEqualTo(4000),
    );
    for (final f in Directory(
      '$_play/changelogs',
    ).listSync().whereType<File>()) {
      expect(_read(f.path).length, lessThanOrEqualTo(500), reason: f.path);
    }
  });
}
