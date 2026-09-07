// test/taxonomy_asset_parity_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app bundles `assets/taxonomy/taxonomy.json` so the Personalization
/// screen and the "Not interested" mute sheet speak the same subcategory
/// vocabulary as the backend. It MUST stay byte-identical to the canonical
/// source at `taxonomy/taxonomy.json` — this guard fails the build if they
/// drift (regenerate with `cp taxonomy/taxonomy.json assets/taxonomy/`).
void main() {
  test('bundled taxonomy asset matches the canonical taxonomy/taxonomy.json',
      () {
    final source = File('taxonomy/taxonomy.json');
    final asset = File('assets/taxonomy/taxonomy.json');

    expect(source.existsSync(), isTrue,
        reason: 'taxonomy/taxonomy.json missing');
    expect(asset.existsSync(), isTrue,
        reason: 'assets/taxonomy/taxonomy.json missing — copy it from source');

    expect(asset.readAsBytesSync(), equals(source.readAsBytesSync()),
        reason: 'assets/taxonomy/taxonomy.json is stale — '
            'run: cp taxonomy/taxonomy.json assets/taxonomy/taxonomy.json');
  });
}
