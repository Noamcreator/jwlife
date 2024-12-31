import 'package:flutter/material.dart';

class VerseDialogItem extends StatefulWidget {
  final dynamic verses;
  final Function onClose; // Callback pour fermer le dialogue
  final Map<String, double> position;

  const VerseDialogItem({
    Key? key,
    required this.verses,
    required this.onClose,
    required this.position,
  }) : super(key: key);

  @override
  _VerseDialogItemState createState() => _VerseDialogItemState();
}

class _VerseDialogItemState extends State<VerseDialogItem> {
  double xPosition = 0;
  double yPosition = 0;
  bool isFullScreen = false;

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: GestureDetector(
        onPanUpdate: (tapInfo) {
          if (!isFullScreen) {
            setState(() {
              double newX = (widget.position["x"] ?? 0) + tapInfo.delta.dx;
              double newY = (widget.position["y"] ?? 0) + tapInfo.delta.dy;

              // Clamp the new position to stay within screen bounds
              newX = newX.clamp(0.0, screenWidth - 300);
              newY = newY.clamp(0.0, screenHeight - 250);

              widget.position["x"] = newX;
              widget.position["y"] = newY;
            });
          }
        },
        child: Material(
          elevation: 4.0,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 300,
              maxHeight: screenHeight * 0.8, // Limite à 80% de la hauteur de l'écran
            ),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              mainAxisSize: MainAxisSize.min, // Ajuste la taille en fonction du contenu
              children: [
                // Section du titre
                Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF424242)
                      : Color(0xFFd8d7d5),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.verses["title"],
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(isFullScreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen),
                            onPressed: () {
                              setState(() {
                                isFullScreen = !isFullScreen;
                                if (isFullScreen) {
                                  widget.position["x"] = xPosition; // Enregistrer la position
                                  widget.position["y"] = yPosition; // Enregistrer la position
                                  xPosition = 0; // Réinitialiser la position si on quitte le plein écran
                                  yPosition = 0;
                                } else {
                                  xPosition = widget.position["x"]!; // Restaurer la position
                                  yPosition = widget.position["y"]!; // Restaurer la position
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              widget.onClose(); // Appel du callback pour fermer
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Section des éléments
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(
                        widget.verses["items"].length,
                            (index) {
                          final item = widget.verses["items"][index];
                          return GestureDetector(
                            onTap: () {
                              print(item["title"]);
                            },
                            child: Container(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFF262626)
                                  : Color(0xFFf2f1ef),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      item["hideThumbnailImage"] || item["imageUrl"] == null
                                          ? Container()
                                          : Image.network(
                                        "https://wol.jw.org" + item["imageUrl"],
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item["title"],
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              item["publicationTitle"],
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600]),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Section du contenu pour chaque item
                                  /*
                                  DocumentHtmlView(
                                      html: item["content"],
                                      docId: index,
                                      isVerseDialog: true),

                                   */
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
