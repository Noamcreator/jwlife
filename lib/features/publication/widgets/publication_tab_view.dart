import 'package:flutter/material.dart';

import '../models/menu/local/tab_items.dart';

class PublicationTabView extends StatefulWidget {
  final TabWithItems tab;
  final Widget Function(BuildContext, TabWithItems) builder;

  const PublicationTabView({
    super.key,
    required this.tab,
    required this.builder,
  });

  @override
  State<PublicationTabView> createState() => _PublicationTabViewState();
}

class _PublicationTabViewState extends State<PublicationTabView>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.builder(context, widget.tab);
  }
}
