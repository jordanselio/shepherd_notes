String formatStoredTime(String value) {
  final parts = value.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final minuteStr = minute.toString().padLeft(2, '0');
  return '$hour12:$minuteStr $period';
}
