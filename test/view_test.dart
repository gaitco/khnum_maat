import 'dart:io';

import 'package:maat/maat.dart';
import 'package:maat/testing.dart';
import 'package:khnum_maat/khnum_maat.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late Application application;

  Future<void> boot({Map<String, dynamic>? view, bool debug = true}) async {
    application =
        await Application.configure(basePath: dir.path, environment: {})
            .withConfig({
              'app': {'name': 'Todo', 'debug': debug},
              'view': ?view,
            })
            .withProviders([ViewServiceProvider.new])
            .create();
  }

  void write(String relative, String contents) => File('${dir.path}/$relative')
    ..createSync(recursive: true)
    ..writeAsStringSync(contents);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('khnum_maat');
    write(
      'resources/views/hello.khnum.html',
      'Hi {{ name }} from {{ appName }}',
    );
  });

  tearDown(() {
    Application.reset();
    dir.deleteSync(recursive: true);
  });

  test(
    'view() renders a template from resources/views as escaped HTML',
    () async {
      await boot();
      Route.get('/', (Request request) => view('hello', {'name': '<b>'}));
      final response = await TestClient(application).get('/');
      response
        ..assertOk()
        ..assertHeaderContains('content-type', 'text/html')
        ..assertSee('Hi &lt;b&gt; from Todo');
    },
  );

  test('renderView() returns the string and View.share() adds data', () async {
    await boot();
    View.share('name', 'shared');
    expect(await renderView('hello'), 'Hi shared from Todo');
    expect(View.exists('hello'), isTrue);
    expect(View.exists('nope'), isFalse);
  });

  test('config("view.paths") relocates the views directory', () async {
    write('templates/other.khnum.html', 'other');
    await boot(view: {'paths': 'templates'});
    expect(await renderView('other'), 'other');
  });

  test('debug mode reloads edited templates, cache mode does not', () async {
    await boot();
    expect(await renderView('hello', {'name': 'a'}), 'Hi a from Todo');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    write('resources/views/hello.khnum.html', 'Changed {{ name }}');
    expect(await renderView('hello', {'name': 'a'}), 'Changed a');

    Application.reset();
    await boot(view: {'cache': true});
    expect(await renderView('hello', {'name': 'b'}), 'Changed b');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    write('resources/views/hello.khnum.html', 'Again {{ name }}');
    expect(await renderView('hello', {'name': 'b'}), 'Changed b');
  });

  test('a missing view is a TemplateNotFoundException with the name', () async {
    await boot();
    expect(
      () => renderView('missing'),
      throwsA(isA<TemplateNotFoundException>()),
    );
  });

  test('asset() is available to templates', () async {
    write(
      'resources/views/styled.khnum.html',
      '<link href="{{ asset(\'build/app.css\') }}">',
    );
    await boot();
    expect(await renderView('styled'), contains('href="/build/app.css"'));
  });
}
