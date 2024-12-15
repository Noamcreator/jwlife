import 'package:flutter/material.dart';
import 'package:jwlife/pages/library_pages/video_pages/video_items_page.dart';
import 'package:realm/realm.dart';

import '../../../jwlife.dart';
import '../../../realm/catalog.dart';
import '../../../widgets/image_widget.dart';

class VideoPage extends StatefulWidget {
  VideoPage({super.key});

  @override
  _VideoPageState createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  Category? video;

  @override
  void initState() {
    super.initState();
    getCategories();
  }

  Future<void> getCategories() async {
    final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
    String languageSymbol = JwLifeApp.currentLanguage.symbol;

    Realm realm = Realm(config);
    video = realm.all<Category>().query("key == 'VideoOnDemand'").query("language == '$languageSymbol'").first;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(5.0),
        itemCount: video!.subcategories.length,
        itemBuilder: (context, index) {
          var category = video!.subcategories[index];
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
        },
      ),
    );
  }
}