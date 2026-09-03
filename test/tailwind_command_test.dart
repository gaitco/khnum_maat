import 'dart:ffi';
import 'dart:io';

import 'package:maat/maat.dart';
import 'package:maat_khnum/maat_khnum.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late Directory home;
  late List<String> captured;
  late StringBuffer out;

  Future<int> run(List<String> args, {Map<String, dynamic>? tailwind}) async {
    final application =
        await Application.configure(
          basePath: dir.path,
          environment: {},
        ).withConfig({
          'app': {'name': 'Test', 'debug': true},
          'view': {'tailwind': ?tailwind},
        }).create();
    final command =
        TailwindCommand(
            homeDir: home.path,
            binaryFactory: (version) => TailwindBinary(
              version: version,
              homeDir: home.path,
              abi: Abi.macosArm64,
              musl: false,
              download: (url, target) async => target.writeAsStringSync('stub'),
            ),
            runProcess: (executable, arguments) async {
              captured = [executable, ...arguments];
              return 0;
            },
          )
          ..app = application
          ..out = out
          ..err = out;
    command.bind(args);
    return command.handle();
  }

  void writeEntrypoint([String relative = 'resources/css/app.css']) =>
      File('${dir.path}/$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync('@import "tailwindcss";');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('maat_tw');
    home = Directory.systemTemp.createTempSync('maat_home');
    captured = [];
    out = StringBuffer();
  });
  tearDown(() {
    dir.deleteSync(recursive: true);
    home.deleteSync(recursive: true);
  });

  test('uses the documented defaults', () async {
    writeEntrypoint();
    expect(await run([]), 0);
    expect(captured.sublist(1), [
      '-i',
      '${dir.path}/resources/css/app.css',
      '-o',
      '${dir.path}/public/css/app.css',
    ]);
  });

  test('forwards --watch and --minify', () async {
    writeEntrypoint();
    await run(['--watch', '--minify']);
    expect(captured, contains('--watch'));
    expect(captured, contains('--minify'));
  });

  test('omits the flags when they are not passed', () async {
    writeEntrypoint();
    await run([]);
    expect(captured, isNot(contains('--watch')));
    expect(captured, isNot(contains('--minify')));
  });

  test('--input and --output override the defaults', () async {
    writeEntrypoint('src/in.css');
    await run(['--input=src/in.css', '--output=dist/out.css']);
    expect(captured, contains('${dir.path}/src/in.css'));
    expect(captured, contains('${dir.path}/dist/out.css'));
  });

  test('config/view.dart overrides the defaults', () async {
    writeEntrypoint('a.css');
    await run([], tailwind: {'input': 'a.css', 'output': 'b.css'});
    expect(captured, contains('${dir.path}/a.css'));
    expect(captured, contains('${dir.path}/b.css'));
  });

  test('runs the cached binary for this platform', () async {
    writeEntrypoint();
    await run([]);
    expect(
      captured.first,
      endsWith(
        'tailwindcss-${TailwindBinary.defaultVersion}-tailwindcss-macos-arm64',
      ),
    );
  });

  test('returns the exit code of the Tailwind process', () async {
    writeEntrypoint();
    final application =
        await Application.configure(
          basePath: dir.path,
          environment: {},
        ).withConfig({
          'app': {'name': 'Test', 'debug': true},
        }).create();
    final command =
        TailwindCommand(
            homeDir: home.path,
            binaryFactory: (version) => TailwindBinary(
              version: version,
              homeDir: home.path,
              abi: Abi.macosArm64,
              musl: false,
              download: (url, target) async => target.writeAsStringSync('stub'),
            ),
            runProcess: (executable, arguments) async => 2,
          )
          ..app = application
          ..out = out
          ..err = out;
    command.bind([]);
    expect(await command.handle(), 2);
  });

  test('a missing CSS entrypoint fails without running Tailwind', () async {
    expect(await run([]), 1);
    expect(captured, isEmpty);
    expect(out.toString(), contains('No CSS entrypoint'));
  });

  test('viewCommands() registers the tailwind command', () {
    expect(viewCommands().map((c) => c.name), contains('tailwind'));
  });
}
