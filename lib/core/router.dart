import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/db/database.dart';
import '../features/exams/exam_detail_screen.dart';
import '../features/exams/exam_editor_screen.dart';
import '../features/exams/exam_list_screen.dart';
import '../features/onboarding/intro_tour_screen.dart';
import '../features/onboarding/template_picker_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/branch_switcher.dart';
import '../features/subjects/subjects_screen.dart';
import '../features/subjects/topic_detail_screen.dart';
import '../features/subjects/topic_list_screen.dart';
import '../features/today/today_screen.dart';
import 'providers.dart';
abstract final class Routes {
  static const splash = '/';
  static const welcome = '/kurulum';
  static const templatePicker = '/kurulum/sablon';
  static const tour = '/tanitim';
  static const today = '/bugun';
  static const plan = '/plan';
  static const subjects = '/dersler';
  static const settings = '/ayarlar';
  static const exams = '/denemeler';
}

/// Kullanıcının kurulum akışında nerede olduğu; canlı değer.
final setupStateProvider = StreamProvider<SetupState>(
  (ref) => ref.watch(databaseProvider).watchSetupState(),
);

/// Uygulamanın yönlendiricisi.
///
/// Kurulum, uygulamanın ittiği bir ekran değil; bir yönlendirmedir.
/// Yönlendirici [setupStateProvider] değerini izler ve kullanıcı, verisinin
/// söylediği yere düşer. Yani kurulumu bitirmek ya da hata ayıklama menüsünden
/// veritabanını silmek, çağrı yerinde hiçbir gezinme koduna ihtiyaç duymaz.
final routerProvider = Provider<GoRouter>((ref) {
  // GoRouter sağlayıcı değil Listenable aldığı için ikisini burada
  // köprülüyoruz. Her durum değişiminde Provider'ı yeniden kurmak yeni bir
  // GoRouter üretir ve gezinme yığınını düşürürdü; bu yüzden watch değil
  // listen kullanılıyor.
  final refresh = ValueNotifier<AsyncValue<SetupState>>(const AsyncLoading());
  ref.onDispose(refresh.dispose);
  ref.listen<AsyncValue<SetupState>>(
    setupStateProvider,
    (previous, next) => refresh.value = next,
    fireImmediately: true,
  );

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: Routes.tour,
        builder: (context, state) => const IntroTourScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomeScreen(),
        routes: [
          GoRoute(
            // İç içe: seçim ekranı karşılama ekranına dönen geri okunu korusun.
            path: 'sablon',
            builder: (context, state) => const TemplatePickerScreen(),
          ),
        ],
      ),
      // Sekmeler ayrı gezinme yığınları taşıyor: Dersler sekmesinde bir
      // konunun içindeyken Bugün'e geçip geri dönmek kullanıcıyı kaldığı
      // yerde bulmalı.
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        // Varsayılan IndexedStack sekmeleri anında değiştiriyor; geçişi
        // yumuşatmak için kendi kapsayıcımızı veriyoruz. Dalların yığını
        // yine korunuyor.
        navigatorContainerBuilder: (context, navigationShell, children) =>
            BranchSwitcher(shell: navigationShell, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.plan,
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.subjects,
                builder: (context, state) => const SubjectsScreen(),
                routes: [
                  GoRoute(
                    path: ':subjectId',
                    builder: (context, state) => TopicListScreen(
                      subjectId: int.parse(state.pathParameters['subjectId']!),
                      // Ders adı `extra` ile taşınıyor; yoksa başlık için tek
                      // satırlık bir sorgu açmak gerekirdi.
                      subjectName: state.extra as String? ?? 'Ders',
                    ),
                    routes: [
                      GoRoute(
                        path: ':topicId',
                        builder: (context, state) => TopicDetailScreen(
                          subjectId:
                              int.parse(state.pathParameters['subjectId']!),
                          topicId: int.parse(state.pathParameters['topicId']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.exams,
                builder: (context, state) => const ExamListScreen(),
                routes: [
                  GoRoute(
                    path: 'yeni',
                    builder: (context, state) => const ExamEditorScreen(),
                  ),
                  GoRoute(
                    path: ':examId',
                    builder: (context, state) => ExamDetailScreen(
                      examId: int.parse(state.pathParameters['examId']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final setup = refresh.value;
      final location = state.matchedLocation;

      // İlk veritabanı okuması hızlı ama anlık değil; geri dönen kullanıcıya
      // karşılama ekranını bir an gösterip almaktansa açılışta bekletiyoruz.
      if (setup.isLoading) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final state0 = setup.value ?? SetupState.initial;

      // Akış tek yönlü: şablon seçimi → tanıtım → uygulama. Her adım kendi
      // bayrağını yazıyor, yönlendirici de yalnızca bayraklara bakıyor; bu
      // yüzden hiçbir ekranın "sıradaki neresi" bilmesi gerekmiyor.
      if (!state0.onboarded) {
        return location.startsWith(Routes.welcome) ? null : Routes.welcome;
      }
      if (!state0.tourSeen) {
        return location == Routes.tour ? null : Routes.tour;
      }

      final inSetup = location.startsWith(Routes.welcome) ||
          location == Routes.tour ||
          location == Routes.splash;
      return inSetup ? Routes.today : null;
    },
  );
});

/// İlk sorgunun sürdüğü birkaç kare boyunca gösterilen boş zemin. Bilerek
/// boş: 80 ms görünen bir dönen çember ilerleme değil, takılma gibi okunur.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold();
}
