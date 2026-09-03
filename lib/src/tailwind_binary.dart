import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:path/path.dart' as p;

/// Fetches [url] into [target]. Injected so tests never touch the network.
typedef BinaryDownloader = Future<void> Function(Uri url, File target);

/// Marks [path] executable, returning the process exit code. Injected so
/// tests can simulate a chmod failure without a real broken filesystem.
typedef BinaryChmod = Future<int> Function(String path);

/// Locates — downloading once if needed — the Tailwind CSS standalone CLI.
///
/// Laravel compiles CSS through npm and Vite. Dart has no equivalent, and a
/// Dart backend should not require a JavaScript toolchain, so Maat drives
/// Tailwind's self-contained binary instead. It is ~80 MB, so it is cached per
/// machine rather than per project.
class TailwindBinary {
  TailwindBinary({
    this.version = defaultVersion,
    required this.homeDir,
    Abi? abi,
    bool? musl,
    BinaryDownloader? download,
    BinaryChmod? chmod,
  }) : abi = abi ?? Abi.current(),
       musl = musl ?? _detectMusl(),
       _download = download ?? _fetch,
       _chmod = chmod ?? _chmodPlusX;

  /// Pinned Tailwind release. Override with `config('view.tailwind.version')`
  /// or `TAILWIND_VERSION`.
  static const String defaultVersion = '4.3.3';

  final String version;
  final String homeDir;
  final Abi abi;
  final bool musl;
  final BinaryDownloader _download;
  final BinaryChmod _chmod;

  static bool _detectMusl() => File('/etc/alpine-release').existsSync();

  static String _abiName(Abi abi) {
    return switch (abi) {
      Abi.macosArm64 => 'macosArm64',
      Abi.macosX64 => 'macosX64',
      Abi.linuxX64 => 'linuxX64',
      Abi.linuxArm64 => 'linuxArm64',
      Abi.windowsX64 => 'windowsX64',
      Abi.linuxIA32 => 'linuxIA32',
      _ => abi.toString(),
    };
  }

  /// The GitHub release asset for this platform.
  String get asset {
    final base = switch (abi) {
      Abi.macosArm64 => 'tailwindcss-macos-arm64',
      Abi.macosX64 => 'tailwindcss-macos-x64',
      Abi.linuxX64 => 'tailwindcss-linux-x64',
      Abi.linuxArm64 => 'tailwindcss-linux-arm64',
      Abi.windowsX64 => 'tailwindcss-windows-x64.exe',
      _ => throw UnsupportedError(
        'Tailwind ships no standalone binary for ${_abiName(abi)}. Download one manually '
        'to ${p.join(homeDir, '.maat', 'bin')} named '
        'tailwindcss-$version-<asset>, or set a different platform.',
      ),
    };
    return musl && base.startsWith('tailwindcss-linux') ? '$base-musl' : base;
  }

  Uri get url => Uri.parse(
    'https://github.com/tailwindlabs/tailwindcss/releases/download/'
    'v$version/$asset',
  );

  /// Cached per machine and per version, so `maat new` does not re-download
  /// 80 MB for every project.
  File get file =>
      File(p.join(homeDir, '.maat', 'bin', 'tailwindcss-$version-$asset'));

  /// The cached binary, downloading and marking it executable on first use.
  ///
  /// The temp file is chmod'd *before* it is renamed onto [file]'s path, so
  /// that path only ever receives a fully-prepared executable — a chmod
  /// failure leaves nothing at the cache path rather than a permanently
  /// non-executable file that every later `ensure()` mistakes for done.
  Future<File> ensure() async {
    final target = file;
    if (target.existsSync()) return target;
    target.parent.createSync(recursive: true);
    // pid-suffixed so two concurrent `maat tailwind` runs don't share —
    // and clobber each other's — download.
    final temp = File('${target.path}.$pid.tmp');
    try {
      await _download(url, temp);
      if (!Platform.isWindows) {
        final exitCode = await _chmod(temp.path);
        if (exitCode != 0) {
          throw StateError(
            'Failed to mark the downloaded Tailwind binary executable '
            '(chmod exit code $exitCode). Check permissions on '
            '${target.parent.path} and try again.',
          );
        }
      }
      temp.renameSync(target.path);
    } catch (e) {
      if (temp.existsSync()) temp.deleteSync();
      rethrow;
    }
    return target;
  }

  static Future<int> _chmodPlusX(String path) async {
    final result = await Process.run('chmod', ['+x', path]);
    return result.exitCode;
  }

  static Future<void> _fetch(Uri requestUrl, File target) async {
    final client = HttpClient();
    try {
      var currentUrl = requestUrl;
      var request = await client.getUrl(currentUrl);
      var response = await request.close();
      // GitHub redirects release downloads to a CDN.
      var hops = 0;
      while (response.isRedirect && hops++ < 5) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) break;
        await response.drain<void>();
        currentUrl = currentUrl.resolve(location);
        request = await client.getUrl(currentUrl);
        response = await request.close();
      }
      if (response.statusCode != 200) {
        throw StateError(
          'Downloading $requestUrl failed with HTTP ${response.statusCode}. Check the '
          'Tailwind version in config/view.dart, or download the binary '
          'manually to ${target.path}.',
        );
      }
      await response.pipe(target.openWrite());
    } finally {
      client.close(force: true);
    }
  }
}
