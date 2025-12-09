import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/assets.dart';
import '../core/ui/app_dimens.dart';
import '../data/databases/tiles_cache.dart';
import '../i18n/i18n.dart';

Future<T?> showQrCodeDialog<T>(
    BuildContext context,
    String title,
    String data, {
      String? imagePath,
    }) {
  return showDialog<T>(
    context: context,
    builder: (context) => QrCodeDialog(title: title, data: data, imagePath: imagePath),
  );
}

class QrCodeDialog extends StatefulWidget {
  final String title;
  final String data;
  final String? imagePath;

  const QrCodeDialog({super.key, required this.title, required this.data, this.imagePath});

  @override
  State<QrCodeDialog> createState() => _QrCodeDialogState();
}

class _QrCodeDialogState extends State<QrCodeDialog> {
  bool _isGray = true;
  File? _imageFile;

  void _toggleBackground() {
    setState(() {
      _isGray = !_isGray;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  // Fonction asynchrone pour charger l'image
  Future<void> _loadImage() async {
    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      if (widget.imagePath!.contains('data')) {
        setState(() {
          _imageFile = File(widget.imagePath!);
        });
      }
      else {
        final imageFile = await TilesCache().getOrDownloadImage(widget.imagePath!);
        if (imageFile != null) {
          setState(() {
            _imageFile = File(imageFile.file.path);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isGray ? Colors.grey[300]! : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                widget.title,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF212121),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Center(
              child: GestureDetector(
                onTap: _toggleBackground,
                child: QrImageView(
                  data: widget.data,
                  backgroundColor: backgroundColor,
                  version: QrVersions.auto,
                  size: 250,
                  embeddedImage: _imageFile != null ? FileImage(_imageFile!) : const AssetImage(Assets.iconsNavJworg),
                  embeddedImageStyle: QrEmbeddedImageStyle(
                    size: const Size(kItemHeight / 1.2, kItemHeight / 1.2),
                  ),
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      i18n().action_close_upper,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}

Future<Barcode?> showQrCodeScanner(BuildContext context) {
  return showDialog<Barcode?>(
    context: context,
    builder: (context) => const QrCodeScannerDialog(),
  );
}

class QrCodeScannerDialog extends StatefulWidget {
  const QrCodeScannerDialog({super.key});

  @override
  State<QrCodeScannerDialog> createState() => _QrCodeScannerDialogState();
}

class _QrCodeScannerDialogState extends State<QrCodeScannerDialog> {
  final MobileScannerController controller = MobileScannerController(
    // Optionnel: peut améliorer la performance ou la précision
    detectionSpeed: DetectionSpeed.normal,
  );

  PermissionStatus _cameraPermissionStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    // Au lieu de vérifier seulement, on demande la permission au démarrage
    _requestCameraPermission();
  }

  // Vérifie l'état actuel et demande la permission de la caméra si nécessaire
  Future<void> _requestCameraPermission() async {
    // 1. On vérifie l'état actuel
    var status = await Permission.camera.status;

    // 2. Si elle n'est pas encore accordée ou refusée, on la demande
    if (status.isDenied || status.isLimited) {
      status = await Permission.camera.request();
    }

    // 3. On met à jour l'état dans le widget
    if (mounted) {
      setState(() {
        _cameraPermissionStatus = status;
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Gère la détection du code QR (identique à votre implémentation)
  void _onDetect(BarcodeCapture capture) {
    final Barcode? barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null) {
      // Arrête le scanner et renvoie le résultat via Navigator.pop
      controller.stop();
      Navigator.of(context).pop(barcode);
    }
  }

  // Affiche le contenu principal (Scanner, Refus Permanent, ou Chargement)
  Widget _buildContent() {
    if (_cameraPermissionStatus.isGranted) {
      // **A. Permission Accordée : Affiche le scanner**
      return MobileScanner(
        controller: controller,
        // On ne définit pas de scanWindow ici pour laisser le MobileScanner
        // utiliser toute la zone disponible du conteneur parent (plus simple).
        onDetect: _onDetect,
        overlayBuilder: (context, constraints) {
          // Un carré de 250x250 centré pour l'effet visuel
          const double scanArea = 250;
          return Center(
            child: Container(
              width: scanArea,
              height: scanArea,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      );
    } else if (_cameraPermissionStatus.isPermanentlyDenied) {
      // **B. Permission Refusée Définitivement : Demande d'aller dans les paramètres**
      return _buildPermissionDeniedMessage();
    }
    else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  // Message d'erreur pour permission refusée
  Widget _buildPermissionDeniedMessage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.no_photography, size: 40, color: Colors.red),
        const SizedBox(height: 15),
        const Text(
          "L'accès à la caméra est refusé. Pour scanner, veuillez l'activer dans les paramètres de votre appareil.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 15),
        ElevatedButton.icon(
          onPressed: openAppSettings, // Ouvre les paramètres de l'application
          icon: const Icon(Icons.settings),
          label: const Text("Ouvrir les paramètres"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Utilise un simple Dialog pour avoir un contenu centré et personnalisé.
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      // Le contenu interne sera ajusté en fonction de la permission
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                i18n().action_scan_qr_code,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF212121),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 320,
              // Ligne Corrigée: Suppression de l'Expanded
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Le contenu principal (Scanner ou Message d'Erreur)
                      _buildContent(),

                      // Bouton de Flash/Torche (uniquement si permission accordée)
                      if (_cameraPermissionStatus.isGranted)
                        Positioned(
                          bottom: 25,
                          child: IconButton(
                            color: Colors.white,
                            iconSize: 30,
                            icon: ValueListenableBuilder<MobileScannerState>(
                              valueListenable: controller,
                              builder: (context, state, child) {
                                // Affiche le bouton uniquement s'il a accès à la caméra
                                if (state.hasCameraPermission) {
                                  return Icon(
                                    controller.torchEnabled ? Icons.flash_on : Icons.flash_off,
                                    color: controller.torchEnabled ? Colors.yellow : Colors.white,
                                  );
                                } else {
                                  return const SizedBox.shrink();
                                }
                              },
                            ),
                            onPressed: () => controller.toggleTorch(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      i18n().action_close_upper,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}