import 'dart:io';

import 'package:fima/domain/entity/desktop_application.dart';
import 'package:fima/infrastructure/service/linux_application_service.dart';
import 'package:fima/infrastructure/service/macos_application_service.dart';
import 'package:fima/infrastructure/service/windows_application_service.dart';

abstract class ApplicationService {
  List<DesktopApplication> getInstalledApplications();

  factory ApplicationService() {
    if (Platform.isLinux) return LinuxApplicationService();
    if (Platform.isMacOS) return MacosApplicationService();
    if (Platform.isWindows) return WindowsApplicationService();
    return LinuxApplicationService();
  }
}
