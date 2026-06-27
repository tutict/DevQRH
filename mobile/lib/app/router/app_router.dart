import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../../features/knowledge/presentation/cards_screen.dart';
import '../../features/knowledge/presentation/home_screen.dart';
import '../../features/knowledge/presentation/library_screen.dart';
import '../../features/knowledge/presentation/material_detail_screen.dart';
import '../../features/knowledge/presentation/settings_screen.dart';
import '../../features/knowledge/presentation/tutor_screen.dart';

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
                builder: (context, state) => const KnowledgeHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ask',
                builder: (context, state) => const TutorScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cards',
                builder: (context, state) => const CardsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const KnowledgeSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/materials/:id',
        builder: (context, state) {
          return MaterialDetailScreen(
            materialId: state.pathParameters['id'] ?? '',
          );
        },
      ),
    ],
  );
});
