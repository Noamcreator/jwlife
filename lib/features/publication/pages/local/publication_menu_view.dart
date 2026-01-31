import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/html_styles.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:jwlife/features/publication/models/menu/local/bible_color_group.dart';
import 'package:jwlife/features/document/data/models/multimedia.dart';
import 'package:jwlife/features/image/pages/full_screen_image_page.dart';
import 'package:jwlife/features/publication/pages/local/publication_search_view.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:jwlife/widgets/searchfield/searchfield_widget.dart';

import '../../../../../app/app_page.dart';
import '../../../../../app/services/settings_service.dart';
import '../../../../../core/ui/app_dimens.dart';
import '../../../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../../../core/utils/utils_language_dialog.dart';
import '../../../../../core/utils/utils_pub.dart';
import '../../../../../i18n/i18n.dart';
import '../../../../widgets/dialog/qr_code_dialog.dart';
import '../../../bible/pages/bible_chapter_page.dart';
import '../../models/menu/local/menu_list_item.dart';
import '../../models/menu/local/publication_menu_model.dart';
import '../../models/menu/local/tab_items.dart' show TabWithItems;
import '../../models/menu/local/words_suggestions_model.dart';
import '../../widgets/publication_tab_view.dart';

const double breakpointMedium = 530.0;
const double breakpointLarge = 800.0;
const double breakpointBig = 900.0;

class PublicationMenuPage extends StatefulWidget {
  final Publication publication;
  final bool showAppBar;
  final bool canPop;

  const PublicationMenuPage({super.key, required this.publication, this.showAppBar = true, this.canPop = true});

  @override
  PublicationMenuPageState createState() => PublicationMenuPageState();
}

