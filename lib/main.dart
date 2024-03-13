import 'package:flutter/material.dart';
import 'package:silence_remover/src/app.dart';
import 'package:silence_remover/src/utils/utils.dart';

void main() async {
  await DB.init();
  runApp(const MyApp());
}
