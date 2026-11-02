import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 仅竖屏（移动端设计稿 390×844）
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const LujiApp());
}
