import 'device_action_service_stub.dart'
    if (dart.library.io) 'device_action_service_io.dart';

class DeviceActionService {
  Future<bool> turnOffDisplay() => turnOffDisplayOnPlatform();

  Future<bool> restoreDisplay() => restoreDisplayOnPlatform();
}
