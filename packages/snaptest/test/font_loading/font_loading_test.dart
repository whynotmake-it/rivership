import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  testWidgets('first load aliases SDK fonts and supports Cupertino overrides', (
    tester,
  ) async {
    await loadFonts(
      fontAliases: {
        'BrandText': 'Roboto',
        'AnotherBrandText': 'Roboto',
      },
      cupertinoFonts: const CupertinoFontConfig.override(
        fontFamily: 'BrandText',
      ),
    );
    for (final family in [
      'BrandText',
      'AnotherBrandText',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
    ]) {
      for (final weight in [FontWeight.w400, FontWeight.w700]) {
        expect(_metrics(family, weight), _metrics('Roboto', weight));
      }
    }
    expect(
      _metrics('BrandText', FontWeight.w400),
      isNot(_metrics('Ahem', FontWeight.w400)),
    );
  });

  testWidgets('later calls can add aliases and repeat existing ones', (
    tester,
  ) async {
    await loadFonts(fontAliases: {'LaterBrandText': 'Roboto'});
    await loadFonts(
      fontAliases: {'BrandText': 'Roboto', 'LaterBrandText': 'Roboto'},
    );
    expect(
      _metrics('LaterBrandText', FontWeight.w700),
      _metrics('Roboto', FontWeight.w700),
    );
  });

  testWidgets('package-qualified font assets can be aliased', (tester) async {
    await loadFonts(
      fontAliases: {
        'PackageAlias': 'packages/fixture/PackageFont',
      },
    );
    expect(
      _metrics('PackageAlias', FontWeight.w400),
      _metrics('packages/fixture/PackageFont', FontWeight.w400),
    );
    expect(
      _metrics('PackageAlias', FontWeight.w400),
      isNot(_metrics('Ahem', FontWeight.w400)),
    );
  });

  testWidgets(
    'unknown sources and blank aliases fail rather than falling back',
    (
      tester,
    ) async {
      for (final aliases in [
        {'MissingFont': 'not-a-loaded-family'},
        {'': 'Roboto'},
        {'  ': 'Roboto'},
      ]) {
        await expectLater(loadFonts(fontAliases: aliases), throwsArgumentError);
      }
      await loadFonts(fontAliases: {'AfterError': 'Roboto'});
      expect(
        _metrics('AfterError', FontWeight.w400),
        _metrics('Roboto', FontWeight.w400),
      );
    },
  );

  testWidgets('aliases and real families cannot be replaced', (tester) async {
    await expectLater(
      loadFonts(fontAliases: {'BrandText': 'MaterialIcons'}),
      throwsStateError,
    );
    await expectLater(
      loadFonts(fontAliases: {'Roboto': 'MaterialIcons'}),
      throwsStateError,
    );
    await loadFonts(fontAliases: {'Roboto': 'Roboto'});
    expect(
      _metrics('BrandText', FontWeight.w400),
      _metrics('Roboto', FontWeight.w400),
    );
  });

  testWidgets('validate every mapping before registering any alias', (
    tester,
  ) async {
    await expectLater(
      loadFonts(
        fontAliases: {
          'NotPartiallyLoaded': 'Roboto',
          'InvalidAlias': 'missing-font',
        },
      ),
      throwsArgumentError,
    );
    await loadFonts(fontAliases: {'NotPartiallyLoaded': 'MaterialIcons'});
  });

  testWidgets('concurrent requests cannot race alias replacement', (
    tester,
  ) async {
    final first = loadFonts(fontAliases: {'ConcurrentAlias': 'Roboto'});
    final second = loadFonts(fontAliases: {'ConcurrentAlias': 'MaterialIcons'});
    final results = await Future.wait(
      [
        first,
        second,
      ].map((f) => f.then<Object?>((_) => null, onError: (Object e) => e)),
    );
    expect(results.whereType<StateError>(), hasLength(1));
    expect(results.where((e) => e == null), hasLength(1));
    expect(
      _metrics('ConcurrentAlias', FontWeight.w400),
      _metrics(
        results[0] == null ? 'Roboto' : 'MaterialIcons',
        FontWeight.w400,
      ),
    );
  });
}

Size _metrics(
  String family,
  FontWeight weight, {
  String text = 'Wi iii WW 123',
}) {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: family, fontWeight: weight, fontSize: 32),
    ),
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}
