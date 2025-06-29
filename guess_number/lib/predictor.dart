import 'dart:js' as js;

Future<int> predictDigit(List<double> image) async {
  final result = js.context.callMethod('predictDigit', [image]);
  return result as int;
}
