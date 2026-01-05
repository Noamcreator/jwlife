import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:provider/provider.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/mediaitem_item_widget.dart';
import 'package:jwlife/widgets/searchfield/searchfield_widget.dart';
import '../../../../app/app_page.dart';
import '../../../../i18n/i18n.dart';
import '../../models/videos/videos_items_model.dart';

class VideoItemsPage extends StatelessWidget {
  final RealmCategory category;

  const VideoItemsPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoItemsModel(initialCategory: category)..loadItems(),
      child: Consumer<VideoItemsModel>(
        builder: (context, model, child) {
          PreferredSizeWidget? appBar = model.isSearching
              ? _buildSearchingAppBar(context, model)
              : _buildRegularAppBar(model);

          Widget bodyContent;
          if (model.filteredVideos.isEmpty && !model.isSearching) {
            bodyContent = emptyStateWidget(i18n().message_no_items_videos, JwIcons.video_stack);
          } else {
            bodyContent = Directionality(textDirection: model.language.isRtl! ? TextDirection.rtl : TextDirection.ltr, child: _buildContentList(context, model));
          }

          return AppPage(
            appBar: appBar,
            body: bodyContent,
          );
        },
      ),
    );
  }

  // --- Méthodes de construction des composants UI (Widgets) ---

  PreferredSizeWidget _buildSearchingAppBar(BuildContext context, VideoItemsModel model) {
    return AppBar(
      titleSpacing: 0.0,
      title: SearchFieldWidget(
        query: '',
        onSearchTextChanged: model.filterVideos,
        onSuggestionTap: (item) {},
        onSubmit: (item) => model.setIsSearching(false),
        onTapOutside: (event) => model.setIsSearching(false),
        suggestionsNotifier: ValueNotifier([]),
      ),
      leading: IconButton(
        icon: const Icon(JwIcons.chevron_left),
        onPressed: () => model.cancelSearch(),
      ),
    );
  }

  PreferredSizeWidget _buildRegularAppBar(VideoItemsModel model) {
    return JwLifeAppBar(
      title: model.category?.name ?? '',
      subTitle: model.language.vernacular,
      actions: [
        IconTextButton(
          icon: const Icon(JwIcons.magnifying_glass),
          onPressed: (BuildContext context) => model.setIsSearching(true),
        ),
        IconTextButton(
          icon: const Icon(JwIcons.language),
          onPressed: (BuildContext context) => model.showLanguageSelection(context),
        ),
      ],
    );
  }

  Widget _buildContentList(BuildContext context, VideoItemsModel model) {
    return ListView.builder(
      itemCount: model.filteredVideos.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: OutlinedButton.icon(
              // Lance la lecture aléatoire de TOUS les médias
              onPressed: () => model.playAllMediaRandomly(context),
              icon: const Icon(JwIcons.arrows_twisted_right, size: 20),
              label: Text(i18n().action_shuffle, style: TextStyle(fontSize: 16)),
            ),
          );
        }

        final subCategory = model.filteredVideos[index - 1];
        // Récupère les clés de médias pour cette sous-catégorie
        final mediaKeys = model.filteredMediaMap[subCategory.key!] ?? subCategory.media.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        subCategory.name!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        IconButton(
                          padding: const EdgeInsets.all(0),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(JwIcons.cloud_arrow_down, color: Theme.of(context).primaryColor, size: 23),
                          onPressed: () => model.downloadAllVideo(context, mediaKeys.cast<String>()),
                        ),
                        IconButton(
                          padding: const EdgeInsets.all(0),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(JwIcons.play, color: Theme.of(context).primaryColor, size: 23),
                          onPressed: () => model.playMediaSequentially(context, mediaKeys.cast<String>()),
                        ),
                        IconButton(
                          padding: const EdgeInsets.all(0),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(JwIcons.arrows_twisted_right, color: Theme.of(context).primaryColor, size: 23),
                          onPressed: () => model.playMediaRandomly(context, mediaKeys.cast<String>()),
                        ),
                      ],
                    ),
                  ]),
            ),
            Container(
              height: 140,
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: mediaKeys.length,
                itemBuilder: (context, idx) {
                  final mediaKey = mediaKeys[idx];
                  // Récupère l'objet Media (une seule requête BDD par élément affiché)
                  final media = model.getMediaFromKey(mediaKey);

                  return MediaItemItemWidget(
                    media: media,
                    medias: mediaKeys.cast<String>(),
                    timeAgoText: false,
                    model: model,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}