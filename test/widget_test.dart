
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:our_committee/main.dart';
import 'package:our_committee/services/state_service.dart';
import 'package:our_committee/models/user.dart';

void main() {
  group('AppStateService Tests', () {
    test('New user registration balance defaults to 0.0 PKR', () async {
      final state = AppStateService();
      
      final bool success = await state.signUp(
        "Test User",
        "newuser@test.com",
        "password123",
        "42101-1234567-3",
        "0300-1112223",
        UserRole.member,
      );

      expect(success, true);
      expect(state.currentUser, isNotNull);
      expect(state.currentUser!.balance, 0.0);
    });

    test('Connecting wallet provider fetches linked balance (PKR 25,000)', () async {
      final state = AppStateService();
      
      await state.signUp(
        "Test User",
        "newuser@test.com",
        "password123",
        "42101-1234567-3",
        "0300-1112223",
        UserRole.member,
      );

      final bool linkSuccess = await state.connectWalletProvider("JAZZCASH", "0312-3456789", "1234");
      expect(linkSuccess, true);
      expect(state.currentUser!.linkedProvider, "JAZZCASH");
      expect(state.currentUser!.balance, 25000.0);
    });

    test('Disconnecting wallet resets balance back to 0.0 PKR', () async {
      final state = AppStateService();
      
      await state.signUp(
        "Test User",
        "newuser@test.com",
        "password123",
        "42101-1234567-3",
        "0300-1112223",
        UserRole.member,
      );

      await state.connectWalletProvider("EASYPAISA", "0312-3456789", "1234");
      expect(state.currentUser!.balance, 25000.0);

      await state.disconnectWallet();
      expect(state.currentUser!.linkedProvider, isNull);
      expect(state.currentUser!.balance, 0.0);
    });
  });

  testWidgets('App loads splash and launches UI without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppStateService()),
        ],
        child: const OurCommitteeApp(),
      ),
    );

    // Verify splash elements exist
    expect(find.text('Our Committee'), findsOneWidget);
    
    // Pump past the splash screen timer (3.2 seconds) to avoid pending timer exception
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();
  });
}
