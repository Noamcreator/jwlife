import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/app_page.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/features/home/widgets/home_page/favorite_section.dart';
import 'package:jwlife/features/home/widgets/home_page/latest_medias_section.dart';

import '../../../app/services/file_handler_service.dart';
import '../../../core/uri/utils_uri.dart';
import '../widgets/home_page/alerts_banner.dart';
import '../widgets/home_page/articles_widget.dart';
import '../widgets/home_page/daily_text_widget.dart';
import '../widgets/home_page/frequently_used_section.dart';
import '../widgets/home_page/home_appbar.dart';
import '../widgets/home_page/latest_publications_section.dart';
import '../widgets/home_page/linear_progress.dart';
import '../widgets/home_page/online_section.dart';
import '../widgets/home_page/toolbox_section.dart';
import '../../settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if(JwOrgUri.startUri != null) {
        handleUri(JwOrgUri.startUri!);
        JwOrgUri.startUri = null;
      }

      FileHandlerService().processPendingContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = (screenWidth * 0.03).clamp(8.0, 40.0);

    return AppPage(
      appBar: HomeAppBar(
        onOpenSettings: () {
          showPage(SettingsPage());
        },
      ),
      body: RefreshIndicator(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        onRefresh: () async {
          if (await hasInternetConnection(context: context) && !AppDataService.instance.isRefreshing.value) {
            await AppDataService.instance.refreshContent();
          }
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgress(),
              const AlertsBanner(),
              const DailyTextWidget(),
              const ArticlesWidget(),
              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    FavoritesSection(
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        JwLifeApp.userdata.reorderFavorites(oldIndex, newIndex);
                      },
                    ),
                    const FrequentlyUsedSection(),
                    const ToolboxSection(),
                    const LatestPublicationSection(),
                    const SizedBox(height: 4),
                    const LatestMediasSection(),
                    const OnlineSection(),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}