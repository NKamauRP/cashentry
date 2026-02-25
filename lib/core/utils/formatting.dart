String formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString();
  return '$y-$m-$d';
}

String formatMoney(double value) => value.toStringAsFixed(2);
