import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import '../features/bible/pages/bible_page.dart';
import '../features/home/pages/home_page.dart' show HomePage, HomePageState;
import '../features/library/pages/library_page.dart';
import '../features/personal/pages/personal_page.dart';
import '../features/predication/pages/predication_page.dart';
import '../features/workship/pages/workship_page.dart';

/// --- HomePage Container ---
class HomePageContainer extends StatelessWidget {
  const HomePageContainer({super.key});
  @override
  Widget build(BuildContext context) {
    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: HomePage(
        key: GlobalKeyService.getKey<HomePageState>(PageType.home),
      ),
    );
  }
}

/// --- BiblePage Container ---
class BiblePageContainer extends StatelessWidget {
  const BiblePageContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: BiblePage(
        key: GlobalKeyService.getKey<BiblePageState>(PageType.bible),
      ),
    );
  }
}

/// --- LibraryPage Container ---
class LibraryPageContainer extends StatelessWidget {
  const LibraryPageContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: LibraryPage(
        key: GlobalKeyService.getKey<LibraryPageState>(PageType.library),
      ),
    );
  }
}

/// --- WorkShipPage Container ---
class WorkShipPageContainer extends StatelessWidget {
  const WorkShipPageContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: WorkShipPage(
        key: GlobalKeyService.getKey<WorkShipPageState>(PageType.workShip),
      ),
    );
  }
}

/// --- PredicationPage Container ---
class PredicationPageContainer extends StatelessWidget {
  const PredicationPageContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: PredicationPage(
        key: GlobalKeyService.getKey<PredicationPageState>(PageType.predication),
      ),
    );
  }
}

/// --- PersonalPage Container ---
class PersonalPageContainer extends StatelessWidget {
  const PersonalPageContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: PersonalPage(
        key: GlobalKeyService.getKey<PersonalPageState>(PageType.personal),
      ),
    );
  }
}
