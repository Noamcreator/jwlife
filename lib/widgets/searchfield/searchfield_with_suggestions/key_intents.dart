import 'package:flutter/material.dart';

import 'searchfield_list_item.dart';

class KCallbackAction<T extends Intent> extends CallbackAction<T> {
  KCallbackAction({required void Function(T) super.onInvoke});
}

class NextIntent extends Intent {
  final bool isTabKey;
  final bool? scrollToBottom;
  const NextIntent(this.isTabKey, {this.scrollToBottom = false});
}

// action to move to the next suggestion
class PreviousIntent extends Intent {
  final bool isTabKey;
  final bool? scrollToTop;
  const PreviousIntent(this.isTabKey, {this.scrollToTop = false});
}

// action to select the suggestion
class SelectionIntent<T> extends Intent {
  final SearchFieldListItem<T>? selectedItem;
  const SelectionIntent(this.selectedItem);
}

// action to hide the suggestions
class UnFocusIntent extends Intent {
  const UnFocusIntent();
}
