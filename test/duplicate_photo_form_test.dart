import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acha_karo/data/deed_catalog.dart';
import 'package:acha_karo/data/deed_form_fields.dart';
import 'package:acha_karo/data/guddi_content.dart';
import 'package:acha_karo/state/app_state.dart';
import 'package:acha_karo/widgets/submit_deed_modal.dart';

// v1.3.2 duplicate photo, end to end through the real submit form: a duplicate keeps the form
// open with Guddi's message, the new photo shows the "will be reviewed" notice, and that next
// submission is sent with afterDuplicate (forced to a moderator). No Supabase: AppState's submit
// is faked, and so is the photo picker.

class _FakePicker extends ImagePickerPlatform {
  final List<Uint8List> queue;
  _FakePicker(this.queue);
  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async =>
      XFile.fromData(queue.removeAt(0), name: 'scaled_1000000033.jpg');
}

class _Call {
  final Uint8List? photo;
  final bool afterDuplicate;
  _Call(this.photo, this.afterDuplicate);
}

class _FakeAppState extends AppState {
  final calls = <_Call>[];
  final List<bool> duplicateAnswers; // per call: was it a duplicate?
  _FakeAppState(this.duplicateAnswers);
  @override
  Future<SubmitResult> submitPhotoDeed(String type, Map<String, String> details,
      {Uint8List? photoBytes, String? photoFileName, String? campaignId, bool shareLocation = true, bool afterDuplicate = false}) async {
    calls.add(_Call(photoBytes, afterDuplicate));
    if (duplicateAnswers[calls.length - 1]) {
      return const SubmitResult(flagged: false, leveledUpTier: null, newMilestones: [], duplicatePhoto: true);
    }
    return SubmitResult(flagged: afterDuplicate, leveledUpTier: null, newMilestones: const []);
  }
}

// A deed with no dropdowns and not a donation, so the photo alone enables Submit.
final _type = deedCatalog.keys.firstWhere((t) => (deedFormFields[t] ?? []).isEmpty && !donationDeedTypes.contains(t));

final _photoA = Uint8List.fromList(List.generate(64, (i) => i));
final _photoB = Uint8List.fromList(List.generate(64, (i) => 255 - i));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({'ak_location_disclosure_accepted': true}));

  void ignoreNoise() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final s = details.exceptionAsString();
      // Fonts are off in tests, and the fake photo bytes aren't a real image (the preview can't decode them).
      if (s.contains('GoogleFonts') || s.contains('google_fonts') || s.contains('Invalid image data') || s.contains('image codec')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<Future<SubmitResult?> Function()> openForm(WidgetTester tester, _FakeAppState state) async {
    SubmitResult? popped;
    var done = false;
    tester.binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
    addTearDown(() => tester.binding.platformDispatcher.views.first.resetPhysicalSize());
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await showModalBottomSheet<SubmitResult>(context: ctx, isScrollControlled: true, builder: (_) => SubmitDeedModal(type: _type));
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    return () async => done ? popped : null;
  }

  Future<void> pickFromGallery(WidgetTester tester) async {
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
  }

  testWidgets('duplicate → Guddi message, form stays open → new photo → review notice → moderated submit', (tester) async {
    ignoreNoise();
    ImagePickerPlatform.instance = _FakePicker([_photoA, _photoB]);
    final state = _FakeAppState([true, false]);
    final result = await openForm(tester, state);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Photo A, submit: it's a duplicate.
    await tester.tap(find.text('📷'));
    await tester.pumpAndSettle();
    await pickFromGallery(tester);
    expect(find.byKey(const ValueKey('will-be-reviewed-note')), findsNothing);
    await tester.tap(find.text('Submit deed'));
    await tester.pumpAndSettle();

    expect(state.calls, hasLength(1));
    expect(state.calls[0].photo, _photoA);
    expect(state.calls[0].afterDuplicate, isFalse);
    expect(await result(), isNull, reason: 'form stays open');
    expect(find.text(GuddiDuplicatePhotoLines.rejected.roman), findsOneWidget);
    expect(find.text('Add a photo'), findsOneWidget, reason: 'the duplicate photo was dropped');

    // "New photo" → photo B. The rejection message goes, the review notice appears.
    await tester.tap(find.byKey(const ValueKey('duplicate-new-photo')));
    await tester.pumpAndSettle();
    await pickFromGallery(tester);
    expect(find.text(GuddiDuplicatePhotoLines.rejected.roman), findsNothing);
    expect(find.text(GuddiDuplicatePhotoLines.willBeReviewed.roman), findsOneWidget);

    await tester.tap(find.text('Submit deed'));
    await tester.pumpAndSettle();
    expect(state.calls, hasLength(2));
    expect(state.calls[1].photo, _photoB);
    expect(state.calls[1].afterDuplicate, isTrue, reason: 'forced onto the moderated path');
    final popped = await result();
    expect(popped, isNotNull, reason: 'form closes after the real submission');
    expect(popped!.flagged, isTrue);
  });

  testWidgets('no duplicate: normal submit, no notices, not forced to review', (tester) async {
    ignoreNoise();
    ImagePickerPlatform.instance = _FakePicker([_photoA]);
    final state = _FakeAppState([false]);
    final result = await openForm(tester, state);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('📷'));
    await tester.pumpAndSettle();
    await pickFromGallery(tester);
    await tester.tap(find.text('Submit deed'));
    await tester.pumpAndSettle();
    expect(state.calls.single.afterDuplicate, isFalse);
    expect(find.text(GuddiDuplicatePhotoLines.rejected.roman), findsNothing);
    expect((await result())!.flagged, isFalse);
  });
}
