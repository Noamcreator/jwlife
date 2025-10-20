import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../core/api/api.dart';
import '../../core/utils/utils_dialog.dart';
import '../services/global_key_service.dart';

class JwLifeAutoUpdater {
  static Future<void> checkAndUpdate({bool showBannerNoUpdate = false}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final String antiCacheQuery = 'v=${DateTime.now().millisecondsSinceEpoch}';
      String appInfoApi = '${Api.gitubApi}app/app_version.json?$antiCacheQuery';
      print(appInfoApi);

      final response = await http.get(Uri.parse(appInfoApi));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final latestVersion = data['version'];
      final apkUrl = '${Api.gitubApi}app/${data['name']}?$antiCacheQuery';
      final changelog = data['changelog']?.toString() ?? "Aucune note de version disponible.";

      // Remplace les \n\n échappés par de vrais sauts de paragraphe
      String formattedChangelog = changelog.replaceAll(r'\n', '\n');

      if (_isNewerVersion(latestVersion, currentVersion)) {
        _showUpdateDialog(latestVersion, formattedChangelog, apkUrl);
      } else {
        debugPrint("✅ Aucune mise à jour disponible (version actuelle: $currentVersion)");
        if(showBannerNoUpdate) {
          showBottomMessage("✅ Aucune mise à jour disponible (version actuelle: $currentVersion)");
        }
      }
    } catch (e) {
      debugPrint("❌ Erreur de vérification de mise à jour: $e");
    }
  }

  static bool _isNewerVersion(String newV, String oldV) {
    List<int> newParts = newV.split('.').map(int.parse).toList();
    List<int> oldParts = oldV.split('.').map(int.parse).toList();
    for (int i = 0; i < newParts.length; i++) {
      if (newParts[i] > oldParts[i]) return true;
      if (newParts[i] < oldParts[i]) return false;
    }
    return false;
  }

  static void _showUpdateDialog(String version, String changelog, String apkUrl) {
    BuildContext context = GlobalKeyService.homeKey.currentState!.context;

    showJwDialog(
      context: context,
      titleText: "Nouvelle version disponible",
      content: Padding(
          padding: EdgeInsetsGeometry.all(16),
          child: SizedBox(
            width: double.maxFinite,
            height: 400, // hauteur fixe pour le scroll
            child: SingleChildScrollView(
              child: GptMarkdown(
                changelog,
                textScaler: TextScaler.linear(1.2),
              ),
            ),
          ),
      ),
      buttons: [
        JwDialogButton(
          label: "PLUS TARD",
          closeDialog: true,
        ),
        JwDialogButton(
          label: "METTRE A JOUR",
          closeDialog: true,
          onPressed: (_) {
            _downloadAndInstall(context, apkUrl, version, changelog);
          },
        ),
      ],
      buttonAxisAlignment: MainAxisAlignment.end,
    );
  }

  static Future<void> _downloadAndInstall(BuildContext context, String url, String version, String changelog) async {
    final dir = await getAppCacheDirectory();
    final filePath = "${dir.path}/update-$version.apk";
    final file = File(filePath);
    final dio = Dio();

    try {
      final progressDialog = JwProgressDialog(context: context, totalBytes: 0, changelog: changelog);
      progressDialog.show();

      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) progressDialog.totalBytes = total;
          JwProgressDialog.updateProgress(received);
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      progressDialog.dismiss();

      if (await Permission.requestInstallPackages.isDenied) {
        await Permission.requestInstallPackages.request();
      }

      await OpenFile.open(filePath, type: "application/vnd.android.package-archive");

    } catch (e) {
      debugPrint("❌ Erreur pendant la mise à jour : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Échec du téléchargement ou de l'installation.")),
      );
    }
  }
}

class JwProgressDialog {
  final BuildContext context;
  int totalBytes;
  static final ValueNotifier<int> _progressNotifier = ValueNotifier(0);
  bool _isShowing = false;
  String changelog;

  JwProgressDialog({required this.context, required this.changelog, this.totalBytes = 0});

  static void updateProgress(int bytes) {
    _progressNotifier.value = bytes;
  }

  Future<void> show() async {
    if (_isShowing) return;
    _isShowing = true;

    await showJwDialog<void>(
      context: context,
      titleText: "Téléchargement de la mise à jour",
      content: ValueListenableBuilder<int>(
        valueListenable: _progressNotifier,
        builder: (context, value, _) {
          double progress = totalBytes > 0 ? value / totalBytes : 0;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.maxFinite,
                  height: 400, // hauteur fixe pour le scroll
                  child: SingleChildScrollView(
                    child: GptMarkdown(
                      changelog,
                      textScaler: TextScaler.linear(1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: progress,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  backgroundColor: Colors.grey.shade300,
                  minHeight: 4,
                ),
                const SizedBox(height: 10),
                Text("${(progress * 100).toStringAsFixed(0)} %"),
              ],
            ),
          );
        },
      ),
      buttons: [],
      buttonAxisAlignment: MainAxisAlignment.end,
    );

    _isShowing = false;
  }

  void dismiss() {
    if (_isShowing) {
      Navigator.of(context, rootNavigator: true).pop();
      _isShowing = false;
    }
  }
}
