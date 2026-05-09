import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_editor/super_editor.dart';

import '../../models/post.dart';
import '../../services/data_service.dart';
import 'record_delete_confirmation_dialog.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({
    super.key,
    this.note,
    this.startInEditMode,
  });

  final Post? note;
  final bool? startInEditMode;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  static const _unorderedListPrefix = '• ';
  static const _paragraphAttribution = NamedAttribution('paragraph');

  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  late final MutableDocument _document;
  late final DocumentEditor _documentEditor;
  late final DocumentComposer _composer;
  late final GlobalKey _documentLayoutKey;
  late final FocusNode _editorFocusNode;
  DocumentSelection? _lastDocumentSelection;
  final List<_NoteEditorSnapshot> _history = [];
  late bool _isShared;
  late bool _isEditing;
  int? _selectedGroupId;
  int _historyIndex = -1;
  bool _isSubmitting = false;
  bool _isApplyingAutomaticListContinuation = false;
  bool _isRestoringHistory = false;
  bool _isToolbarExpanded = false;
  late List<String> _knownDocumentNodeIds;

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _titleFocusNode = FocusNode();
    _document = _createInitialDocument(widget.note);
    _knownDocumentNodeIds = _document.nodes.map((node) => node.id).toList();
    _document.addListener(_handleDocumentChanged);
    _documentEditor = DocumentEditor(document: _document);
    _composer = DocumentComposer();
    _documentLayoutKey = GlobalKey();
    _composer.addListener(_handleComposerChanged);
    _editorFocusNode = FocusNode();
    _titleController.addListener(_handleTitleChanged);
    _isShared = widget.note?.isShared ?? true;
    _isEditing = widget.startInEditMode ?? widget.note == null;
    _recordHistorySnapshot(force: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedGroupId != null || widget.note?.groupId != null) {
      return;
    }

    _selectedGroupId = context.read<DataService>().currentGroup?.id;
  }

  @override
  void dispose() {
    _document.removeListener(_handleDocumentChanged);
    _composer.removeListener(_handleComposerChanged);
    _titleController.removeListener(_handleTitleChanged);
    _titleController.dispose();
    _titleFocusNode.dispose();
    _composer.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  bool get _canUndo => _historyIndex > 0;

  bool get _canRedo =>
      _historyIndex >= 0 && _historyIndex < _history.length - 1;

  void _handleDocumentChanged() {
    final previousNodeIds = List<String>.from(_knownDocumentNodeIds);
    _knownDocumentNodeIds = _document.nodes.map((node) => node.id).toList();

    if (!_isRestoringHistory && !_isApplyingAutomaticListContinuation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _continueListAfterParagraphSplit(previousNodeIds);
      });
    }

    if (!_isRestoringHistory) {
      _recordHistorySnapshot();
    }

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _handleTitleChanged() {
    if (_isRestoringHistory) {
      return;
    }

    _recordHistorySnapshot();
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _recordHistorySnapshot({bool force = false}) {
    final snapshot = _createHistorySnapshot();
    if (!force &&
        _historyIndex >= 0 &&
        _history[_historyIndex].hasSameContent(snapshot)) {
      return;
    }

    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(snapshot);
    _historyIndex = _history.length - 1;
  }

  _NoteEditorSnapshot _createHistorySnapshot() {
    return _NoteEditorSnapshot(
      title: _titleController.text,
      titleSelection: _titleController.selection,
      serializedDocument: _serializeDocument(),
      documentSelection: _DocumentSelectionSnapshot.fromSelection(
        _composer.selection ?? _lastDocumentSelection,
        _document,
      ),
    );
  }

  void _undo() {
    if (!_canUndo) {
      return;
    }

    _historyIndex -= 1;
    _restoreHistorySnapshot(_history[_historyIndex]);
  }

  void _redo() {
    if (!_canRedo) {
      return;
    }

    _historyIndex += 1;
    _restoreHistorySnapshot(_history[_historyIndex]);
  }

  void _restoreHistorySnapshot(_NoteEditorSnapshot snapshot) {
    final shouldFocusTitle = _titleFocusNode.hasFocus;

    _isRestoringHistory = true;
    try {
      _titleController.value = TextEditingValue(
        text: snapshot.title,
        selection: _clampTextSelection(
          snapshot.titleSelection,
          snapshot.title.length,
        ),
      );

      final restoredDocument =
          _deserializeDocument(snapshot.serializedDocument);
      _documentEditor.executeCommand(
        EditorCommandFunction((document, transaction) {
          final currentNodes = List<DocumentNode>.from(document.nodes);
          for (final node in currentNodes.reversed) {
            transaction.deleteNode(node);
          }

          for (var index = 0;
              index < restoredDocument.nodes.length;
              index += 1) {
            transaction.insertNodeAt(index, restoredDocument.nodes[index]);
          }
        }),
      );

      _knownDocumentNodeIds = _document.nodes.map((node) => node.id).toList();
      _composer.selection = snapshot.documentSelection?.toSelection(_document);
      _lastDocumentSelection = _composer.selection;
    } finally {
      _isRestoringHistory = false;
    }

    if (shouldFocusTitle) {
      _titleFocusNode.requestFocus();
    } else {
      _editorFocusNode.requestFocus();
    }

    setState(() {});
  }

  TextSelection _clampTextSelection(TextSelection selection, int textLength) {
    return TextSelection(
      baseOffset: math.min(selection.baseOffset, textLength),
      extentOffset: math.min(selection.extentOffset, textLength),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  ListItemType? _listTypeForText(String text) {
    if (text.startsWith(_unorderedListPrefix)) {
      return ListItemType.unordered;
    }

    if (RegExp(r'^\d+\.\s+').hasMatch(text)) {
      return ListItemType.ordered;
    }

    return null;
  }

  int _orderedListOrdinal(String text) {
    final match = RegExp(r'^(\d+)\.\s+').firstMatch(text);
    return int.tryParse(match?.group(1) ?? '') ?? 1;
  }

  void _continueListAfterParagraphSplit(List<String> previousNodeIds) {
    final selection = _composer.selection;
    if (selection == null || !selection.isCollapsed) {
      return;
    }

    final selectedNode = _document.getNodeById(selection.extent.nodeId);
    if (selectedNode is! ParagraphNode) {
      return;
    }

    if (previousNodeIds.contains(selectedNode.id)) {
      return;
    }

    final previousNode = _document.getNodeBefore(selectedNode);
    if (previousNode is! TextNode) {
      return;
    }

    final listType = _listTypeForText(previousNode.text.text);
    if (listType == null) {
      return;
    }

    final prefix = listType == ListItemType.ordered
        ? _orderedListPrefix(_orderedListOrdinal(previousNode.text.text) + 1)
        : _unorderedListPrefix;

    _isApplyingAutomaticListContinuation = true;
    try {
      selectedNode.putMetadataValue('blockType', _paragraphAttribution);
      selectedNode.text = _removeListPrefixFromText(selectedNode.text)
          .insertString(textToInsert: prefix, startOffset: 0);
      _composer.selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: selectedNode.id,
          nodePosition: TextNodePosition(offset: prefix.length),
        ),
      );
    } finally {
      _isApplyingAutomaticListContinuation = false;
    }
  }

  void _handleComposerChanged() {
    final selection = _composer.selection;
    if (selection == null) {
      return;
    }

    if (_editorFocusNode.hasFocus) {
      _lastDocumentSelection = selection;
    }
  }

  void _rememberCurrentSelection() {
    final selection = _composer.selection;
    if (selection != null) {
      _lastDocumentSelection = selection;
    }
  }

  DocumentSelection? _resolveActiveSelection() {
    if (_editorFocusNode.hasFocus && _composer.selection != null) {
      return _composer.selection;
    }

    return _lastDocumentSelection ?? _composer.selection;
  }

  TextNode? _resolveActiveTextNode() {
    final selection = _resolveActiveSelection();
    if (selection == null) {
      return null;
    }

    final selectedNode = _document.getNodeById(selection.extent.nodeId);
    if (selectedNode is! TextNode) {
      return null;
    }

    if (selectedNode.text.text.trim().isNotEmpty) {
      return selectedNode;
    }

    DocumentNode? candidate = _document.getNodeBefore(selectedNode);
    while (candidate != null) {
      if (candidate is TextNode && candidate.text.text.trim().isNotEmpty) {
        return candidate;
      }
      candidate = _document.getNodeBefore(candidate);
    }

    return selectedNode;
  }

  String _orderedListPrefix([int ordinal = 1]) => '$ordinal. ';

  int _listPrefixLength(String text) {
    if (text.startsWith(_unorderedListPrefix)) {
      return _unorderedListPrefix.length;
    }

    final orderedPrefix = RegExp(r'^\d+\.\s+').firstMatch(text);
    return orderedPrefix?.end ?? 0;
  }

  AttributedText _removeListPrefixFromText(AttributedText text) {
    final prefixLength = _listPrefixLength(text.text);
    if (prefixLength == 0) {
      return text;
    }

    return text.removeRegion(startOffset: 0, endOffset: prefixLength);
  }

  AttributedText _applyListPrefixToText(
    AttributedText text,
    ListItemType listType,
  ) {
    final normalizedText = _removeListPrefixFromText(text);
    final prefix = listType == ListItemType.ordered
        ? _orderedListPrefix()
        : _unorderedListPrefix;
    return normalizedText.insertString(textToInsert: prefix, startOffset: 0);
  }

  void _updateSelectionForPrefixChange({
    required String nodeId,
    required int removedCharacters,
    required int insertedCharacters,
  }) {
    final selection = _resolveActiveSelection();
    if (selection == null) {
      return;
    }

    TextNodePosition? adjust(NodePosition position) {
      if (position is! TextNodePosition) {
        return null;
      }

      final adjustedOffset = math.max(
        0,
        position.offset - removedCharacters + insertedCharacters,
      );
      return TextNodePosition(
        offset: adjustedOffset,
        affinity: position.affinity,
      );
    }

    final basePosition = adjust(selection.base.nodePosition);
    final extentPosition = adjust(selection.extent.nodePosition);
    if (basePosition == null || extentPosition == null) {
      return;
    }

    _composer.selection = DocumentSelection(
      base: DocumentPosition(nodeId: nodeId, nodePosition: basePosition),
      extent: DocumentPosition(nodeId: nodeId, nodePosition: extentPosition),
    );
  }

  MutableDocument _createInitialDocument(Post? note) {
    final serializedDocument = note?.formattedContent?.trim();
    if (serializedDocument != null && serializedDocument.isNotEmpty) {
      try {
        final restored = _deserializeDocument(serializedDocument);
        if (restored.nodes.isNotEmpty) {
          return restored;
        }
      } catch (_) {}
    }

    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(note?.content?.trim() ?? ''),
        ),
      ],
    );
  }

  MutableDocument _deserializeDocument(String serialized) {
    final dynamic decoded = jsonDecode(serialized);
    if (decoded is! Map) {
      throw const FormatException('Invalid note document payload.');
    }

    final rawNodes = decoded['nodes'];
    if (rawNodes is! List) {
      throw const FormatException('Invalid note document nodes.');
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

      final text = _deserializeAttributedText(nodeMap);

      if (nodeType == 'listItem') {
        final listType = (nodeMap['listType'] as String?) == 'ordered'
            ? ListItemType.ordered
            : ListItemType.unordered;
        nodes.add(
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: _applyListPrefixToText(text, listType),
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
  }

  AttributedText _deserializeAttributedText(Map<String, dynamic> nodeMap) {
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
        'link' => _deserializeLinkAttribution(spanMap['url'] as String?),
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

  LinkAttribution? _deserializeLinkAttribution(String? rawUrl) {
    final url = rawUrl?.trim();
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    if (!_isSupportedAbsoluteUri(uri)) {
      return null;
    }

    return LinkAttribution(url: uri!);
  }

  String _serializeDocument() {
    final nodes = _document.nodes.map(_serializeNode).toList(growable: false);
    return jsonEncode({'version': 1, 'nodes': nodes});
  }

  Map<String, dynamic> _serializeNode(DocumentNode node) {
    if (node is ImageNode) {
      return {
        'type': 'image',
        'imageUrl': node.imageUrl,
        'altText': node.altText,
      };
    }

    if (node is ListItemNode) {
      return {
        'type': 'listItem',
        'listType': node.type == ListItemType.ordered ? 'ordered' : 'unordered',
        'indent': node.indent,
        ..._serializeTextNode(node),
      };
    }

    if (node is ParagraphNode) {
      final blockType = node.getMetadataValue('blockType');
      return {
        'type': 'paragraph',
        'blockType': switch (blockType) {
          final value when value == header1Attribution => 'header1',
          final value when value == blockquoteAttribution => 'blockquote',
          final value when value == codeAttribution => 'code',
          _ => 'paragraph',
        },
        ..._serializeTextNode(node),
      };
    }

    return {
      'type': 'paragraph',
      'blockType': 'paragraph',
      'text': '',
      'spans': const <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic> _serializeTextNode(TextNode node) {
    final spans = <Map<String, dynamic>>[];
    final text = node.text;

    for (final attribution in const [
      boldAttribution,
      italicsAttribution,
      underlineAttribution,
      strikethroughAttribution,
      codeAttribution,
    ]) {
      final attributionSpans = text.getAttributionSpans({attribution});
      for (final span in attributionSpans) {
        spans.add({
          'attribution': attribution.id,
          'start': span.start,
          'end': span.end,
        });
      }
    }

    final linkSpans = text.getAttributionSpansByFilter(
      (attribution) => attribution is LinkAttribution,
    );
    for (final span in linkSpans) {
      final linkAttribution = span.attribution;
      if (linkAttribution is! LinkAttribution) {
        continue;
      }

      spans.add({
        'attribution': linkAttribution.id,
        'url': linkAttribution.url.toString(),
        'start': span.start,
        'end': span.end,
      });
    }

    spans.sort((first, second) {
      final startCompare = ((first['start'] as int?) ?? 0)
          .compareTo((second['start'] as int?) ?? 0);
      if (startCompare != 0) {
        return startCompare;
      }

      return ((first['end'] as int?) ?? 0)
          .compareTo((second['end'] as int?) ?? 0);
    });

    return {
      'text': text.text,
      'spans': spans,
    };
  }

  String _plainTextSummary() {
    final buffer = StringBuffer();
    for (final node in _document.nodes) {
      if (node is TextNode) {
        final value = node.text.text.trim();
        if (value.isNotEmpty) {
          if (buffer.isNotEmpty) {
            buffer.writeln();
          }
          buffer.write(value);
        }
      } else if (node is ImageNode) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
        }
        final altText = node.altText.trim();
        buffer.write(altText.isEmpty ? '[Image]' : altText);
      }
    }
    return buffer.toString().trim();
  }

  int get _plainTextLength => _plainTextSummary().characters.length;

  void _enterEditMode({required bool focusContent}) {
    if (!_isEditing) {
      setState(() {
        _isEditing = true;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (focusContent) {
        _editorFocusNode.requestFocus();
      } else {
        _titleFocusNode.requestFocus();
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final serializedDocument = _serializeDocument();
    final summary = _plainTextSummary();
    if (title.isEmpty || summary.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final wrappedContent = encodeRichNoteContent(
      title: title,
      body: serializedDocument,
      summary: summary,
      groupId: _selectedGroupId,
    );

    try {
      if (widget.note == null) {
        await context.read<DataService>().addPost(
              Post(
                id: 0,
                type: PostType.note,
                title: title,
                content: wrappedContent,
                formattedContent: serializedDocument,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                color: 'yellow',
                isShared: _isShared,
                groupId: _selectedGroupId,
              ),
            );

        if (!mounted) {
          return;
        }

        Navigator.of(context).pop(true);
        return;
      }

      await context.read<DataService>().updateNote(
            widget.note!.id,
            title: title,
            content: wrappedContent,
            isShared: _isShared,
            groupId: _selectedGroupId,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _updateExistingNote({bool showSavedMessage = false}) async {
    if (widget.note == null || _isSubmitting) {
      return;
    }

    final title = _titleController.text.trim();
    final serializedDocument = _serializeDocument();
    final summary = _plainTextSummary();
    if (title.isEmpty || summary.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<DataService>().updateNote(
            widget.note!.id,
            title: title,
            content: encodeRichNoteContent(
              title: title,
              body: serializedDocument,
              summary: summary,
              groupId: _selectedGroupId,
            ),
            isShared: _isShared,
            groupId: _selectedGroupId,
          );

      if (!mounted || !showSavedMessage) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note updated.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _toggleVisibility() async {
    if (widget.note == null || _isSubmitting) {
      return;
    }

    setState(() {
      _isShared = !_isShared;
    });

    await _updateExistingNote();
  }

  Future<void> _moveToFolder() async {
    if (widget.note == null || _isSubmitting) {
      return;
    }

    final dataService = context.read<DataService>();
    if (dataService.isSharedNoteFromOtherUser(widget.note!)) {
      return;
    }

    final selectedFolder = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) {
        final folders = dataService.noteFoldersForCurrentGroup;
        final currentFolder = dataService.noteFolderNameFor(widget.note!.id);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Move To')),
              _FolderSelectionTile(
                title: 'All',
                selected: currentFolder == null,
                onTap: () => Navigator.of(context).pop<String?>(null),
              ),
              for (final folder in folders)
                _FolderSelectionTile(
                  title: folder,
                  selected: currentFolder == folder,
                  onTap: () => Navigator.of(context).pop<String?>(folder),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    final currentFolder = dataService.noteFolderNameFor(widget.note!.id);
    if (selectedFolder == currentFolder) {
      return;
    }

    dataService.moveNoteToFolder(widget.note!.id, selectedFolder);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedFolder == null
              ? 'Moved to All.'
              : 'Moved to $selectedFolder.',
        ),
      ),
    );
  }

  Future<void> _deleteNote() async {
    if (widget.note == null || _isSubmitting) {
      return;
    }

    final shouldDelete = await showRecordDeleteConfirmationDialog(
      context,
      title: 'Delete Note',
      message: 'Delete this note permanently?',
    );
    if (!shouldDelete || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<DataService>().deleteNote(widget.note!.id);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _toggleBold() {
    final selection = _resolveActiveSelection();
    if (selection == null || selection.isCollapsed) {
      return;
    }

    _documentEditor.executeCommand(
      ToggleTextAttributionsCommand(
        documentSelection: selection,
        attributions: {boldAttribution},
      ),
    );
    _editorFocusNode.requestFocus();
    setState(() {});
  }

  void _toggleItalic() {
    final selection = _resolveActiveSelection();
    if (selection == null || selection.isCollapsed) {
      return;
    }

    _documentEditor.executeCommand(
      ToggleTextAttributionsCommand(
        documentSelection: selection,
        attributions: {italicsAttribution},
      ),
    );
    _editorFocusNode.requestFocus();
    setState(() {});
  }

  void _toggleUnderline() {
    final selection = _resolveActiveSelection();
    if (selection == null || selection.isCollapsed) {
      return;
    }

    _documentEditor.executeCommand(
      ToggleTextAttributionsCommand(
        documentSelection: selection,
        attributions: {underlineAttribution},
      ),
    );
    _editorFocusNode.requestFocus();
    setState(() {});
  }

  void _toggleStrikethrough() {
    final selection = _resolveActiveSelection();
    if (selection == null || selection.isCollapsed) {
      return;
    }

    _documentEditor.executeCommand(
      ToggleTextAttributionsCommand(
        documentSelection: selection,
        attributions: {strikethroughAttribution},
      ),
    );
    _editorFocusNode.requestFocus();
    setState(() {});
  }

  void _convertToHeader() {
    final selectedNode = _resolveActiveTextNode();
    if (selectedNode == null) {
      return;
    }

    if (selectedNode is ParagraphNode) {
      final prefixLength = _listPrefixLength(selectedNode.text.text);
      selectedNode.text = _removeListPrefixFromText(selectedNode.text);
      selectedNode.putMetadataValue('blockType', header1Attribution);
      _updateSelectionForPrefixChange(
        nodeId: selectedNode.id,
        removedCharacters: prefixLength,
        insertedCharacters: 0,
      );
    } else if (selectedNode is ListItemNode) {
      _documentEditor.executeCommand(
        ConvertListItemToParagraphCommand(
          nodeId: selectedNode.id,
          paragraphMetadata: {'blockType': header1Attribution},
        ),
      );
    }
    _editorFocusNode.requestFocus();
    setState(() {});
  }

  void _convertToParagraph() {
    final selectedNode = _resolveActiveTextNode();
    if (selectedNode == null) {
      return;
    }

    if (selectedNode is ParagraphNode) {
      final prefixLength = _listPrefixLength(selectedNode.text.text);
      selectedNode.text = _removeListPrefixFromText(selectedNode.text);
      selectedNode.putMetadataValue('blockType', _paragraphAttribution);
      _updateSelectionForPrefixChange(
        nodeId: selectedNode.id,
        removedCharacters: prefixLength,
        insertedCharacters: 0,
      );
    } else if (selectedNode is ListItemNode) {
      _documentEditor.executeCommand(
        ConvertListItemToParagraphCommand(
          nodeId: selectedNode.id,
          paragraphMetadata: const {},
        ),
      );
    }
    _editorFocusNode.requestFocus();
    setState(() {});
  }

  void _convertToUnorderedList() {
    _convertToList(ListItemType.unordered);
  }

  void _convertToOrderedList() {
    _convertToList(ListItemType.ordered);
  }

  void _convertToBlockquote() {
    _convertToBlockType(blockquoteAttribution);
  }

  void _convertToCodeBlock() {
    _convertToBlockType(codeAttribution);
  }

  void _convertToBlockType(Attribution blockType) {
    final selectedNode = _resolveActiveTextNode();
    if (selectedNode == null) {
      return;
    }

    if (selectedNode is ParagraphNode) {
      final prefixLength = _listPrefixLength(selectedNode.text.text);
      selectedNode.text = _removeListPrefixFromText(selectedNode.text);
      selectedNode.putMetadataValue('blockType', blockType);
      _updateSelectionForPrefixChange(
        nodeId: selectedNode.id,
        removedCharacters: prefixLength,
        insertedCharacters: 0,
      );
    } else if (selectedNode is ListItemNode) {
      _documentEditor.executeCommand(
        ConvertListItemToParagraphCommand(
          nodeId: selectedNode.id,
          paragraphMetadata: {'blockType': blockType},
        ),
      );
    }

    _editorFocusNode.requestFocus();
    setState(() {});
  }

  Future<void> _insertLink() async {
    final selection = _resolveSingleTextNodeSelection();
    if (selection == null) {
      _showToolbarMessage('Select text in one paragraph to add a link.');
      return;
    }

    final range = _trimSelectionWhitespace(
      selection.textNode.text,
      startOffset: selection.startOffset,
      endOffsetExclusive: selection.endOffset,
    );
    if (range == null) {
      _showToolbarMessage('Select some text before adding a link.');
      return;
    }

    final url = await _showToolbarUrlDialog(
      title: 'Add Link',
      hintText: 'https://example.com',
      confirmLabel: 'Apply',
    );
    if (!mounted || url == null) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (!_isSupportedAbsoluteUri(uri)) {
      _showToolbarMessage('Enter a valid link URL.');
      return;
    }

    final overlappingLinks = selection.textNode.text.getAttributionSpansInRange(
      attributionFilter: (attribution) => attribution is LinkAttribution,
      range: range,
    );
    for (final linkSpan in overlappingLinks) {
      selection.textNode.text.removeAttribution(
        linkSpan.attribution,
        SpanRange(linkSpan.start, linkSpan.end),
      );
    }

    selection.textNode.text.addAttribution(
      LinkAttribution(url: uri!),
      range,
    );
    _editorFocusNode.requestFocus();
    setState(() {});
  }

  Future<void> _insertImage() async {
    final imageUrl = await _showToolbarUrlDialog(
      title: 'Insert Image',
      hintText: 'https://example.com/image.jpg',
      confirmLabel: 'Insert',
    );
    if (!mounted || imageUrl == null) {
      return;
    }

    final uri = Uri.tryParse(imageUrl);
    if (!_isSupportedAbsoluteUri(uri)) {
      _showToolbarMessage('Enter a valid image URL.');
      return;
    }

    final selection = _resolveActiveSelection();
    final selectedNode = selection == null
        ? null
        : _document.getNodeById(selection.extent.nodeId);
    final imageNode = ImageNode(
      id: DocumentEditor.createNodeId(),
      imageUrl: imageUrl,
    );
    final trailingParagraph = ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(''),
    );

    _documentEditor.executeCommand(
      EditorCommandFunction((document, transaction) {
        if (selectedNode is TextNode && selectedNode.text.text.trim().isEmpty) {
          final nodeIndex = document.nodes.indexOf(selectedNode);
          transaction.deleteNode(selectedNode);
          transaction.insertNodeAt(nodeIndex, imageNode);
          transaction.insertNodeAt(nodeIndex + 1, trailingParagraph);
          return;
        }

        final insertionIndex = selectedNode == null
            ? document.nodes.length
            : document.nodes.indexOf(selectedNode) + 1;
        transaction.insertNodeAt(insertionIndex, imageNode);
        transaction.insertNodeAt(insertionIndex + 1, trailingParagraph);
      }),
    );

    _composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: trailingParagraph.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    );
    _editorFocusNode.requestFocus();
    setState(() {});
  }

  _ResolvedTextSelection? _resolveSingleTextNodeSelection() {
    final selection = _resolveActiveSelection();
    if (selection == null || selection.isCollapsed) {
      return null;
    }

    if (selection.base.nodeId != selection.extent.nodeId) {
      return null;
    }

    final basePosition = selection.base.nodePosition;
    final extentPosition = selection.extent.nodePosition;
    if (basePosition is! TextNodePosition ||
        extentPosition is! TextNodePosition) {
      return null;
    }

    final textNode = _document.getNodeById(selection.extent.nodeId);
    if (textNode is! TextNode) {
      return null;
    }

    return _ResolvedTextSelection(
      textNode: textNode,
      startOffset: math.min(basePosition.offset, extentPosition.offset),
      endOffset: math.max(basePosition.offset, extentPosition.offset),
    );
  }

  SpanRange? _trimSelectionWhitespace(
    AttributedText text, {
    required int startOffset,
    required int endOffsetExclusive,
  }) {
    var trimmedStart = startOffset;
    var trimmedEnd = endOffsetExclusive;

    while (trimmedStart < trimmedEnd && text.text[trimmedStart] == ' ') {
      trimmedStart += 1;
    }
    while (trimmedEnd > trimmedStart && text.text[trimmedEnd - 1] == ' ') {
      trimmedEnd -= 1;
    }

    if (trimmedStart >= trimmedEnd) {
      return null;
    }

    return SpanRange(trimmedStart, trimmedEnd - 1);
  }

  bool _isSupportedAbsoluteUri(Uri? uri) {
    if (uri == null || !uri.hasScheme) {
      return false;
    }

    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Future<String?> _showToolbarUrlDialog({
    required String title,
    required String hintText,
    required String confirmLabel,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(hintText: hintText),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Required';
                }

                final uri = Uri.tryParse(trimmed);
                if (!_isSupportedAbsoluteUri(uri)) {
                  return 'Enter a valid URL';
                }

                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() != true) {
                  return;
                }

                Navigator.of(dialogContext).pop(controller.text.trim());
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }

                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return value;
  }

  void _showToolbarMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showAllFormattingTools() {
    _rememberCurrentSelection();
    setState(() {
      _isToolbarExpanded = !_isToolbarExpanded;
    });
  }

  List<_ToolbarAction> _buildExpandedToolbarActions() {
    return [
      _ToolbarAction(
        icon: Icons.format_bold_rounded,
        tooltip: 'Bold',
        onPressed: _toggleBold,
      ),
      _ToolbarAction(
        icon: Icons.format_italic_rounded,
        tooltip: 'Italic',
        onPressed: _toggleItalic,
      ),
      _ToolbarAction(
        icon: Icons.format_list_bulleted_rounded,
        tooltip: 'List',
        onPressed: _convertToUnorderedList,
      ),
      _ToolbarAction(
        icon: Icons.format_list_numbered_rounded,
        tooltip: 'Ordered List',
        onPressed: _convertToOrderedList,
      ),
      _ToolbarAction(
        icon: Icons.format_underlined_rounded,
        tooltip: 'Underline',
        onPressed: _toggleUnderline,
      ),
      _ToolbarAction(
        icon: Icons.format_strikethrough_rounded,
        tooltip: 'Strikethrough',
        onPressed: _toggleStrikethrough,
      ),
      _ToolbarAction(
        icon: Icons.subject_outlined,
        tooltip: 'Paragraph',
        onPressed: _convertToParagraph,
      ),
      _ToolbarAction(
        icon: Icons.title_outlined,
        tooltip: 'Heading',
        onPressed: _convertToHeader,
      ),
      _ToolbarAction(
        icon: Icons.link_rounded,
        tooltip: 'Link',
        onPressedAsync: _insertLink,
      ),
      _ToolbarAction(
        icon: Icons.format_quote_rounded,
        tooltip: 'Quote',
        onPressed: _convertToBlockquote,
      ),
      _ToolbarAction(
        icon: Icons.data_object_rounded,
        tooltip: 'Code Block',
        onPressed: _convertToCodeBlock,
      ),
      _ToolbarAction(
        icon: Icons.image_outlined,
        tooltip: 'Image',
        onPressedAsync: _insertImage,
      ),
    ];
  }

  void _convertToList(ListItemType listType) {
    final selectedNode = _resolveActiveTextNode();
    if (selectedNode == null) {
      return;
    }

    if (selectedNode is ListItemNode) {
      _documentEditor.executeCommand(
        ConvertListItemToParagraphCommand(
          nodeId: selectedNode.id,
          paragraphMetadata: const {},
        ),
      );
      final convertedNode = _document.getNodeById(selectedNode.id);
      if (convertedNode is ParagraphNode) {
        final removedCharacters = _listPrefixLength(convertedNode.text.text);
        final updatedText =
            _applyListPrefixToText(convertedNode.text, listType);
        convertedNode.text = updatedText;
        convertedNode.putMetadataValue('blockType', _paragraphAttribution);
        _updateSelectionForPrefixChange(
          nodeId: convertedNode.id,
          removedCharacters: removedCharacters,
          insertedCharacters: _listPrefixLength(updatedText.text),
        );
      }
    } else if (selectedNode is ParagraphNode) {
      final removedCharacters = _listPrefixLength(selectedNode.text.text);
      final updatedText = _applyListPrefixToText(selectedNode.text, listType);
      selectedNode.text = updatedText;
      selectedNode.putMetadataValue('blockType', _paragraphAttribution);
      _updateSelectionForPrefixChange(
        nodeId: selectedNode.id,
        removedCharacters: removedCharacters,
        insertedCharacters: _listPrefixLength(updatedText.text),
      );
    }
    _editorFocusNode.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _lastDocumentSelection ??= _composer.selection;
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    const titleSlotHeight = 56.0;
    final contentMinHeight =
        math.max(560.0, MediaQuery.sizeOf(context).height * 0.72);

    return Consumer<DataService>(
      builder: (context, dataService, child) {
        final updatedAt = widget.note?.updatedAt ?? DateTime.now();
        final canMoveToFolder = widget.note != null &&
            !dataService.isSharedNoteFromOtherUser(widget.note!);
        return Scaffold(
          backgroundColor: const Color(0xFFF7F3EC),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF7F3EC),
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              if (_isEditing) ...[
                IconButton(
                  onPressed: _canUndo ? _undo : null,
                  tooltip: 'Undo',
                  icon: const Icon(Icons.undo_rounded),
                ),
                IconButton(
                  onPressed: _canRedo ? _redo : null,
                  tooltip: 'Redo',
                  icon: const Icon(Icons.redo_rounded),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: SizedBox.square(
                  dimension: 48,
                  child: _isEditing
                      ? IconButton(
                          onPressed: _isSubmitting ? null : _save,
                          tooltip: 'Save',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          icon: const Icon(Icons.check_rounded),
                        )
                      : PopupMenuButton<_NoteMenuAction>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_horiz_rounded),
                          tooltip: 'More',
                          onSelected: (value) async {
                            switch (value) {
                              case _NoteMenuAction.toggleVisibility:
                                await _toggleVisibility();
                                break;
                              case _NoteMenuAction.moveTo:
                                await _moveToFolder();
                                break;
                              case _NoteMenuAction.delete:
                                await _deleteNote();
                                break;
                            }
                          },
                          itemBuilder: (context) {
                            return [
                              PopupMenuItem<_NoteMenuAction>(
                                value: _NoteMenuAction.toggleVisibility,
                                child: Text(
                                  _isShared
                                      ? 'Set to Private'
                                      : 'Set to Public',
                                ),
                              ),
                              if (canMoveToFolder)
                                const PopupMenuItem<_NoteMenuAction>(
                                  value: _NoteMenuAction.moveTo,
                                  child: Text('Move To'),
                                ),
                              const PopupMenuItem<_NoteMenuAction>(
                                value: _NoteMenuAction.delete,
                                child: Text('Delete'),
                              ),
                            ];
                          },
                        ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                _isEditing
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          8,
                          24,
                          _isToolbarExpanded ? 160 : 120,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: titleSlotHeight,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Transform.translate(
                                  offset: const Offset(0, 0.75),
                                  child: TextField(
                                    controller: _titleController,
                                    focusNode: _titleFocusNode,
                                    decoration: const InputDecoration(
                                      isCollapsed: true,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: 'Title',
                                      border: InputBorder.none,
                                    ),
                                    maxLines: 1,
                                    style: titleStyle,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${updatedAt.month}月${updatedAt.day}日 ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}  |  $_plainTextLength chars',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF8A8175),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(bottom: 4),
                                child: SuperEditor(
                                  documentLayoutKey: _documentLayoutKey,
                                  focusNode: _editorFocusNode,
                                  editor: _documentEditor,
                                  composer: _composer,
                                  stylesheet: _stylesheet,
                                  selectionPolicies:
                                      const SuperEditorSelectionPolicies(
                                    placeCaretAtEndOfDocumentOnGainFocus: false,
                                    restorePreviousSelectionOnGainFocus: true,
                                    clearSelectionWhenEditorLosesFocus: false,
                                    clearSelectionWhenImeConnectionCloses:
                                        false,
                                  ),
                                  autofocus: widget.note == null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _enterEditMode(focusContent: false),
                              child: SizedBox(
                                height: titleSlotHeight,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _titleController.text.trim().isEmpty
                                        ? 'Untitled Note'
                                        : _titleController.text.trim(),
                                    style: titleStyle,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${updatedAt.month}月${updatedAt.day}日 ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}  |  $_plainTextLength chars',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF8A8175),
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _enterEditMode(focusContent: true),
                              child: Container(
                                width: double.infinity,
                                constraints:
                                    BoxConstraints(minHeight: contentMinHeight),
                                padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                                child: SingleColumnDocumentLayout(
                                  presenter: SingleColumnLayoutPresenter(
                                    document: _document,
                                    componentBuilders: defaultComponentBuilders,
                                    pipeline: [
                                      SingleColumnStylesheetStyler(
                                        stylesheet: _stylesheet,
                                      ),
                                    ],
                                  ),
                                  componentBuilders: defaultComponentBuilders,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                if (_isEditing)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 28,
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: _FloatingFormattingToolbar(
                          onBeforeAction: _rememberCurrentSelection,
                          isExpanded: _isToolbarExpanded,
                          primaryActions: const [
                            _ToolbarAction(
                              icon: Icons.format_bold_rounded,
                              tooltip: 'Bold',
                            ),
                            _ToolbarAction(
                              icon: Icons.format_italic_rounded,
                              tooltip: 'Italic',
                            ),
                            _ToolbarAction(
                              icon: Icons.format_list_bulleted_rounded,
                              tooltip: 'List',
                            ),
                            _ToolbarAction(
                              icon: Icons.format_list_numbered_rounded,
                              tooltip: 'Ordered List',
                            ),
                            _ToolbarAction(
                              icon: Icons.format_underlined_rounded,
                              tooltip: 'Underline',
                            ),
                          ],
                          primaryCallbacks: [
                            _toggleBold,
                            _toggleItalic,
                            _convertToUnorderedList,
                            _convertToOrderedList,
                            _toggleUnderline,
                          ],
                          expandedActions: _buildExpandedToolbarActions(),
                          onMore: _showAllFormattingTools,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FloatingFormattingToolbar extends StatelessWidget {
  const _FloatingFormattingToolbar({
    required this.onBeforeAction,
    required this.isExpanded,
    required this.primaryActions,
    required this.primaryCallbacks,
    required this.expandedActions,
    required this.onMore,
  });

  final VoidCallback onBeforeAction;
  final bool isExpanded;
  final List<_ToolbarAction> primaryActions;
  final List<VoidCallback> primaryCallbacks;
  final List<_ToolbarAction> expandedActions;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final collapsedActions = [
      for (var index = 0; index < primaryActions.length; index += 1)
        primaryActions[index].copyWith(onPressed: primaryCallbacks[index]),
      _ToolbarAction(
        icon: Icons.more_horiz_rounded,
        tooltip: 'More Formatting',
        onPressed: onMore,
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBF7).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToolbarActionRow(
                        onBeforeAction: onBeforeAction,
                        actions:
                            expandedActions.take(6).toList(growable: false),
                      ),
                      const SizedBox(height: 8),
                      _ToolbarActionRow(
                        onBeforeAction: onBeforeAction,
                        actions: expandedActions
                            .skip(6)
                            .take(6)
                            .toList(growable: false),
                      ),
                    ],
                  )
                : _ToolbarActionRow(
                    onBeforeAction: onBeforeAction,
                    actions: collapsedActions,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarActionRow extends StatelessWidget {
  const _ToolbarActionRow({
    required this.onBeforeAction,
    required this.actions,
  });

  final VoidCallback onBeforeAction;
  final List<_ToolbarAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _ToolbarActionButton(
              onBeforeAction: onBeforeAction,
              icon: action.icon,
              tooltip: action.tooltip,
              onTap: action.callback,
            ),
          ),
      ],
    );
  }
}

class _ToolbarActionButton extends StatelessWidget {
  const _ToolbarActionButton({
    required this.onBeforeAction,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final VoidCallback onBeforeAction;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Listener(
        onPointerDown: (_) => onBeforeAction(),
        child: IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          iconSize: 22,
          icon: Icon(icon, color: const Color(0xFF8A7A6C)),
        ),
      ),
    );
  }
}

class _ToolbarAction {
  const _ToolbarAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.onPressedAsync,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Future<void> Function()? onPressedAsync;

  VoidCallback get callback {
    if (onPressed != null) {
      return onPressed!;
    }

    return () {
      onPressedAsync?.call();
    };
  }

  _ToolbarAction copyWith({
    IconData? icon,
    String? tooltip,
    VoidCallback? onPressed,
    Future<void> Function()? onPressedAsync,
  }) {
    return _ToolbarAction(
      icon: icon ?? this.icon,
      tooltip: tooltip ?? this.tooltip,
      onPressed: onPressed ?? this.onPressed,
      onPressedAsync: onPressedAsync ?? this.onPressedAsync,
    );
  }
}

class _NoteEditorSnapshot {
  const _NoteEditorSnapshot({
    required this.title,
    required this.titleSelection,
    required this.serializedDocument,
    required this.documentSelection,
  });

  final String title;
  final TextSelection titleSelection;
  final String serializedDocument;
  final _DocumentSelectionSnapshot? documentSelection;

  bool hasSameContent(_NoteEditorSnapshot other) {
    return title == other.title &&
        titleSelection == other.titleSelection &&
        serializedDocument == other.serializedDocument &&
        documentSelection == other.documentSelection;
  }
}

class _ResolvedTextSelection {
  const _ResolvedTextSelection({
    required this.textNode,
    required this.startOffset,
    required this.endOffset,
  });

  final TextNode textNode;
  final int startOffset;
  final int endOffset;
}

class _DocumentSelectionSnapshot {
  const _DocumentSelectionSnapshot({
    required this.base,
    required this.extent,
  });

  final _DocumentPositionSnapshot base;
  final _DocumentPositionSnapshot extent;

  static _DocumentSelectionSnapshot? fromSelection(
    DocumentSelection? selection,
    Document document,
  ) {
    if (selection == null) {
      return null;
    }

    final base =
        _DocumentPositionSnapshot.fromPosition(selection.base, document);
    final extent = _DocumentPositionSnapshot.fromPosition(
      selection.extent,
      document,
    );
    if (base == null || extent == null) {
      return null;
    }

    return _DocumentSelectionSnapshot(base: base, extent: extent);
  }

  DocumentSelection? toSelection(Document document) {
    final basePosition = base.toPosition(document);
    final extentPosition = extent.toPosition(document);
    if (basePosition == null || extentPosition == null) {
      return null;
    }

    return DocumentSelection(base: basePosition, extent: extentPosition);
  }
}

class _DocumentPositionSnapshot {
  const _DocumentPositionSnapshot({
    required this.nodeIndex,
    required this.offset,
    required this.affinity,
  });

  final int nodeIndex;
  final int offset;
  final TextAffinity affinity;

  static _DocumentPositionSnapshot? fromPosition(
    DocumentPosition position,
    Document document,
  ) {
    final nodePosition = position.nodePosition;
    if (nodePosition is! TextNodePosition) {
      return null;
    }

    final nodeIndex = document.getNodeIndexById(position.nodeId);
    if (nodeIndex < 0) {
      return null;
    }

    return _DocumentPositionSnapshot(
      nodeIndex: nodeIndex,
      offset: nodePosition.offset,
      affinity: nodePosition.affinity,
    );
  }

  DocumentPosition? toPosition(Document document) {
    final node = document.getNodeAt(nodeIndex);
    if (node is! TextNode) {
      return null;
    }

    final clampedOffset = math.min(offset, node.text.text.length);
    return DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(
        offset: clampedOffset,
        affinity: affinity,
      ),
    );
  }
}

enum _NoteMenuAction {
  toggleVisibility,
  moveTo,
  delete,
}

class _FolderSelectionTile extends StatelessWidget {
  const _FolderSelectionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded)
          : const Icon(Icons.circle_outlined),
      onTap: onTap,
    );
  }
}
