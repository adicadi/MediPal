import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/bootstrap.dart';

void main() async {
  await AppBootstrap.initialize();
  runApp(const MediPalApp());
}
