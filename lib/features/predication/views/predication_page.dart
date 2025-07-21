import 'package:flutter/material.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/features/predication/views/predication_repport_page.dart';
import 'package:qr_flutter/qr_flutter.dart';  // Utilisé pour générer des QR codes
import 'package:printing/printing.dart';     // Utilisé pour générer un PDF
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:ui' as ui;

import 'visits_view.dart';  // Import for ImageByteFormat

class PredicationView extends StatefulWidget {
  const PredicationView({super.key});

  @override
  _PredicationViewState createState() => _PredicationViewState();
}

class _PredicationViewState extends State<PredicationView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _linesController = TextEditingController();
  String? qrPosition = 'Bas Gauche';

  // Variables pour suivre l'état des cases à cocher
  bool isQrCodeSelected = true;
  bool isLinesSelected = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf() async {
    final url = _urlController.text.trim();
    final sizeText = _sizeController.text.trim();
    final linesText = _linesController.text.trim();

    try {
      final doc = pw.Document();

      // Générer le QR code si applicable
      if (url.isNotEmpty && sizeText.isNotEmpty) {
        final size = double.parse(sizeText); // Assurez-vous que c'est un double

        // Générer le QR code sous forme d'image
        final qrImage = await QrPainter(
          data: url,
          version: QrVersions.auto,
          gapless: true,
        ).toImage(size); // size doit être converti en int

        final qrImageData = await qrImage.toByteData(
            format: ui.ImageByteFormat.png);
        final qrBytes = qrImageData!.buffer.asUint8List();

        // Ajouter une page avec le QR code à la position définie
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  pw.Container(
                    alignment: pw.Alignment.topLeft,
                    child: pw.Image(
                        pw.MemoryImage(qrBytes), width: size, height: size),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Générer uniquement des lignes si applicable
      final numberOfLines = int.tryParse(linesText) ?? 0;

      if (numberOfLines > 0) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                children: List.generate(numberOfLines, (index) {
                  return pw.Container(
                    margin: pw.EdgeInsets.only(bottom: (numberOfLines*2)),
                    // Espacement dynamique
                    height: 1,
                    width: double.infinity,
                    color: PdfColors.black,
                  );
                }),
              );
            },
          ),
        );
      }

      // Sauvegarder le PDF ou l'afficher
      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la génération du PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 4,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: Text('Prédication',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          body: Column(
            children: [
              TabBar(
                isScrollable: true,
                controller: _tabController,
                tabs: [
                  Tab(text: localization(context).navigation_predication_letters.toUpperCase()),
                  Tab(text: localization(context).navigation_predication_visits.toUpperCase()),
                  Tab(text: localization(context).navigation_predication_bible_studies.toUpperCase()),
                  Tab(text: localization(context).navigation_predication_report.toUpperCase()),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCourrierTab(), // Contenu de l'onglet "COURRIER"
                    VisitsView(),
                    Center(child: Text('COURS BIBLIQUES')),
                    PredicationReportPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildCourrierTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cases à cocher pour choisir entre QR Code et Lignes
          Row(
            children: [
              Checkbox(
                value: isQrCodeSelected,
                onChanged: (value) {
                  setState(() {
                    isQrCodeSelected = value!;
                  });
                },
              ),
              Text('QR Code'),
              SizedBox(width: 20), // Espace entre les cases à cocher
              Checkbox(
                value: isLinesSelected,
                onChanged: (value) {
                  setState(() {
                    isLinesSelected = value!;
                  });
                },
              ),
              Text('Lignes'),
            ],
          ),
          SizedBox(height: 10),

          // Afficher le QR Code si sélectionné
          if (isQrCodeSelected) ...[
            Text('QR Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                  labelText: 'Entrez le lien de la page'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _sizeController,
              decoration: InputDecoration(
                  labelText: 'Taille du QR Code (en pixels)'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            Text('Position du QR Code :'),
            DropdownButton<String>(
              value: qrPosition,
              items: [
                DropdownMenuItem(
                    child: Text('Haut Gauche'), value: 'Haut Gauche'),
                DropdownMenuItem(
                    child: Text('Haut Droite'), value: 'Haut Droite'),
                DropdownMenuItem(
                    child: Text('Bas Gauche'), value: 'Bas Gauche'),
                DropdownMenuItem(
                    child: Text('Bas Droite'), value: 'Bas Droite'),
              ],
              onChanged: (value) {
                setState(() {
                  qrPosition = value!;
                });
              },
            ),
            SizedBox(height: 20), // Espace entre QR Code et lignes
          ],

          // Afficher le TextField des lignes si la case "Lignes" est cochée
          if (isLinesSelected) ...[
            Text('Lignes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            TextField(
              controller: _linesController,
              decoration: InputDecoration(
                  labelText: 'Nombre de lignes à imprimer'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20), // Espace entre lignes et bouton
          ],

          ElevatedButton(
            onPressed: () => _generatePdf(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
              textStyle: const TextStyle(fontSize: 20),
            ),
            child: Text(
                'Générer le PDF', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}