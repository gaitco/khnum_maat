import 'package:maat/maat.dart';

import 'tailwind_command.dart';

/// The view layer's maat commands. Register the result in
/// `lib/app/console/kernel.dart`, alongside `databaseCommands(...)`.
List<Command> viewCommands() => [TailwindCommand()];
