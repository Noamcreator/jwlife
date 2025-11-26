import 'package:flutter/material.dart';
import 'package:jwlife/data/models/userdata/playlist_item.dart';
import 'package:jwlife/data/models/userdata/tag.dart';

import '../../app/jwlife_app.dart';

class TagsController extends ChangeNotifier {
  List<Tag> tags = [];

  Future<void> loadTags() async {
    tags = await JwLifeApp.userdata.fetchTags();
    notifyListeners();
  }

  Future<void> renameTag(int tagId, String name) async {
    await JwLifeApp.userdata.renameTag(tagId, 1, name);
    final index = tags.indexWhere((n) => n.id == tagId);
    if (index != -1) {
      tags[index].name = name;
    }
    notifyListeners();
  }

  Future<Tag> addTag(String name, {int? type}) async {
    Tag? tag = await JwLifeApp.userdata.addTag(name, type);
    if(tag != null) {
      tags.add(tag);
    }
    notifyListeners();

    return tag!;
  }

  Future<void> removeTag(int tagId, {int type = 1, List<PlaylistItem>? items}) async {
    await JwLifeApp.userdata.removeTag(tagId, type, items: items);
    tags.removeWhere((n) => n.id == tagId);
    notifyListeners();
  }

  void clearAll() {
    if (tags.isNotEmpty) {
      tags = [];
      notifyListeners();
    }
  }
}
