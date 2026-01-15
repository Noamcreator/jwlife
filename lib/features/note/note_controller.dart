import 'package:flutter/material.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/app/services/global_key_service.dart';

class NoteController extends ChangeNotifier {
  // Instance unique (Singleton)
  static final NoteController _instance = NoteController._internal();
  factory NoteController() => _instance;
  NoteController._internal();

  Note? _currentNote;
  bool _isVisible = false;

  // Getters
  Note? get note => _currentNote;
  bool get isVisible => _isVisible && _currentNote != null;

  /// Affiche le widget avec une nouvelle note
  void show(Note note) {
    _currentNote = note;
    _isVisible = true;
    
    // Met à jour la visibilité globale pour le padding
    GlobalKeyService.jwLifePageKey.currentState?.toggleNoteWidgetVisibility(true);
    
    notifyListeners();
  }

  /// Cache le widget
  void hide() {
    _isVisible = false;
    _currentNote = null;
    
    // Met à jour la visibilité globale pour le padding
    GlobalKeyService.jwLifePageKey.currentState?.toggleNoteWidgetVisibility(false);
    
    notifyListeners();
  }
}

// Instance globale facile d'accès
final noteController = NoteController();