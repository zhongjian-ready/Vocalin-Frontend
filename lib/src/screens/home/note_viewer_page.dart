import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../../models/post.dart';

class NoteViewerPage extends StatelessWidget {
  const NoteViewerPage({
    super.key,
    required this.note,
  });

  final Post note;

  Stylesheet get _stylesheet => defaultStylesheet.copyWith(
        documentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        addRulesAfter: [
          StyleRule(
            BlockSelector.all,
            (doc, docNode) {
              return {
                'maxWidth': 640.0,
                'padding': const CascadingPadding.symmetric(horizontal: 0),
                'textStyle': const TextStyle(
                  color: Colors.black,
                  fontSize: 19,
                  height: 1.6,
                ),
              };
            },
          ),
          StyleRule(
            const BlockSelector('header1'),
            (doc, docNode) {
              return {
                'padding': const CascadingPadding.only(top: 28),
                'textStyle': const TextStyle(
                  color: Color(0xFF2E241D),
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              };
            },
          ),
          StyleRule(
            const BlockSelector('paragraph'),
            (doc, docNode) {
              return {
                'padding': const CascadingPadding.only(top: 16),
              };
            },
          ),
          StyleRule(
            const BlockSelector('paragraph').after('header1'),
            (doc, docNode) {
              return {
                'padding': const CascadingPadding.only(top: 4),
              };
            },
          ),
          StyleRule(
            const BlockSelector('listItem'),
            (doc, docNode) {
              return {
                'padding': const CascadingPadding.only(top: 14),
              };
            },
          ),
          StyleRule(
            const BlockSelector('code'),
            (doc, docNode) {
              return {
                'padding': const CascadingPadding.only(top: 16),
                'textStyle': const TextStyle(
                  color: Color(0xFF45352B),
                  fontSize: 17,
                  height: 1.6,
                  fontFamily: 'monospace',
                ),
              };
            },
          ),
        ],
      );

  Document _parseDocument() {
    final serializedContent = note.formattedContent?.trim();
    if (serializedContent == null || serializedContent.isEmpty) {
      return MutableDocument(
        nodes: [
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText(note.content ?? ''),
          ),
        ],
      );
    }

    try {
      final decoded = jsonDecode(serializedContent);
      if (decoded is! Map) {
        return MutableDocument(
          nodes: [
            ParagraphNode(
              id: DocumentEditor.createNodeId(),
              text: AttributedText(note.content ?? ''),
            ),
          ],
        );
      }

      final rawNodes = decoded['nodes'];
      if (rawNodes is! List) {
        return MutableDocument(
          nodes: [
            ParagraphNode(
              id: DocumentEditor.createNodeId(),
              text: AttributedText(note.content ?? ''),
            ),
          ],
        );
      }

      final nodes = <DocumentNode>[];
      for (final rawNode in rawNodes) {
        if (rawNode is! Map) {
          continue;
        }

        final nodeMap = rawNode.map(
          (key, dynamic value) => MapEntry(key.toString(), value),
        );
        final nodeType = nodeMap['type'];

        if (nodeType == 'image') {
          final imageUrl = (nodeMap['imageUrl'] as String?)?.trim();
          if (imageUrl != null && imageUrl.isNotEmpty) {
            nodes.add(
              ImageNode(
                id: DocumentEditor.createNodeId(),
                imageUrl: imageUrl,
                altText: (nodeMap['altText'] as String?) ?? '',
              ),
            );
          }
          continue;
        }

        final text = _parseAttributedText(nodeMap);

        if (nodeType == 'listItem') {
          final listType = (nodeMap['listType'] as String?) == 'ordered'
              ? ListItemType.ordered
              : ListItemType.unordered;
          final prefix = listType == ListItemType.ordered ? '1. ' : '• ';
          nodes.add(
            ParagraphNode(
              id: DocumentEditor.createNodeId(),
              text: text.insertString(textToInsert: prefix, startOffset: 0),
            ),
          );
          continue;
        }

        final metadata = <String, dynamic>{};
        switch (nodeMap['blockType']) {
          case 'header1':
            metadata['blockType'] = header1Attribution;
            break;
          case 'blockquote':
            metadata['blockType'] = blockquoteAttribution;
            break;
          case 'code':
            metadata['blockType'] = codeAttribution;
            break;
        }

        nodes.add(
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: text,
            metadata: metadata,
          ),
        );
      }

      if (nodes.isEmpty) {
        nodes.add(
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText(''),
          ),
        );
      }

      return MutableDocument(nodes: nodes);
    } catch (_) {
      return MutableDocument(
        nodes: [
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText(note.content ?? ''),
          ),
        ],
      );
    }
  }

  AttributedText _parseAttributedText(Map<String, dynamic> nodeMap) {
    final text = AttributedText((nodeMap['text'] as String?) ?? '');
    final spans = nodeMap['spans'];
    if (spans is! List) {
      return text;
    }

    for (final span in spans) {
      if (span is! Map) {
        continue;
      }

      final spanMap = span.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
      final attribution = switch (spanMap['attribution']) {
        'bold' => boldAttribution,
        'italics' => italicsAttribution,
        'underline' => underlineAttribution,
        'strikethrough' => strikethroughAttribution,
        'code' => codeAttribution,
        'link' => _parseLinkAttribution(spanMap['url'] as String?),
        _ => null,
      };
      final start = (spanMap['start'] as num?)?.toInt();
      final end = (spanMap['end'] as num?)?.toInt();
      if (attribution == null || start == null || end == null) {
        continue;
      }

      text.addAttribution(attribution, SpanRange(start, end));
    }

    return text;
  }

  LinkAttribution? _parseLinkAttribution(String? rawUrl) {
    final url = rawUrl?.trim();
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    return LinkAttribution(url: uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final updatedAt = note.updatedAt;
    final content = _parseDocument();
    final title = note.title?.trim().isEmpty ?? true
        ? 'Untitled Note'
        : note.title!.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F3EC),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: titleStyle),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${updatedAt.month}月${updatedAt.day}日 ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF8A8175),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                child: SingleColumnDocumentLayout(
                  presenter: SingleColumnLayoutPresenter(
                    document: content,
                    componentBuilders: defaultComponentBuilders,
                    pipeline: [
                      SingleColumnStylesheetStyler(stylesheet: _stylesheet),
                    ],
                  ),
                  componentBuilders: defaultComponentBuilders,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
