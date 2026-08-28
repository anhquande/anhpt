import 'dart:io';

import 'package:win32/win32.dart';

Future<bool> turnOffDisplayOnPlatform() async {
  if (!Platform.isWindows) return false;
  final targetWindow = GetForegroundWindow();
  if (targetWindow == 0) return false;

  // Do not use HWND_BROADCAST here. Broadcasting WM_SYSCOMMAND also reaches
  // Windows shell processes; on some systems that can be interpreted as a
  // machine power action instead of monitor power-off.
  SendMessage(targetWindow, WM_SYSCOMMAND, SC_MONITORPOWER, 2);
  return true;
}
