import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import '../core/ui/app_dimens.dart';

class AppPage extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget body;
  final bool isWebview;
  final bool extendBodyBehindAppBar;
  final Widget? floatingActionButton;

  const AppPage({
    super.key,
    this.appBar,
    this.backgroundColor,
    required this.body,
    this.isWebview = false,
    this.extendBodyBehindAppBar = false,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: GlobalKeyService.jwLifePageKey.currentState!.noteWidgetVisible,
      builder: (context, noteVisible, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: GlobalKeyService.jwLifePageKey.currentState!.audioWidgetVisible,
          builder: (context, audioVisible, child) {
            final double topPadding = isWebview || extendBodyBehindAppBar ? 0 : kToolbarHeight;
            final double bottomPadding = isWebview ? 0 : (kBottomNavigationBarHeight + (audioVisible ? kAudioWidgetHeight : 0) + (noteVisible ? kNoteHeight : 0));
        
            final EdgeInsets pagePadding = EdgeInsets.only(
              top: topPadding,
              bottom: bottomPadding,
            );
        
            return MediaQuery.removeViewInsets(
                removeBottom: true, // empêche rebuild clavier
                context: context,
                child: Container(
                  color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
                  child: Stack(
                    children: [
                      /// --- CONTENU PRINCIPAL ---
                      isWebview || extendBodyBehindAppBar
                          ? Padding(
                        padding: pagePadding,
                        child: RepaintBoundary(child: body),
                      )
                          : SafeArea(
                        child: Padding(
                          padding: pagePadding,
                          child: body,
                        ),
                      ),
        
                      /// --- APPBAR OPTIONNELLE ---
                      if (appBar != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: appBar!,
                        ),
        
                      if (floatingActionButton != null)
                        PositionedDirectional(
                          bottom: kBottomNavigationBarHeight + 16,
                          end: 16,
                          child: floatingActionButton!,
                        ),
                    ],
                  ),
                )
            );
          },
        );
      }
    );
  }
}
