import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/mediaitem_item_widget.dart';
import 'package:jwlife/widgets/searchfield/searchfield_widget.dart';
import '../../models/videos/videos_items_model.dart';

class VideoItemsPage extends StatelessWidget {
  final Category category;

  const VideoItemsPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoItemsModel(initialCategory: category)..loadItems(),
      child: Consumer<VideoItemsModel>(
        builder: (context, model, child) {
          const textStyleTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
          final textStyleSubtitle = TextStyle(
            fontSize: 14,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFc3c3c3)
                : const Color(0xFF626262),
          );

          final appBar = model.isSearching
              ? _buildSearchingAppBar(context, model)
              : _buildRegularAppBar(context, model, textStyleTitle, textStyleSubtitle);

          Widget bodyContent;
          if (model.filteredVideos.isEmpty && !model.isSearching) {
            bodyContent = _buildEmptyState(context);
          } else {
            bodyContent = _buildContentList(context, model);
          }

          return Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: appBar,
            body: bodyContent,
          );
        },
      ),
    );
  }

  // --- Méthodes de construction des composants UI (Widgets) ---

  AppBar _buildSearchingAppBar(BuildContext context, VideoItemsModel model) {
    return AppBar(
      title: SearchFieldWidget(
        query: '',
        onSearchTextChanged: model.filterVideos,
        onSuggestionTap: (item) {},
        onSubmit: (item) => model.setIsSearching(false),
        onTapOutside: (event) => model.setIsSearching(false),
        suggestionsNotifier: ValueNotifier([]),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => model.cancelSearch(),
      ),
    );
  }

  AppBar _buildRegularAppBar(BuildContext context, VideoItemsModel model, TextStyle titleStyle, TextStyle subtitleStyle) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(model.categoryName, style: titleStyle),
          Text(model.language, style: subtitleStyle),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(JwIcons.magnifying_glass),
          onPressed: () => model.setIsSearching(true),
        ),
        IconButton(
          icon: const Icon(JwIcons.language),
          onPressed: () => model.showLanguageSelection(context),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'Il n\'y a pas de vidéos disponibles pour le moment dans cette langue.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).hintColor,
          ),
        ),
      ),
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
              label: const Text('Lecture aléatoire', style: TextStyle(fontSize: 16)),
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
                        subCategory.localizedName!,
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