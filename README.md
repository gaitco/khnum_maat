# Khnum for Maat

<p align="center"><img src="assets/icon.svg" width="96" alt="Khnum icon"></p>

Wires [khnum](https://github.com/gaitco/khnum) into Maat.

```dart
// bootstrap/app.dart
.withProviders([AppServiceProvider.new, ViewServiceProvider.new, ...])

// config/view.dart
final Map<String, dynamic> view = {
  'paths': 'resources/views',
  'cache': !envBool('APP_DEBUG'),
};

// a handler
Route.get('/', (Request request) => view('home', {'title': 'Home'}));
```

`view(name, data)` returns an HTML `Response`; `renderView(name, data)`
returns the string; `View.share(name, value)` adds data to every template.