class PublicationMenuPageState extends State<PublicationMenuPage> with SingleTickerProviderStateMixin {
  late PublicationMenuModel _model;
  bool _isLoading = true;
  TabController? _tabController;
  final ScrollController _mainScrollController = ScrollController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _model = PublicationMenuModel(widget.publication);
    init();
  }

  Future<void> init() async {
    await _model.init();
    if (_model.tabsWithItems.isNotEmpty && _model.tabsWithItems.length > 1) {
      _tabController = TabController(
        length: _model.tabsWithItems.length,
        vsync: this,
        initialIndex: _model.initialTabIndex,
      );
      // Listener pour forcer le refresh uniquement de la zone de contenu lors du switch d'onglet
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) setState(() {});
      });
    }

    if (mounted) setState(() => _isLoading = false);
    _model.initAudio();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> goToTheBooksTab() async {
    if(_tabController != null) {
      // Assure que l'index 1 existe avant d'animer
      if (_model.tabsWithItems.length > 1) {
        _tabController!.animateTo(_model.initialTabIndex);
        _mainScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> refreshBibleColors() async {
    setState(() {});
  }

  // --- FONCTION UTILITAIRE POUR LA FLUIDITÉ ---
  List<ListItem> _flattenItems(List<ListItem> items) {
    final List<ListItem> flatList = [];
    for (var item in items) {
      if (item.isTitle) {
        flatList.add(item);
        flatList.addAll(item.subItems);
      } else {
        flatList.add(item);
      }
    }
    return flatList;
  }

  Widget _buildMenu() {
    // LOADING
    if (_isLoading) {
      return getLoadingWidget(Theme.of(context).primaryColor);
    }

    // EMPTY
    if (_model.tabsWithItems.isEmpty) {
      return Center(
        child: Text(i18n().message_no_content),
      );
    }

    final bool isBible = widget.publication.isBible() || !widget.canPop;
    final bool showHeader = !isBible;
    final bool hasMultipleTabs = _model.tabsWithItems.length > 1;

    return Directionality(
      textDirection: widget.publication.mepsLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isBible ? double.infinity : kMaxMenuItemWidth,
          ),
          child: NestedScrollView(
            controller: _mainScrollController,

            // ================= HEADER =================
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                if (showHeader)
                  SliverToBoxAdapter(
                    child: _buildHeaderContent(),
                  ),

                // TAB BAR SEULEMENT SI PLUSIEURS TABS
                if (hasMultipleTabs)
                  SliverToBoxAdapter(
                    child: _buildTabBar(isBible),
                  ),
              ];
            },

            // ================= CONTENU =================
            body: hasMultipleTabs
                ? TabBarView(
              controller: _tabController,
              children: List.generate(
                _model.tabsWithItems.length,
                    (index) {
                  final tab = _model.tabsWithItems[index];

                  return PublicationTabView(
                    tab: tab,
                    builder: _buildTabSliverContent,
                  );
                },
              ),
            )

            // 👉 UNE SEULE TAB (PAS DE TABBAR / PAS DE SWIPE)
                : _buildTabSliverContent(
              context,
              _model.tabsWithItems.first,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSliverContent(BuildContext context,TabWithItems tab) {
    final bool isNumberType = tab.tab['DataType'] == 'number';
    final bool isBibleBooks = tab.items.any((item) => item.isBibleBooks);

    final List<ListItem> flatItems = _flattenItems(tab.items);

    // NUMBER TYPE
    if (isNumberType) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildPaddingContent(
              _buildNumberList(tab.items),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      );
    }

    // BIBLE BOOKS
    if (isBibleBooks) {
      return CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              _buildBooksTab(context, tab),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      );
    }

    // STANDARD LIST
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final item = flatItems[index];

              if (item.isTitle) {
                return _buildPaddingContent(
                  _buildOnlyTitleSection(context, item),
                );
              }

              return _buildPaddingContent(
                _buildNameItem(context, item),
              );
            },
            childCount: flatItems.length,
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
      ],
    );
  }

  Widget _buildPaddingContent(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: child,
    );
  }

  Widget _buildHeaderContent() {
    final imageLsr = widget.publication.imageLsr;
    final path = widget.publication.path;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool hasImage = imageLsr is String && imageLsr.isNotEmpty && path != null;
    final String imagePath = hasImage ? '$path/${imageLsr.split('/').last}' : '';

    return Column(
      children: [
        if (hasImage)
          GestureDetector(
            onTap: () {
              Multimedia m = Multimedia(filePath: imageLsr.split('/').last);
              showPage(FullScreenImagePage(publication: widget.publication, multimedias: [m], multimedia: m));
            },
            onLongPressStart: (details) {
              // Les coordonnées du pointeur sont ici dans details.globalPosition
              final double clientX = details.globalPosition.dx;
              final double clientY = details.globalPosition.dy;

              // Nous appelons la fonction avec les coordonnées calculées
              // Faire vibrer le téléphone
              HapticFeedback.mediumImpact();

              showFloatingMenuAtPosition(context, imagePath, clientX, clientY);
            },
            child: AspectRatio(
              aspectRatio: 1200 / 600,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.fill,
                width: double.infinity,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 50),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            widget.publication.getCoverTitle(),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2, color: isDarkMode ? Colors.white : Colors.black),
            textAlign: TextAlign.center,
          ),
        ),
        if (widget.publication.description.isNotEmpty && JwLifeSettings.instance.showPublicationDescription)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextHtmlWidget(text: widget.publication.description, style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), textAlign: TextAlign.center, isSearch: false),
          ),
        const SizedBox(height: 5),
      ],
    );
  }

  Widget _buildOnlyTitleSection(BuildContext context, ListItem item) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxMenuItemWidth),
        child: Padding(
          padding: EdgeInsets.only(top: item.title.isEmpty ? 10 : 20),
          child: item.title.isNotEmpty
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                fontSize: 20, fontWeight: FontWeight.bold,
              )),
              const SizedBox(height: 2),
              const Divider(color: Color(0xFFa7a7a7), height: 1),
              const SizedBox(height: 10),
            ],
          )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildNameItem(BuildContext context, ListItem item) {
    final bool isRtl = widget.publication.mepsLanguage.isRtl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String subtitle = item.subTitle.replaceAll('​', '').trim();
    final bool showSubTitle = subtitle.isNotEmpty && subtitle != item.displayTitle;

    final String? path = widget.publication.path;
    final String imageFullPath = (item.showImage && item.imageFilePath.isNotEmpty && path != null) ? '$path/${item.imageFilePath}' : '';

    final String description = item.description.replaceAll('​', '').trim();
    final bool showDescription = JwLifeSettings.instance.showDocumentDescription ? (description.isNotEmpty && description != item.displayTitle) : false;

    return Padding(
      padding: EdgeInsets.only(top: 4, bottom: showDescription ? 8 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showPageDocument(widget.publication, item.mepsDocumentId),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.showImage)
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsetsDirectional.only(end: 10, start: 5), // Ajout d'un petit start pour l'image
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: imageFullPath.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(imageFullPath),
                                fit: BoxFit.cover,
                                cacheWidth: 180,
                              ),
                            )
                          : null,
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        // Si pas d'image, on met 16 de padding pour ne pas coller au bord
                        start: 0,
                        top: showDescription ? 2 : 4.0,
                        end: 30,
                        bottom: item.showImage ? 0 : 15
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showSubTitle)
                            Text(item.subTitle, style: TextStyle(color: isDark ? const Color(0xFFc0c0c0) : const Color(0xFF626262), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2.0),
                          Text(item.displayTitle, style: TextStyle(color: isDark ? const Color(0xFF9fb9e3) : const Color(0xFF4a6da7), fontSize: 16.5, height: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (showDescription) ...[
                            const SizedBox(height: 2.0), // Espace pour que la description ne colle pas au titre
                            Text(description, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12), maxLines: 4, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              PositionedDirectional(top: -10, end: -12, child: _buildPopupMenu(item)),
              _buildDownloadIndicator(item, isRtl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberList(List<ListItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 60).floor().clamp(1, 10);
        return GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 2.0,
            mainAxisSpacing: 2.0,
            childAspectRatio: 1.0,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final String displayLabel = item.title;
            return Material(
              color: const Color(0xFF757575),
              child: InkWell(
                onTap: () => showPageDocument(widget.publication, item.mepsDocumentId),
                child: Container(
                  alignment: Alignment.center,
                  child: Text(displayLabel, style: const TextStyle(color: Colors.white, fontSize: 20)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabBar(bool isBible) {
    final List<Tab> tabs = _model.tabsWithItems.map((t) => Tab(text: t.tab['Title'] ?? 'Tab')).toList();

    return isBible ?
    Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111111)
          : Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        dividerHeight: 1,
        dividerColor: const Color(0xFF686868),
        tabs: tabs,
        labelStyle: const TextStyle(letterSpacing: 0.5, fontWeight: FontWeight.bold, fontSize: 16),
        unselectedLabelStyle: const TextStyle(letterSpacing: 0.5, fontSize: 16),
        indicatorWeight: 2,
      ),
    )
        :
    Material(
      color: Colors.transparent,
      child: SizedBox(
        height: 40, // Force une hauteur plus petite
        child: TabBar(
          controller: _tabController,
          padding: const EdgeInsets.only(left: 10, right: 10),
          isScrollable: true,
          dividerHeight: 0,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
          indicatorSize: TabBarIndicatorSize.label,
          splashFactory: InkRipple.splashFactory,

          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFF686868).withOpacity(0.1);
            }
            return Colors.transparent;
          }),

          tabs: tabs, // Assurez-vous que vos widgets Tab n'ont pas de padding interne excessif
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          unselectedLabelStyle: const TextStyle(fontSize: 14, letterSpacing: 1.5),
          indicatorAnimation: TabIndicatorAnimation.linear,
          indicatorPadding: const EdgeInsets.only(bottom: 6),
        ),
      )
    );
  }

  Widget _buildDownloadIndicator(ListItem item, bool isRtl) {
    return ValueListenableBuilder<List<Audio>>(
      valueListenable: widget.publication.audiosNotifier,
      builder: (context, audios, _) {
        final audio = audios.firstWhereOrNull((a) => a.documentId == item.mepsDocumentId);
        if (audio == null) return const SizedBox.shrink();

        return ValueListenableBuilder<bool>(
          valueListenable: audio.isDownloadingNotifier,
          builder: (context, isDownloading, _) {
            if (!isDownloading) return const SizedBox.shrink();
            return PositionedDirectional(
              bottom: 5,
              start: item.showImage ? 70 : 0,
              end: 40,
              child: ValueListenableBuilder<double>(
                valueListenable: audio.progressNotifier,
                builder: (context, progress, _) => LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPopupMenu(ListItem item) {
    return ValueListenableBuilder<List<Audio>>(
        valueListenable: widget.publication.audiosNotifier,
        builder: (context, audios, _) {
          final audio = audios.firstWhereOrNull((a) => a.documentId == item.mepsDocumentId);
          return PopupMenuButton(
            useRootNavigator: true,
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_horiz, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8e8e8e) : const Color(0xFF757575)),
            itemBuilder: (context) {
              List<PopupMenuEntry> menuItems = [];
              if (audio != null && audio.fileSize != null) {
                menuItems.add(PopupMenuItem(child: Row(children: [const Icon(JwIcons.headphones__simple), const SizedBox(width: 8), Text(i18n().action_play_audio)]), onTap: () { int index = widget.publication.audiosNotifier.value.indexWhere((audio) => audio.documentId == item.mepsDocumentId); if (index != -1) { showAudioPlayerPublicationLink(context, widget.publication, index); } }));
                menuItems.add(PopupMenuItem(child: Row(children: [const Icon(JwIcons.cloud_arrow_down), const SizedBox(width: 8), ValueListenableBuilder<bool>(valueListenable: audio.isDownloadingNotifier, builder: (context, isDownloading, child) { return isDownloading ? const SizedBox.shrink() : Text(audio.isDownloadedNotifier.value ? i18n().action_remove_audio_size(formatFileSize(audio.fileSize!)) : i18n().action_download_audio_size(formatFileSize(audio.fileSize!)), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)); }),]), onTap: () { if (audio.isDownloadedNotifier.value) { audio.remove(context); } else { audio.download(context); } }));
              }
              menuItems.add(PopupMenuItem(child: Row(children: [const Icon(JwIcons.share), const SizedBox(width: 8), Text(i18n().action_open_in_share)]), onTap: () => widget.publication.documentsManager?.getDocumentFromMepsDocumentId(item.mepsDocumentId).share()));
              menuItems.add(PopupMenuItem(child: Row(children: [const Icon(JwIcons.qr_code), const SizedBox(width: 8), Text(i18n().action_qr_code)]), onTap: () { String? uri = widget.publication.documentsManager?.getDocumentFromMepsDocumentId(item.mepsDocumentId).share(hide: true); if(uri != null) {showQrCodeDialog(context, item.title, uri);}}));
              return menuItems;
            },
          );
        }
    );
  }

  String _getBookDisplayTitle(ListItem item, double screenWidth) {
    if (screenWidth >= breakpointLarge && item.largeTitle.isNotEmpty) return item.largeTitle;
    if (screenWidth >= breakpointMedium && item.mediumTitle.isNotEmpty) return item.mediumTitle;
    return item.title.isNotEmpty ? item.title : item.displayTitle;
  }

  Widget _buildBookItem(BuildContext context, ListItem item, double screenWidth) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int bibleBookId = item.bibleBookNumber ?? 0;
    final int groupId = item.groupId ?? 0;
    final bool hasCommentary = item.hasCommentary ?? false;
    final bool hasAudio = _model.publication.audiosNotifier.value.any((audio) => audio.track == bibleBookId);
    final String displayTitle = _getBookDisplayTitle(item, screenWidth);
    final bool isBookExist = item.isBookExist;

    final Color colorBackgroundBookNoExist = isDark ? Color(0xFF3C3C3C) : Color(0xFFD8D8D8);
    final Color colorTextBookNoExist = isDark ? Color(0xFF626262) : Color(0xFFA7A7A7);

    if (screenWidth < breakpointMedium) {
      return GestureDetector(
        onTap: () => isBookExist ? showPage(BibleChapterPage(bible: widget.publication, book: bibleBookId, bookName: item.largeTitle)) : null,
        child: Container(
          decoration: BoxDecoration(color: isBookExist ? BibleColorGroup.getGroupColorAt(groupId) : colorBackgroundBookNoExist),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Text(displayTitle, style: TextStyle(color: isBookExist ? Colors.white : colorTextBookNoExist, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      );
    }

    final double iconSize = screenWidth >= breakpointLarge ? 15 : 13;
    final double titleRightPadding = 8.0 + (hasAudio ? iconSize + 4.0 : 0.0) + (hasCommentary ? iconSize + 4.0 : 0.0);
    final double commentaryRightPosition = hasAudio ? 4.0 + iconSize + 4.0 : 4.0;

    return GestureDetector(
      onTap: () => showPage(BibleChapterPage(bible: widget.publication, book: bibleBookId, bookName: item.largeTitle)),
      child: Container(
        decoration: BoxDecoration(color: BibleColorGroup.getGroupColorAt(groupId)),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 8.0, right: titleRightPadding),
                child: Text(displayTitle, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (hasAudio)
              PositionedDirectional(end: 4.0, top: 4, child: Icon(JwIcons.headphones__simple, size: iconSize, color: Colors.white)),
            if (hasCommentary)
              PositionedDirectional(end: commentaryRightPosition, top: 4, child: Icon(JwIcons.gem__simple, size: iconSize, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBooksTab(BuildContext context, TabWithItems tabWithItems) {
    final List<ListItem> topLevelItems = tabWithItems.items;
    return [
      LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = constraints.maxWidth;
          final double maxListWidth = screenWidth / 2 / 4 - 3 * kSpacing;
          int crossAxisCount;
          double mainAxisExtent;

          if (screenWidth < breakpointMedium) {
            crossAxisCount = 6; mainAxisExtent = 60.0;
          } else if (screenWidth < breakpointLarge) {
            crossAxisCount = (screenWidth / 100.0).floor(); mainAxisExtent = 45.0;
          } else {
            crossAxisCount = (screenWidth / 150.0).floor(); mainAxisExtent = 45.0;
            crossAxisCount = crossAxisCount < 2 ? 2 : crossAxisCount;
          }
          crossAxisCount = crossAxisCount < 1 ? 1 : crossAxisCount;

          final List<Widget> listContents = topLevelItems.map((item) {
            if (item.isTitle) {
              return Padding(
                padding: const EdgeInsets.only(top: 16.0, left: 8.0, right: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 20.0, fontWeight: FontWeight.bold, height: 1.2)),
                    const SizedBox(height: 10),
                    if (item.isBibleBooks)
                      if (screenWidth < breakpointMedium)
                        SizedBox(
                          width: (crossAxisCount * mainAxisExtent) + ((crossAxisCount - 1) * kSpacing),
                          child: GridView.builder(
                            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: kSpacing, mainAxisSpacing: kSpacing, mainAxisExtent: mainAxisExtent),
                            itemCount: item.subItems.length,
                            itemBuilder: (context, index) => _buildBookItem(context, item.subItems[index], screenWidth),
                          ),
                        )
                      else if (screenWidth < breakpointBig)
                        GridView.builder(
                          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: kSpacing, mainAxisSpacing: kSpacing, mainAxisExtent: mainAxisExtent),
                          itemCount: item.subItems.length,
                          itemBuilder: (context, index) => _buildBookItem(context, item.subItems[index], screenWidth),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: tabWithItems.items.indexOf(item) == 0 ? ((maxListWidth * 4) + kSpacing * 3) : ((maxListWidth * 3) + kSpacing * 2)),
                          child: GridView.builder(
                            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: tabWithItems.items.indexOf(item) == 0 ? 4 : 3, crossAxisSpacing: kSpacing, mainAxisSpacing: kSpacing, mainAxisExtent: mainAxisExtent),
                            itemCount: item.subItems.length,
                            itemBuilder: (context, index) => _buildBookItem(context, item.subItems[index], screenWidth),
                          ),
                        )
                  ],
                ),
              );
            }
            return Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: _buildNameItem(context, item));
          }).toList();

          if (screenWidth >= breakpointBig) {
            final int half = (listContents.length / 2).ceil();
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: listContents.sublist(0, half))),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: listContents.sublist(half))),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: listContents);
        },
      ),
    ];
  }

  Widget _buildCircuitMenu() {
    // Récupération de la couleur de texte en fonction du thème
    final textColor = Theme
        .of(context)
        .brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    final bool isRtl = widget.publication.mepsLanguage.isRtl;
    final TextDirection textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;


    return Directionality(
      textDirection: textDirection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Liste des éléments dans une colonne
          _isLoading ? getLoadingWidget(Theme.of(context).primaryColor) : Column(
            children: _model.tabsWithItems.first.items.map<Widget>((item) {
              _model.tabsWithItems.first.items.any((
                  item) => item.imageFilePath != '');
      
              if (item.isTitle) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 19.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Divider(
                            color: Color(0xFFa7a7a7),
                            height: 1,
                          ),
                          SizedBox(height: 10),
                        ],
                      ),
                    ),
                    ...item.subItems.map<Widget>((subItem) {
                      return _buildNameItem(context, subItem);
                    }),
                  ],
                );
              }
              else {
                return _buildNameItem(context, item);
              }
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return !widget.showAppBar ? _buildCircuitMenu()
        : AppPage(
      appBar: _isSearching
          ? JwLifeAppBar(
          // BARRE DE RECHERCHE CORRIGÉE
          titleWidget: SearchFieldWidget(
            query: '',

            // onSearchTextChanged: Appel du modèle pour lancer la recherche (void)
            onSearchTextChanged: (text) {
              widget.publication.wordsSuggestionsModel?.fetchSuggestions(text);
            },

            // onSuggestionTap: Utilisation de item.item.caption pour le mot suggéré
            onSuggestionTap: (item) async {
              // item.item est de type SuggestionItem (avec .caption pour le texte du mot)
              final String query = item.item!.query;
              showPage(PublicationSearchView(query: query, publication: widget.publication));
              setState(() { _isSearching = false; });
            },

            onSubmit: (text) async {
              setState(() { _isSearching = false; });
              showPage(PublicationSearchView(query: text, publication: widget.publication));
            },

            onTapOutside: (event) {
              setState(() { _isSearching = false; });
            },

            // suggestionsNotifier: Utilisation du ValueNotifier du modèle
            suggestionsNotifier: widget.publication.wordsSuggestionsModel?.suggestionsNotifier ?? ValueNotifier([]),
          ),
          handleBackPress: () {
            setState(() { _isSearching = false; });
            return false;
          },
      ) : JwLifeAppBar(
        canPop: widget.canPop,
        title: widget.publication.getShortTitle(),
        subTitle: "${widget.publication.mepsLanguage.vernacular} · ${widget.publication.keySymbol}",
        actions: [
          IconTextButton(text: i18n().action_search, icon: const Icon(JwIcons.magnifying_glass), onPressed: (anchorContext) async {
            // Initialisation du modèle lors du clic sur rechercher
            widget.publication.wordsSuggestionsModel ??= WordsSuggestionsModel(widget.publication);
            setState(() { _isSearching = true; });
          }),
          IconTextButton(text: i18n().action_bookmarks, icon: const Icon(JwIcons.bookmark), onPressed: (anchorContext) async {
            Bookmark? bookmark = await showBookmarkDialog(context, widget.publication);
            if (bookmark != null) {
              // Utilisation de ?? 0 pour éviter le '!'
              if (bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) { showPageBibleChapter(widget.publication, bookmark.location.bookNumber ?? 0, bookmark.location.chapterNumber ?? 0, firstVerse: bookmark.blockIdentifier, lastVerse: bookmark.blockIdentifier); }
              else if (bookmark.location.mepsDocumentId != null) { showPageDocument(widget.publication, bookmark.location.mepsDocumentId ?? 0, startParagraphId: bookmark.blockIdentifier, endParagraphId: bookmark.blockIdentifier); }
            }
          }),
          IconTextButton(text: i18n().action_languages, icon: const Icon(JwIcons.language), onPressed: (anchorContext) async {
            if(!widget.canPop) { showLanguagePubDialog(context, null).then((languageBible) async { if (languageBible != null) { String bibleKey = languageBible.getKey(); JwLifeSettings.instance.lookupBible.value = bibleKey; AppSharedPreferences.instance.setLookUpBible(bibleKey); } }); }
            else { showLanguagePubDialog(context, widget.publication).then((languagePub) async { if(languagePub != null) { languagePub.showMenu(context); } }); }
          }),
          //IconTextButton(text: "Ajouter un widget sur l'écran d'accueil", icon: const Icon(JwIcons.article), onPressed: (anchorContext) async { /* ... */ }),
          IconTextButton(text: i18n().action_download_media, icon: const Icon(JwIcons.cloud_arrow_down), onPressed: (anchorContext) { showDownloadMediasDialog(context, widget.publication); }),
          IconTextButton(text: i18n().action_history, icon: const Icon(JwIcons.arrow_circular_left_clock), onPressed: (anchorContext) { JwLifeApp.history.showHistoryDialog(context); }),
          IconTextButton(text: i18n().action_open_in_share, icon: const Icon(JwIcons.share), onPressed: (anchorContext) { widget.publication.shareLink(); }),
          IconTextButton(text: i18n().action_qr_code, icon: const Icon(JwIcons.qr_code), onPressed: (anchorContext) { String uri = widget.publication.shareLink(hide: true); showQrCodeDialog(context, widget.publication.getTitle(), uri); }),
        ],
      ),
      body: _buildMenu(),
    );
  }
}