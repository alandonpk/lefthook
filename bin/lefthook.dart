import 'dart:io';
import 'dart:async';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:system_info/system_info.dart';

const _LEFTHOOK_VERSION = '0.7.7';

void main(List<String> args) async {
  final logger = new Logger.standard();
  final executablePath =
      Platform.script.resolve('../.exec/lefthook').toFilePath();
  ;

  await _ensureExecutable(executablePath);

  final result = await Process.run(executablePath, args);
  if (result.exitCode != 0) {
    logger.stderr(result.stderr);
    logger.stdout(result.stdout);
    exit(1);
  } else {
    logger.stdout(result.stdout);
  }
}

void _ensureExecutable(String targetPath, {bool force = false}) async {
  Logger logger = new Logger.standard();

  final fileAlreadyExist = await _isExecutableExist(targetPath);
  if (fileAlreadyExist && !force) {
    return;
  }

  final url = _resolveDownloadUrl();

  logger.stdout('Download executable for lefthook...');
  logger.stdout(url);

  final file = await _downloadFile(url);

  logger.stdout('Download complete');

  logger.stdout('');
  logger.stdout('Saving executable file...');
  await _saveFile(targetPath, file);

  logger.stdout('Saved to ${targetPath}');
  logger.stdout('');

  await _installLefthook(targetPath, logger);

  logger.stdout('All done!');
}

String _resolveDownloadUrl() {
  String getOS() {
    if (Platform.isLinux) {
      return 'Linux';
    }

    if (Platform.isMacOS) {
      return 'MacOS';
    }

    if (Platform.isWindows) {
      return 'Windows';
    }

    throw 'Unsupported OS';
  }

  String getArchitecture() {
    final arch = SysInfo.kernelArchitecture;

    if (arch == 'AMD64') {
      return 'x86_64';
    }

    if (['x86_64', 'i386', 'arm64'].contains(arch)) {
      return arch;
    }

    throw 'Unsupported architecture: $arch';
  }

  final os = getOS();
  final executableExt = os == 'Windows' ? '.exe' : '';
  final architecture = getArchitecture();

  return 'https://github.com/evilmartians/lefthook/releases/download/v${_LEFTHOOK_VERSION}/lefthook_${_LEFTHOOK_VERSION}_${os}_${architecture}${executableExt}';
}

Future<List<int>> _downloadFile(String url) async {
  HttpClient client = new HttpClient();
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();
  if (response.statusCode == 404) throw 'Lefthook executable not found at $url';

  final downloadData = List<int>();
  final completer = new Completer();
  response.listen((d) => downloadData.addAll(d), onDone: completer.complete);
  await completer.future;

  return downloadData;
}

Future<void> _saveFile(String targetPath, List<int> data) async {
  Future<void> makeExecutable(File file) async {
    String cmd;
    List args;
    if (Platform.isWindows) {
      cmd = "icacls";
      args = [file.path, "/grant", "%username%:(r,x)"];
    } else {
      cmd = "chmod";
      args = ["u+x", file.path];
    }

    final result = await Process.run(cmd, args);

    if (result.exitCode != 0) {
      throw new Exception(result.stderr);
    }
  }

  final executableFile = new File(targetPath);
  await executableFile.create(recursive: true);
  await executableFile.writeAsBytes(data);
  await makeExecutable(executableFile);
}

Future<void> _installLefthook(String executablePath, Logger logger) async {
  final result = await Process.run(executablePath, ["install", '-f']);

  if (result.exitCode != 0) {
    logger.stderr(result.stderr);
    throw new Exception(result.stderr);
  }

  logger.stdout(result.stdout);
}

Future<bool> _isExecutableExist(String executablePath) async {
  return new File(executablePath).exists();
}
