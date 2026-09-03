import 'package:maat_khnum_core/maat_khnum_core.dart';
import 'package:maat/maat.dart';

Khnum get _engine => app<Khnum>();

/// Renders [name] (`'tasks.index'` → `resources/views/tasks/index.khnum.html`)
/// with [data] and returns the HTML.
Future<String> renderView(
  String name, [
  Map<String, Object?> data = const {},
]) => _engine.render(name, data);

/// Laravel's `view()` helper: an HTML response for the rendered template.
/// For another status wrap [renderView] yourself:
/// `Response.html(await renderView('form', data), status: 422)`.
Future<Response> view(
  String name, [
  Map<String, Object?> data = const {},
]) async => Response.html(await renderView(name, data));

/// Static conveniences over the bound engine, the `View` facade.
abstract final class View {
  /// Make [value] visible to every template as [name].
  static void share(String name, Object? value) => _engine.share(name, value);

  static bool exists(String name) => _engine.exists(name);

  static Khnum get engine => _engine;
}
