import 'core_html_widget.dart' as core;

import 'core_widget_factory.dart';
import 'html_widget.dart';

/// A widget that builds Flutter widget tree from HTML
/// with support for IFRAME, VIDEO and many other tags.
class HtmlWidget extends core.DocumentHtmlWidget {
  /// Creates a widget that builds Flutter widget tree from html.
  ///
  /// The [html] argument must not be null.
  const HtmlWidget(
    super.html, {
    super.buildAsync,
    super.enableCaching,
    WidgetFactory Function()? factoryBuilder,
    super.key,
    super.baseUrl,
    super.customStylesBuilder,
    super.customWidgetBuilder,
    super.onErrorBuilder,
    super.onLoadingBuilder,
    super.onTapImage,
    super.onTapUrl,
    super.rebuildTriggers,
    super.renderMode,
    super.textStyle,
  }) : super(factoryBuilder: factoryBuilder ?? _getEnhancedWf);

  static WidgetFactory _getEnhancedWf() => WidgetFactory();
}
