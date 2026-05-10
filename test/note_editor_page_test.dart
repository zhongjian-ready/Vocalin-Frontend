import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/super_editor.dart';
import 'package:vocalin/src/models/post.dart';
import 'package:vocalin/src/screens/records/note_editor_page.dart';
import 'package:vocalin/src/services/data_service.dart';

Widget buildTestApp() {
  return ChangeNotifierProvider<DataService>.value(
    value: DataService(autoInitialize: false),
    child: MaterialApp(
      home: NoteEditorPage(
        note: buildTestNote(),
        startInEditMode: true,
      ),
    ),
  );
}

Post buildTestNote() {
  return Post(
    id: 1,
    type: PostType.note,
    title: 'Title',
    content: 'I love you!',
    createdAt: DateTime(2026, 4, 23, 9),
    updatedAt: DateTime(2026, 4, 23, 9),
    color: 'yellow',
    isShared: true,
  );
}

Future<void> pumpNoteEditorInNavigationStack(
  WidgetTester tester, {
  required DataService dataService,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    ChangeNotifierProvider<DataService>.value(
      value: dataService,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Center(child: Text('Notes List'))),
      ),
    ),
  );

  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => NoteEditorPage(
        note: buildTestNote(),
        startInEditMode: true,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
  });

  testWidgets('compact toolbar shows primary formatting actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Bold'), findsOneWidget);
    expect(find.byTooltip('Italic'), findsOneWidget);
    expect(find.byTooltip('List'), findsOneWidget);
    expect(find.byTooltip('Ordered List'), findsOneWidget);
    expect(find.byTooltip('Underline'), findsOneWidget);
    expect(find.byTooltip('More Formatting'), findsOneWidget);
    expect(find.byTooltip('Strikethrough'), findsNothing);
  });

  testWidgets('more formatting expands inline and shows full toolbar actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More Formatting'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Paragraph'), findsOneWidget);
    expect(find.byTooltip('Heading'), findsOneWidget);
    expect(find.byTooltip('Strikethrough'), findsOneWidget);
    expect(find.byTooltip('Link'), findsOneWidget);
    expect(find.byTooltip('Quote'), findsOneWidget);
    expect(find.byTooltip('Code Block'), findsOneWidget);
    expect(find.byTooltip('Image'), findsOneWidget);
    expect(find.byTooltip('More Formatting'), findsNothing);
  });

  testWidgets('tapping note content places selection on the visible paragraph',
      (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final firstNode = SuperEditorInspector.getNodeAt<TextNode>(0);
    final tapOffset = SuperEditorInspector.findComponentOffset(
          firstNode.id,
          Alignment.topLeft,
        ) +
        const Offset(32, 12);

    await tester.tapAt(tapOffset);
    await tester.pumpAndSettle();

    final selection = SuperEditorInspector.findDocumentSelection();
    expect(selection, isNotNull);
    expect(selection!.extent.nodeId, firstNode.id);
  });

  testWidgets('unordered list converts the selected note paragraph', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final composer = SuperEditorInspector.findComposer()!;
    final document = SuperEditorInspector.findDocument()!;
    final firstNode = document.nodes.first as TextNode;
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: firstNode.id,
        nodePosition: const TextNodePosition(offset: 2),
      ),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();

    final updatedDocument = SuperEditorInspector.findDocument()!;
    expect(updatedDocument.nodes.first, isA<ParagraphNode>());
    expect(
      (updatedDocument.nodes.first as ParagraphNode).text.text,
      '• I love you!',
    );
    expect(updatedDocument.nodes.whereType<ListItemNode>(), isEmpty);
  });

  testWidgets('ordered list converts the selected note paragraph', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final composer = SuperEditorInspector.findComposer()!;
    final document = SuperEditorInspector.findDocument()!;
    final firstNode = document.nodes.first as TextNode;
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: firstNode.id,
        nodePosition: const TextNodePosition(offset: 2),
      ),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('Ordered List'));
    await tester.pumpAndSettle();

    final updatedDocument = SuperEditorInspector.findDocument()!;
    expect(updatedDocument.nodes.first, isA<ParagraphNode>());
    expect(
      (updatedDocument.nodes.first as ParagraphNode).text.text,
      '1. I love you!',
    );
    expect(updatedDocument.nodes.whereType<ListItemNode>(), isEmpty);
  });

  testWidgets('underline and strikethrough toolbar buttons add text spans', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final composer = SuperEditorInspector.findComposer()!;
    final document = SuperEditorInspector.findDocument()!;
    final firstNode = document.nodes.first as TextNode;
    composer.selection = DocumentSelection(
      base: DocumentPosition(
        nodeId: firstNode.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
      extent: DocumentPosition(
        nodeId: firstNode.id,
        nodePosition: const TextNodePosition(offset: 4),
      ),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('Underline'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More Formatting'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Strikethrough'));
    await tester.pumpAndSettle();

    final updatedParagraph =
        SuperEditorInspector.findDocument()!.nodes.first as ParagraphNode;
    expect(
      updatedParagraph.text.getAttributionSpans({underlineAttribution}),
      isNotEmpty,
    );
    expect(
      updatedParagraph.text.getAttributionSpans({strikethroughAttribution}),
      isNotEmpty,
    );
  });

  testWidgets('quote and code block actions are available after inline expand',
      (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final composer = SuperEditorInspector.findComposer()!;
    final document = SuperEditorInspector.findDocument()!;
    final firstNode = document.nodes.first as TextNode;
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: firstNode.id,
        nodePosition: const TextNodePosition(offset: 2),
      ),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('More Formatting'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quote'));
    await tester.pumpAndSettle();

    ParagraphNode updatedParagraph =
        SuperEditorInspector.findDocument()!.nodes.first as ParagraphNode;
    expect(
        updatedParagraph.getMetadataValue('blockType'), blockquoteAttribution);

    await tester.tap(find.byTooltip('Code Block'));
    await tester.pumpAndSettle();

    updatedParagraph =
        SuperEditorInspector.findDocument()!.nodes.first as ParagraphNode;
    expect(updatedParagraph.getMetadataValue('blockType'), codeAttribution);
  });

  testWidgets('pressing enter continues an unordered list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final composer = SuperEditorInspector.findComposer()!;
    final document = SuperEditorInspector.findDocument()!;
    final firstNode = document.nodes.first as TextNode;
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: firstNode.id,
        nodePosition: TextNodePosition(offset: firstNode.text.text.length),
      ),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final updatedDocument = SuperEditorInspector.findDocument()!;
    expect(updatedDocument.nodes.length, 2);
    expect(
      (updatedDocument.nodes.first as ParagraphNode).text.text,
      '• I love you!',
    );
    expect(
      (updatedDocument.nodes[1] as ParagraphNode).text.text,
      '• ',
    );

    final selection = SuperEditorInspector.findDocumentSelection()!;
    expect(selection.extent.nodeId, updatedDocument.nodes[1].id);
    expect(
      (selection.extent.nodePosition as TextNodePosition).offset,
      2,
    );
  });

  testWidgets('undo and redo toolbar buttons restore note content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final composer = SuperEditorInspector.findComposer()!;
    final document = SuperEditorInspector.findDocument()!;
    final firstNode = document.nodes.first as TextNode;
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: firstNode.id,
        nodePosition: const TextNodePosition(offset: 2),
      ),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();

    ParagraphNode updatedParagraph =
        SuperEditorInspector.findDocument()!.nodes.first as ParagraphNode;
    expect(updatedParagraph.text.text, '• I love you!');

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();

    updatedParagraph =
        SuperEditorInspector.findDocument()!.nodes.first as ParagraphNode;
    expect(updatedParagraph.text.text, 'I love you!');

    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();

    updatedParagraph =
        SuperEditorInspector.findDocument()!.nodes.first as ParagraphNode;
    expect(updatedParagraph.text.text, '• I love you!');
  });

  testWidgets('back navigation prompts to save and saves before returning', (
    WidgetTester tester,
  ) async {
    final dataService = _RecordingDataService();

    await pumpNoteEditorInNavigationStack(tester, dataService: dataService);

    await tester.enterText(find.byType(TextField).first, 'Updated Title');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Save changes?'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(dataService.updateNoteCallCount, 1);
    expect(dataService.lastUpdatedTitle, 'Updated Title');
    expect(find.text('Notes List'), findsOneWidget);
  });

  testWidgets('back navigation discards changes and returns without saving', (
    WidgetTester tester,
  ) async {
    final dataService = _RecordingDataService();

    await pumpNoteEditorInNavigationStack(tester, dataService: dataService);

    await tester.enterText(find.byType(TextField).first, 'Discarded Title');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Save changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(dataService.updateNoteCallCount, 0);
    expect(find.text('Notes List'), findsOneWidget);
  });
}

class _RecordingDataService extends DataService {
  _RecordingDataService() : super(autoInitialize: false);

  int updateNoteCallCount = 0;
  String? lastUpdatedTitle;

  @override
  bool get isLoading => false;

  @override
  Future<void> updateNote(
    int noteId, {
    String? title,
    required String content,
    required bool isShared,
    int? groupId,
  }) async {
    updateNoteCallCount += 1;
    lastUpdatedTitle = title;
  }
}
