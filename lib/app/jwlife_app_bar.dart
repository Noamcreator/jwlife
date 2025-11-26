import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/ui/text_styles.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import '../core/icons.dart';

class JwLifeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final String? subTitle;
  final Widget? subTitleWidget;
  final List<IconTextButton>? actions;
  final Function()? handleBackPress;
  final bool? canPop;
  final Color? iconsColor;
  final Color? backgroundColor;

  const JwLifeAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.subTitle,
    this.subTitleWidget,
    this.handleBackPress,
    this.actions,
    this.canPop,
    this.iconsColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool canPopState = canPop ?? Navigator.of(context).canPop();

    final textStyleTitle = Theme.of(context).extension<JwLifeThemeStyles>()!.appBarTitle;
    final textStyleSubtitle = Theme.of(context).extension<JwLifeThemeStyles>()!.appBarSubTitle;

    return AppBar(
      backgroundColor: backgroundColor,
      scrolledUnderElevation: 0,
      actionsPadding: const EdgeInsets.only(left: 10, right: 5),
      leading: canPopState == true ? IconButton(
        icon: Icon(JwIcons.chevron_left, color: iconsColor ?? Theme.of(context).iconTheme.color),
        onPressed: () {
          handleBackPress?.call() ?? GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
        },
      ) : null,
      title: subTitle != null || subTitleWidget != null ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget ?? Text(title, style: textStyleTitle),
          subTitleWidget ?? Text(subTitle!, style: textStyleSubtitle),
        ],
      ) : Text(title, style: textStyleTitle),
      titleSpacing: canPopState ? 0.0 : null,
      actions: actions != null ? [ResponsiveAppBarActions(allActions: actions!, canPop: canPopState, iconsColor: iconsColor)] : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}