import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../../features/lookup/presentation/checklist_detail_screen.dart';
import '../../features/lookup/presentation/favorites_screen.dart';
import '../../features/lookup/presentation/home_screen.dart';
import '../../features/lookup/presentation/recent_screen.dart';
import '../../features/lookup/presentation/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recent',
                builder: (context, state) => const RecentScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/checklists/:id',
        builder: (context, state) {
          final checklistId = state.pathParameters['id'] ?? '';
          final title = state.uri.queryParameters['title'] ?? '';
          return ChecklistDetailScreen(
            checklistId: checklistId,
            titleHint: title,
          );
        },
      ),
    ],
  );
});
