import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/screens/add_edit_habit/add_edit_habit_screen.dart';
import 'package:tide/screens/add_edit_habit/widgets/target_fields.dart';
import 'package:tide/screens/home/widgets/add_habit_tile.dart';
import 'package:tide/services/tide_scope.dart';
import 'package:tide/widgets/tide_dialog.dart';
import 'package:tide/widgets/tide_sheet.dart';
import 'package:tide/widgets/tide_tab_bar.dart';

/// A phone, not the 800×600 default. The editor is a full page with a
/// pinned footer and Today's add control sits below four habit cards;
/// neither is reachable in a window shaped like a small laptop.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1100, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Fixed pumps rather than `pumpAndSettle`: several screens carry deliberate
/// ambient loops that never settle by design.
Future<void> settle(WidgetTester tester, [int ms = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Scrolls [target] into view before pressing it. The form is longer than
/// any phone.
Future<void> tapInForm(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await settle(tester, 200);
  await tester.tap(target);
  await settle(tester);
}

Future<void> openEditor(WidgetTester tester) async {
  usePhone(tester);
  await tester.pumpWidget(const TideApp(startOnboarded: true));
  await settle(tester, 900);

  // The tile is the last thing in the list, so with a full day on screen it
  // starts under the floating tab bar. Scroll it clear the way a thumb
  // would.
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
  await settle(tester);

  await tester.tap(find.byType(AddHabitTile));
  await settle(tester);
}

/// The Android back button, as the platform actually delivers it.
Future<void> pressSystemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await settle(tester);
}

void main() {
  group('the add control', () {
    testWidgets('lives in the list rather than beside milestones', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(const TideApp(startOnboarded: true));
      await settle(tester, 900);

      expect(find.byType(AddHabitTile), findsOneWidget);
    });
  });

  group('the habit editor', () {
    testWidgets('opens as a page rather than a sheet', (tester) async {
      await openEditor(tester);

      expect(find.byType(AddEditHabitScreen), findsOneWidget);
      expect(
        find.byType(TideSheet),
        findsNothing,
        reason: 'the form is a destination, not a modal over a blurred page',
      );
      expect(find.text('New habit'), findsWidgets);
    });

    testWidgets('leaving a clean form just leaves', (tester) async {
      await openEditor(tester);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester);

      expect(find.byType(AddEditHabitScreen), findsNothing);
    });

    testWidgets('leaving a dirty form asks first, in a dialog', (tester) async {
      await openEditor(tester);

      await tester.enterText(find.byType(TextField).first, 'Evening walk');
      await settle(tester);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester);

      expect(find.byType(TideDialogPanel), findsOneWidget);
      expect(find.text('Discard changes?'), findsOneWidget);

      // Keeping the edit leaves the form standing, with the typing intact.
      await tester.tap(find.text('Keep editing'));
      await settle(tester);

      expect(find.byType(TideDialogPanel), findsNothing);
      expect(find.byType(AddEditHabitScreen), findsOneWidget);
      expect(find.text('Evening walk'), findsWidgets);
    });

    testWidgets('the system back gesture asks the same question', (
      tester,
    ) async {
      await openEditor(tester);

      await tester.enterText(find.byType(TextField).first, 'Evening walk');
      await settle(tester);

      await pressSystemBack(tester);

      expect(find.byType(TideDialogPanel), findsOneWidget);
      expect(find.byType(AddEditHabitScreen), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await settle(tester);

      expect(find.byType(AddEditHabitScreen), findsNothing);
    });

    testWidgets('a quantity habit can be counted in something typed', (
      tester,
    ) async {
      await openEditor(tester);
      await tapInForm(tester, find.text('Quantity'));

      // Eleven offered units, not three.
      expect(find.text('servings'), findsOneWidget);
      expect(find.text('steps'), findsOneWidget);

      await tapInForm(tester, find.text('Custom'));
      // The name field may have scrolled out of the built range by now, so
      // reach for the last one rather than a fixed index.
      await tester.enterText(find.byType(TextField).last, 'laps');
      await settle(tester);

      expect(find.textContaining('laps'), findsWidgets);
    });

    testWidgets('a new habit starts with no days chosen', (tester) async {
      await openEditor(tester);
      await tester.ensureVisible(find.text('Pick at least one day'));
      await settle(tester, 200);

      expect(find.text('Pick at least one day'), findsOneWidget);
      expect(find.textContaining('no days yet'), findsOneWidget);
    });

    testWidgets('saving with no days holds the form until some are picked', (
      tester,
    ) async {
      await openEditor(tester);
      final store = TideScope.read(
        tester.element(find.byType(AddEditHabitScreen)),
      );
      final before = store.allHabits.length;

      await tester.enterText(find.byType(TextField).first, 'Evening walk');
      await settle(tester);
      await tester.tap(find.text('Create habit'));
      await settle(tester);

      expect(find.byType(AddEditHabitScreen), findsOneWidget);
      expect(store.allHabits, hasLength(before), reason: 'nothing was saved');

      await tapInForm(tester, find.text('Weekdays'));
      expect(find.textContaining('weekdays,'), findsOneWidget);

      await tester.tap(find.text('Create habit'));
      await settle(tester, 1200);

      expect(find.byType(AddEditHabitScreen), findsNothing);
      expect(store.allHabits.last.days, {1, 2, 3, 4, 5});
    });

    testWidgets('a preset tapped again clears the days', (tester) async {
      await openEditor(tester);

      await tapInForm(tester, find.text('Every day'));
      expect(find.text('Every day'), findsNWidgets(2), reason: 'chip + line');

      await tapInForm(tester, find.text('Every day').first);
      expect(find.text('Pick at least one day'), findsOneWidget);
    });

    testWidgets('a duration target reads as time, not a bare number', (
      tester,
    ) async {
      await openEditor(tester);
      await tapInForm(tester, find.text('Duration'));

      expect(find.text('30 min'), findsWidgets);

      await tapInForm(tester, find.text('1 hr 30 min'));
      expect(find.text('1 hr 30 min'), findsWidgets);
    });
  });

  group('back on a tab', () {
    testWidgets('returns to Today instead of closing the app', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(const TideApp(startOnboarded: true));
      await settle(tester, 900);

      await tester.tap(
        find.descendant(
          of: find.byType(TideTabBar),
          matching: find.text('History'),
        ),
      );
      await settle(tester);
      expect(
        tester.widget<TideTabBar>(find.byType(TideTabBar)).currentIndex,
        1,
      );

      await pressSystemBack(tester);

      expect(
        tester.widget<TideTabBar>(find.byType(TideTabBar)).currentIndex,
        0,
        reason: 'back on a secondary tab goes home, it does not exit',
      );
    });
  });

  group('a duration label', () {
    test('never counts past the hour in minutes', () {
      expect(TargetFields.durationLabel(45), '45 min');
      expect(TargetFields.durationLabel(60), '1 hr');
      expect(TargetFields.durationLabel(90), '1 hr 30 min');
      expect(TargetFields.durationLabel(125), '2 hr 5 min');
    });
  });
}
