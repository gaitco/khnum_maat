import 'dart:io';

import 'package:maat/maat.dart';
import 'package:path/path.dart' as p;

import '../tailwind_binary.dart';

/// Runs the Tailwind binary. Injected so tests assert the argv without
/// executing an 80 MB download.
typedef TailwindProcessRunner =
    Future<int> Function(String executable, List<String> arguments);

/// Compiles the application's CSS with the Tailwind standalone CLI.
///
/// Maat's answer to `npm run dev` / `npm run build`. Deliberately separate
/// from `maat serve`: Laravel keeps `maat serve` and `npm run dev` as
/// two processes, and folding a file watcher into the dev server would tangle
/// two independent restart loops.
class TailwindCommand extends Command {
  TailwindCommand({
    String? homeDir,
    TailwindBinary Function(String version)? binaryFactory,
    TailwindProcessRunner? runProcess,
  }) : _homeDir = homeDir, // ignore: prefer_initializing_formals
       _binaryFactory = binaryFactory, // ignore: prefer_initializing_formals
       _runProcess = runProcess ?? _spawn;

  final String? _homeDir;
  final TailwindBinary Function(String version)? _binaryFactory;
  final TailwindProcessRunner _runProcess;

  @override
  String get name => 'tailwind';

  @override
  String get description => 'Compile the application CSS with Tailwind';

  @override
  String get signature => '{--watch} {--minify} {--input=} {--output=}';

  @override
  Future<int> handle() async {
    final settings = this.app.config.get('view.tailwind');
    final config = settings is Map
        ? Map<String, dynamic>.from(settings)
        : const <String, dynamic>{};

    final version =
        (config['version'] as String?) ??
        env('TAILWIND_VERSION', TailwindBinary.defaultVersion)!;
    final input =
        option('input') ??
        (config['input'] as String?) ??
        'resources/css/app.css';
    final output =
        option('output') ??
        (config['output'] as String?) ??
        'public/css/app.css';

    final source = File(this.app.path(input));
    if (!source.existsSync()) {
      error(
        'No CSS entrypoint at ${source.path}. Create it with '
        '`@import "tailwindcss";`, or pass --input=<path>.',
      );
      return 1;
    }

    final binary = (_binaryFactory ?? _defaultFactory)(version);
    if (!binary.file.existsSync()) {
      info('Downloading ${binary.asset} (Tailwind v$version) ...');
    }
    final executable = await binary.ensure();

    Directory(p.dirname(this.app.path(output))).createSync(recursive: true);

    final arguments = [
      '-i',
      source.path,
      '-o',
      this.app.path(output),
      if (flag('minify')) '--minify',
      if (flag('watch')) '--watch',
    ];
    return _runProcess(executable.path, arguments);
  }

  TailwindBinary _defaultFactory(String version) => TailwindBinary(
    version: version,
    homeDir:
        _homeDir ??
        Platform.environment['MAAT_HOME'] ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path,
  );

  static Future<int> _spawn(String executable, List<String> arguments) async {
    final process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}
