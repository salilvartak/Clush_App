import 'package:encrypt/encrypt.dart';

void main() {
  final iv = IV.fromLength(16);
  print(iv.bytes);
}
