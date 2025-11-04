import 'dart:typed_data';

import 'package:jwlife/data/models/publication.dart';

class Multimedia {
  final int id;
  int? linkMultimediaId;
  int dataType;
  int majorType;
  int minorType;
  int? width;
  int? height;
  String mimeType;
  String label;
  String? labelRich;
  String caption;
  String? captionRich;
  Uint8List? captionContent;
  String creditLine;
  String? creditLineRich;
  Uint8List? creditLineContent;
  int categoryType;
  String filePath;
  String? keySymbol;
  int? track;
  int? mepsDocumentId;
  int? mepsLanguageId;
  int issueTagNumber;
  bool hasSuppressZoom;
  String? sizeConstraint;
  int? beginParagraphOrdinal;
  int? endParagraphOrdinal;

  Multimedia({
    required this.id,
    this.linkMultimediaId,
    this.dataType = 0,
    this.majorType = 0,
    this.minorType = 0,
    this.width,
    this.height,
    this.mimeType = '',
    this.label = '',
    this.labelRich,
    this.caption = '',
    this.captionRich,
    this.captionContent,
    this.creditLine = '',
    this.creditLineRich,
    this.creditLineContent,
    this.categoryType = 0,
    this.filePath = '',
    this.keySymbol,
    this.track,
    this.mepsDocumentId,
    this.mepsLanguageId,
    this.issueTagNumber = 0,
    this.hasSuppressZoom = false,
    this.sizeConstraint,
    required this.beginParagraphOrdinal,
    required this.endParagraphOrdinal,
  });

  factory Multimedia.fromMap(Map<String, dynamic> map) {
    return Multimedia(
      id: map['MultimediaId'] ?? 0,
      linkMultimediaId: map['LinkMultimediaId'],
      dataType: map['DataType'] ?? 0,
      majorType: map['MajorType'] ?? 0,
      minorType: map['MinorType'] ?? 0,
      width: map['Width'],
      height: map['Height'],
      mimeType: map['MimeType'] ?? '',
      label: map['Label'] ?? '',
      labelRich: map['LabelRich'],
      caption: map['Caption'] ?? '',
      captionRich: map['CaptionRich'],
      captionContent: map['CaptionContent'],
      creditLine: map['CreditLine'] ?? '',
      creditLineRich: map['CreditLineRich'],
      creditLineContent: map['CreditLineContent'],
      categoryType: map['CategoryType'] ?? 0,
      filePath: map['FilePath'] ?? '',
      keySymbol: map['KeySymbol']?.toString().toLowerCase(),
      track: map['Track'],
      mepsDocumentId: map['MepsDocumentId'],
      mepsLanguageId: map['MepsLanguageIndex'],
      issueTagNumber: map['IssueTagNumber'] ?? 0,
      hasSuppressZoom: map['SuppressZoom'] == 1 ? true : false,
      sizeConstraint: map['SizeConstraint'],
      beginParagraphOrdinal: map['BeginParagraphOrdinal'],
      endParagraphOrdinal: map['EndParagraphOrdinal'],
    );
  }

  String? getImage(Publication publication) {
    String? pubPath = publication.path;
    return pubPath == null ? null : "$pubPath/$filePath";
  }
}
