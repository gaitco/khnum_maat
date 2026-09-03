import 'package:khnum/khnum.dart';
import 'package:maat/maat.dart';

/// Binds a [Khnum] engine built from `config('view')`:
///
/// ```dart
/// final Map<String, dynamic> view = {
///   'paths': 'resources/views',              // relative to the base path
///   'components': 'resources/views/components',
///   'cache': !envBool('APP_DEBUG'),          // parse once vs reload on edit
///   'tailwind': {'version': '4.3.3', 'input': 'resources/css/app.css',
///                'output': 'public/css/app.css'},
/// };
/// ```
///
/// With no `view` config every value above is the default and `cache`
/// follows `app.debug`. `config('app.name')` is shared with every
/// template as `appName`.
class ViewServiceProvider extends ServiceProvider {
  ViewServiceProvider(super.app);

  @override
  void register() {
    this.app.singleton<Khnum>((_) => _engine());
  }

  Khnum _engine() {
    final raw = this.app.config.get('view');
    final settings = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    final paths = (settings['paths'] ?? 'resources/views') as String;
    final components = settings['components'] as String?;
    final cache = settings['cache'] as bool? ?? !this.app.debug;
    final engine = Khnum(
      viewsPath: this.app.path(paths),
      componentsPath: components == null ? null : this.app.path(components),
      environment: cache
          ? TemplateEnvironment.production
          : TemplateEnvironment.development,
    );
    engine.share('appName', this.app.config.get('app.name'));
    // Templates cannot call Dart, so the framework's own helper is
    // registered as a Khnum one: `{{ asset('css/app.css') }}`.
    engine.helper('asset', (args) => asset(args.first?.toString() ?? ''));
    return engine;
  }
}
