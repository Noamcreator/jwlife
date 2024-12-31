import 'package:flutter/material.dart';
import 'package:jwlife/pages/library_pages/video_pages/video_items_page.dart';
import 'package:realm/realm.dart';

import '../../../jwlife.dart';
import '../../../realm/catalog.dart';
import '../../../widgets/image_widget.dart';

class VideoPage extends StatefulWidget {
  final Category video;

  VideoPage({super.key, required this.video});

  @override
  _VideoPageState createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(5.0),
      child: Column(
        children: widget.video.subcategories.map((category) {
          return buildCategoryItem(category);
        }).toList()
      ),
    );
  }

  Widget buildCategoryItem(Category category) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
              return VideoItemsPage(
                category: category,
              );
            },
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        child: Stack(
          children: [
            ImageCachedWidget(
              imageUrl: category.persistedImages!.extraWideFullSizeImageUrl!,
              pathNoImage: "pub_type_video",
              height: 85.0,
              width: double.infinity,
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    category.localizedName!,
                    style: const TextStyle(
                      fontSize: 20.0,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}