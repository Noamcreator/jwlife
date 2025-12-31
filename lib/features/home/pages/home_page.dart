import 'package:flutter/material.dart';
import 'package:jwlife/app/app_page.dart';
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/features/home/widgets/home_content.dart';

import '../../../app/services/file_handler_service.dart';
import '../../../core/uri/utils_uri.dart';
import '../widgets/home_page/home_appbar.dart';
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
    const double sizeDivider = 10;
      
    return AppPage(
      appBar: HomeAppBar(
        onOpenSettings: () => showPage(SettingsPage()),
      ),
      body: RefreshIndicator(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        onRefresh: () {
          if (!AppDataService.instance.isRefreshing.value) {
            AppDataService.instance.checkUpdatesAndRefreshContent(context);
          }
          return Future.value();
        },
        child: HomeContent(
          horizontalPadding: horizontalPadding,
          sizeDivider: sizeDivider,
        ),
      )
    );
  }
}