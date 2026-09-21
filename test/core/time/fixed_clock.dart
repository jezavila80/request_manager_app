import 'package:request_manager_app/core/time/app_clock.dart';

final class FixedClock implements AppClock {
  const FixedClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value.toUtc();
}
