import 'package:csv/csv.dart';
void main() {
  print(CsvEncoder().convert([['a', 'b'], ['c', 'd']]));
}
