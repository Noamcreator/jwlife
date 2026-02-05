import 'package:flutter/material.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/app/services/global_key_service.dart';

class NoteController extends ChangeNotifier {
  // Instance unique (Singleton)
  static final NoteController _instance = NoteController._internal();
  factory NoteController() => _instance;
  NoteController._internal();

  String? _currentNoteGuid;
  bool _isVisible = false;

  // Getters
  String? get currentNoteguid => _currentNoteGuid;
  bool get isVisible => _isVisible && _currentNoteGuid != null;

  /// Affiche le widget avec une nouvelle note
  void show(Note note) {
    _currentNoteGuid = note.guid;
    _isVisible = true;
    
    // Met à jour la visibilité globale pour le padding
    GlobalKeyService.jwLifePageKey.currentState?.toggleNoteWidgetVisibility(true);
    
    notifyListeners();
  }

  /// Cache le widget
  void hide() {
    _isVisible = false;
    _currentNoteGuid = null;
    
    // Met à jour la visibilité globale pour le padding
    GlobalKeyService.jwLifePageKey.currentState?.toggleNoteWidgetVisibility(false);
    
    notifyListeners();
  }
}

// Instance globale facile d'accès
final noteController = NoteController();