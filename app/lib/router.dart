import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/data/cart.dart';
import 'core/data/orders.dart';
import 'core/data/session.dart';
import 'core/models/models.dart';
import 'features/auth/registration_screen.dart';
import 'features/auth/waiting_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/cart/order_placed_screen.dart';
import 'features/cart/review_screen.dart';
import 'features/catalogue/category_screen.dart';
import 'features/catalogue/home_screen.dart';
import 'features/catalogue/product_screen.dart';
import 'features/catalogue/search_screen.dart';
import 'features/orders/my_orders_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/owner/catalogue_admin_screen.dart';
import 'features/owner/category_edit_screen.dart';
import 'features/owner/customers_screen.dart';
import 'features/owner/dashboard_screen.dart';
import 'features/owner/owner_order_screen.dart';
import 'features/owner/owner_orders_screen.dart';
import 'features/owner/product_edit_screen.dart';
import 'features/owner/settings_screen.dart';
import 'features/profile/profile_screen.dart';

/// Re-runs the router's redirect whenever the session changes.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _SessionListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/shop',
    refreshListenable: listenable,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      if (session.isLoading && !session.hasValue) return loc == '/splash' ? null : '/splash';
      final s = session.value ?? const SignedOut();
      final open = loc == '/policy';

      String? only(String target, {List<String> also = const []}) =>
          loc == target || open || also.contains(loc) ? null : target;

      switch (s) {
        case SignedOut():
          return only('/welcome');
        case NeedsProfile():
          return only('/register');
        case Owner():
          return loc.startsWith('/owner') || open ? null : '/owner';
        case Customer(:final profile):
          if (profile.status != UserStatus.approved) {
            return profile.status == UserStatus.rejected
                ? only('/waiting', also: ['/register'])
                : only('/waiting');
          }
          if (loc.startsWith('/owner') || const ['/welcome', '/register', '/waiting', '/splash'].contains(loc)) {
            return '/shop';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegistrationScreen()),
      GoRoute(path: '/waiting', builder: (_, _) => const WaitingScreen()),
      GoRoute(path: '/policy', builder: (_, _) => const PrivacyPolicyScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _CustomerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/shop',
              builder: (_, _) => const HomeScreen(),
              routes: [
                GoRoute(path: 'search', builder: (_, _) => const SearchScreen()),
                GoRoute(path: 'category/:id', builder: (_, s) => CategoryScreen(categoryId: s.pathParameters['id']!)),
                GoRoute(path: 'product/:id', builder: (_, s) => ProductScreen(productId: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cart',
              builder: (_, _) => const CartScreen(),
              routes: [
                GoRoute(path: 'review', builder: (_, _) => const ReviewScreen()),
                GoRoute(
                  path: 'placed/:id',
                  builder: (_, s) => OrderPlacedScreen(orderId: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/orders',
              builder: (_, _) => const MyOrdersScreen(),
              routes: [
                GoRoute(path: ':id', builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _OwnerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/owner', builder: (_, _) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/owner/orders',
              builder: (_, _) => const OwnerOrdersScreen(),
              routes: [
                GoRoute(path: ':id', builder: (_, s) => OwnerOrderScreen(orderId: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/owner/customers', builder: (_, _) => const CustomersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/owner/catalogue',
              builder: (_, _) => const CatalogueAdminScreen(),
              routes: [
                GoRoute(path: 'product/:id', builder: (_, s) => ProductEditScreen(productId: s.pathParameters['id']!)),
                GoRoute(path: 'category/:id', builder: (_, s) => CategoryEditScreen(categoryId: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/owner/settings', builder: (_, _) => const OwnerSettingsScreen()),
          ]),
        ],
      ),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _CustomerShell extends ConsumerWidget {
  const _CustomerShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Shop'),
          NavigationDestination(
            icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_cart_outlined)),
            selectedIcon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_cart)),
            label: 'Cart',
          ),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'My orders'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _OwnerShell extends ConsumerWidget {
  const _OwnerShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCustomersProvider).value?.length ?? 0;
    final newOrders = ref.watch(ownerOrdersProvider(OrderFilter.open)).value
            ?.where((o) => o.status == OrderStatus.placed)
            .length ??
        0;
    Widget badge(int n, IconData icon) =>
        Badge(isLabelVisible: n > 0, label: Text('$n'), child: Icon(icon));
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Today'),
          NavigationDestination(icon: badge(newOrders, Icons.receipt_long_outlined), label: 'Orders'),
          NavigationDestination(icon: badge(pending, Icons.people_outline), label: 'Customers'),
          const NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Catalogue'),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
