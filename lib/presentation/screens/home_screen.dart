import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../../domain/entities/transaction.dart';
import '../providers/advice_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/budget_providers.dart';
import '../providers/category_providers.dart';
import '../providers/home_providers.dart';
import '../providers/receipt_scan_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/transaction_providers.dart';
import '../widgets/budget_warning_banner.dart';
import '../widgets/error_view.dart';
import '../widgets/gamification_feedback_listener.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/transaction_delete.dart';
import 'advice_screen.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'receipt_scan_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'transaction_form_screen.dart';
import 'transactions_screen.dart';

class _HomeTab {
  const _HomeTab(this.label, this.icon, this.selectedIcon, this.build);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() build;
}

/// The app's main shell: bottom navigation over Home (the dashboard),
/// Transactions, Budgets, Reports and Profile (Settings). Tabs are built
/// lazily, the first time they are opened.
///
/// The fourth slot is **Reports**, as in the approved mockup. AI Insights is
/// no longer a tab: it lives inside Reports → Trends → Insights, and on the
/// Home AI card. Rewards is reached from Home (quick action / More) — the
/// mockups put both Reports and Rewards in the same five-slot bar, and only
/// one of them fits.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _tab = 'Home';
  final Set<String> _visited = <String>{'Home'};

  void _select(String label) => setState(() {
    _tab = label;
    _visited.add(label);
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <_HomeTab>[
      _HomeTab(
        'Home',
        Icons.home_outlined,
        Icons.home_rounded,
        () => _Dashboard(
          onOpenTransactions: () => _select('Transactions'),
          onOpenBudgets: () => _select('Budgets'),
          onOpenReports: () => _select('Reports'),
          onOpenProfile: () => _select('Profile'),
        ),
      ),
      const _HomeTab(
        'Transactions',
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        TransactionsScreen.new,
      ),
      const _HomeTab(
        'Budgets',
        Icons.bar_chart_outlined,
        Icons.bar_chart,
        BudgetsScreen.new,
      ),
      const _HomeTab(
        'Reports',
        Icons.pie_chart_outline,
        Icons.pie_chart,
        ReportsScreen.new,
      ),
      const _HomeTab(
        'Profile',
        Icons.person_outline,
        Icons.person,
        SettingsScreen.new,
      ),
    ];
    var index = tabs.indexWhere((t) => t.label == _tab);
    if (index < 0) index = 0;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GamificationFeedbackListener(
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: <Widget>[
            for (final t in tabs)
              _visited.contains(t.label) ? t.build() : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          // Five labelled tabs cannot survive huge text; the nav bar alone is
          // capped (everything else on screen still scales fully).
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: 1.15),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                elevation: 0,
                height: 68,
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => theme.textTheme.labelSmall?.copyWith(
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: states.contains(WidgetState.selected)
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    size: 26,
                    color: states.contains(WidgetState.selected)
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => _select(tabs[i].label),
                destinations: <Widget>[
                  for (final t in tabs)
                    NavigationDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.selectedIcon),
                      label: t.label,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Home tab, laid out to the approved mockup and fed entirely by the
/// cached aggregates and local repositories (nothing here waits on the network).
class _Dashboard extends ConsumerStatefulWidget {
  const _Dashboard({
    required this.onOpenTransactions,
    required this.onOpenBudgets,
    required this.onOpenReports,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenTransactions;
  final VoidCallback onOpenBudgets;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenProfile;

  @override
  ConsumerState<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<_Dashboard> {
  /// Ids swiped away but not yet gone from the stream.
  final Set<String> _hiddenIds = <String>{};

  Future<void> _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categories'),
              onTap: () {
                Navigator.of(sheet).pop();
                _push(const CategoriesScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('Rewards'),
              onTap: () {
                Navigator.of(sheet).pop();
                _push(const StatsScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(sheet).pop();
                widget.onOpenProfile();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(localTimeProvider)();
    final name = ref.watch(currentUserFirstNameProvider);
    final balance = ref.watch(currentBalanceMinorProvider);
    final month = ref.watch(homeMonthProvider);
    final hidden = ref.watch(balanceHiddenProvider);
    final budget = ref.watch(overallMonthlyBudgetProvider);
    final warnings = ref.watch(budgetWarningsProvider);
    final categoriesById = ref.watch(allCategoriesByIdProvider);
    final txAsync = ref.watch(transactionsProvider);
    final aiOn = ref.watch(adviceConfiguredProvider);
    final scanOn = ref.watch(receiptScanConfiguredProvider);
    final tip = ref.watch(latestAdviceTipProvider).value;

    final recent = (txAsync.value ?? const <Transaction>[])
        .where((t) => !_hiddenIds.contains(t.id))
        .take(4)
        .toList(growable: false);

    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md),
      child: child,
    );
    const gap = SizedBox(height: Insets.md - 2);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(top: Insets.sm, bottom: Insets.lg),
        children: <Widget>[
          pad(
            HomeHeader(
              name: name,
              now: now,
              onProfile: widget.onOpenProfile,
              syncIndicator: const SyncStatusIndicator(),
            ),
          ),
          gap,
          pad(
            BalanceHeroCard(
              balanceMinor: balance,
              monthNetMinor: month.netMinor,
              runningNetMinor: month.cumulativeNetMinor,
              hidden: hidden,
              onToggleHidden: () =>
                  ref.read(balanceHiddenProvider.notifier).toggle(),
              onTap: widget.onOpenReports,
            ),
          ),
          gap,
          pad(
            QuickActionsRow(
              actions: <QuickAction>[
                QuickAction(
                  icon: Icons.add,
                  label: 'Add',
                  sublabel: 'Transaction',
                  filled: true,
                  onTap: () => _push(const TransactionFormScreen()),
                ),
                if (scanOn)
                  QuickAction(
                    icon: Icons.document_scanner_outlined,
                    label: 'Scan',
                    sublabel: 'Receipt',
                    onTap: () => _push(const ReceiptScanScreen()),
                  )
                else
                  QuickAction(
                    icon: Icons.emoji_events_outlined,
                    label: 'Rewards',
                    sublabel: '& Streaks',
                    onTap: () => _push(const StatsScreen()),
                  ),
                QuickAction(
                  icon: Icons.insights,
                  label: 'Reports',
                  sublabel: '& Charts',
                  onTap: widget.onOpenReports,
                ),
                QuickAction(
                  icon: Icons.more_horiz,
                  label: 'More',
                  sublabel: 'Options',
                  onTap: _showMore,
                ),
              ],
            ),
          ),
          gap,
          pad(
            MonthlySpendingCard(
              status: budget,
              onViewBudget: widget.onOpenBudgets,
            ),
          ),
          BudgetWarningBanner(warnings: warnings, onTap: widget.onOpenBudgets),
          gap,
          pad(
            TopCategoriesCard(
              slices: month.topCategories,
              categoriesById: categoriesById,
              onSeeAll: widget.onOpenReports,
            ),
          ),
          gap,
          if (txAsync.hasError)
            pad(
              ErrorView(
                message: "Couldn't load your transactions.",
                detail: txAsync.error,
                onRetry: () => ref.invalidate(transactionsProvider),
              ),
            )
          else
            pad(
              RecentTransactionsCard(
                transactions: recent,
                categoriesById: categoriesById,
                now: now,
                onSeeAll: widget.onOpenTransactions,
                onOpen: (t) => _push(TransactionFormScreen(existing: t)),
                onDelete: (t) => deleteTransactionWithUndo(
                  context: context,
                  ref: ref,
                  transaction: t,
                  onHide: () => setState(() => _hiddenIds.add(t.id)),
                  onUnhide: () => setState(() => _hiddenIds.remove(t.id)),
                ),
              ),
            ),
          if (aiOn) ...<Widget>[
            gap,
            pad(
              AiTipCard(
                tip: tip?.title,
                onTap: () => _push(const AdviceScreen()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
