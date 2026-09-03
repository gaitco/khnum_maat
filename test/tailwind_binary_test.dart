import 'dart:ffi';
import 'dart:io';

import 'package:maat_khnum/maat_khnum.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory home;

  TailwindBinary binary({required Abi abi, bool musl = false}) =>
      TailwindBinary(
        homeDir: home.path,
        abi: abi,
        musl: musl,
        download: (url, target) async =>
            target.writeAsStringSync('#!/bin/sh\necho stub'),
      );

  setUp(() => home = Directory.systemTemp.createTempSync('maat_home'));
  tearDown(() => home.deleteSync(recursive: true));

  test('maps each supported platform to its release asset', () {
    expect(binary(abi: Abi.macosArm64).asset, 'tailwindcss-macos-arm64');
    expect(binary(abi: Abi.macosX64).asset, 'tailwindcss-macos-x64');
    expect(binary(abi: Abi.linuxX64).asset, 'tailwindcss-linux-x64');
    expect(binary(abi: Abi.linuxArm64).asset, 'tailwindcss-linux-arm64');
    expect(binary(abi: Abi.windowsX64).asset, 'tailwindcss-windows-x64.exe');
  });

  test('selects the musl build on musl libc', () {
    expect(
      binary(abi: Abi.linuxX64, musl: true).asset,
      'tailwindcss-linux-x64-musl',
    );
    expect(
      binary(abi: Abi.linuxArm64, musl: true).asset,
      'tailwindcss-linux-arm64-musl',
    );
  });

  test('musl does not affect macOS or Windows assets', () {
    expect(
      binary(abi: Abi.macosArm64, musl: true).asset,
      'tailwindcss-macos-arm64',
    );
    expect(
      binary(abi: Abi.windowsX64, musl: true).asset,
      'tailwindcss-windows-x64.exe',
    );
  });

  test('an unsupported platform fails with a message naming the fix', () {
    expect(
      () => binary(abi: Abi.linuxIA32).asset,
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          allOf(contains('linuxIA32'), contains('.maat')),
        ),
      ),
    );
  });

  test('the download URL pins the version', () {
    expect(
      binary(abi: Abi.macosArm64).url.toString(),
      'https://github.com/tailwindlabs/tailwindcss/releases/download/'
      'v${TailwindBinary.defaultVersion}/tailwindcss-macos-arm64',
    );
  });

  test('the cache path is per machine and per version', () {
    expect(
      binary(abi: Abi.macosArm64).file.path,
      p.join(
        home.path,
        '.maat',
        'bin',
        'tailwindcss-${TailwindBinary.defaultVersion}-tailwindcss-macos-arm64',
      ),
    );
  });

  test('ensure() downloads once and reuses the cached binary', () async {
    var downloads = 0;
    TailwindBinary counting() => TailwindBinary(
      homeDir: home.path,
      abi: Abi.macosArm64,
      musl: false,
      download: (url, target) async {
        downloads++;
        target.writeAsStringSync('stub');
      },
    );
    await counting().ensure();
    await counting().ensure();
    expect(downloads, 1);
    expect(counting().file.existsSync(), isTrue);
  });

  test('a failed download leaves no file at the cache path', () async {
    TailwindBinary failing() => TailwindBinary(
      homeDir: home.path,
      abi: Abi.macosArm64,
      musl: false,
      download: (url, target) async {
        target.writeAsStringSync('partial');
        throw Exception('Network dropped');
      },
    );
    final failingBinary = failing();
    try {
      await failingBinary.ensure();
      fail('Expected ensure() to throw');
    } on Exception {
      // Expected
    }
    expect(failingBinary.file.existsSync(), isFalse);
    // Subsequent ensure() with a working downloader succeeds
    TailwindBinary working() => TailwindBinary(
      homeDir: home.path,
      abi: Abi.macosArm64,
      musl: false,
      download: (url, target) async => target.writeAsStringSync('valid'),
    );
    await working().ensure();
    expect(working().file.existsSync(), isTrue);
    expect(working().file.readAsStringSync(), 'valid');
  });

  test(
    'a failed chmod leaves no file at the cache path',
    () async {
      TailwindBinary binaryWith({required BinaryChmod chmod}) => TailwindBinary(
        homeDir: home.path,
        abi: Abi.macosArm64,
        musl: false,
        download: (url, target) async => target.writeAsStringSync('stub'),
        chmod: chmod,
      );

      final failing = binaryWith(chmod: (path) async => 1);
      await expectLater(failing.ensure(), throwsA(isA<StateError>()));
      expect(failing.file.existsSync(), isFalse);
      // No stray temp file left behind either.
      expect(home.listSync(recursive: true).whereType<File>(), isEmpty);

      // A subsequent ensure() with a working chmod still succeeds.
      final working = binaryWith(chmod: (path) async => 0);
      await working.ensure();
      expect(working.file.existsSync(), isTrue);
    },
    skip: Platform.isWindows ? 'chmod is not run on Windows' : false,
  );
}
