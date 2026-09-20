import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// What a widget tap is asking the app to do, decoded from its launch URI.
sealed class WidgetLaunchAction {
  const WidgetLaunchAction();
}

class OpenToday extends WidgetLaunchAction {
  const OpenToday();
}

class OpenNewAppointment extends WidgetLaunchAction {
  const OpenNewAppointment();
}

class OpenAppointment extends WidgetLaunchAction {
  final int id;
  const OpenAppointment(this.id);
}

class OpenTodoTab extends WidgetLaunchAction {
  const OpenTodoTab();
}

/// Decodes the URIs the native widgets launch the app with into
/// [WidgetLaunchAction]s and exposes the most recent one for [RootScreen] to
/// act on. Covers both a cold start via a widget tap
/// (`initiallyLaunchedFromHomeWidget`) and a tap while the app is already
/// running (`widgetClicked`).
class WidgetLaunch {
  WidgetLaunch._();
  static final WidgetLaunch instance = WidgetLaunch._();

  final ValueNotifier<WidgetLaunchAction?> pending = ValueNotifier(null);

  Future<void> init() async {
    HomeWidget.widgetClicked.listen(_handle);
    final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handle(initial);
  }

  void _handle(Uri? uri) {
    if (uri == null) return;
    switch (uri.host.toLowerCase()) {
      case 'today':
        pending.value = const OpenToday();
      case 'newappointment':
        pending.value = const OpenNewAppointment();
      case 'appointment':
        final id = int.tryParse(uri.queryParameters['id'] ?? '');
        if (id != null) pending.value = OpenAppointment(id);
      case 'todotab':
        pending.value = const OpenTodoTab();
    }
  }

  /// Marks the current action as handled so it doesn't re-fire on the next
  /// rebuild.
  void consume() => pending.value = null;
}
