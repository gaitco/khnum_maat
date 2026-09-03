import 'dart:io';

import 'package:khnum_maat/khnum_maat.dart';
import 'package:maat/maat.dart';

Future<void> main() async {
  final root = Directory.systemTemp.createTempSync('khnum_maat_example');
  File('${root.path}/resources/views/welcome.khnum.html')
    ..createSync(recursive: true)
    ..writeAsStringSync('Welcome, {{ name }}!');

  try {
    await Application.configure(basePath: root.path, environment: {})
        .withConfig({
          'app': {'name': 'Maat', 'debug': true},
          'view': {'paths': 'resources/views'},
        })
        .withProviders([ViewServiceProvider.new])
        .create();

    print(await renderView('welcome', {'name': 'Ada'}));
  } finally {
    Application.reset();
    root.deleteSync(recursive: true);
  }
}
