import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../router/app_router.dart';

class MainScreen extends ConsumerStatefulWidget {
  final Widget child;
  final String currentLocation;

  const MainScreen({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  static const List<_NavItem> _navItems = <_NavItem>[
    _NavItem(
      route: AppRoutes.home,
      label: 'Inicio',
      icon: Icons.home_rounded,
      semanticsLabel: 'Navegar a inicio',
      keyName: 'home',
    ),
    _NavItem(
      route: AppRoutes.github,
      label: 'GitHub Data',
      faIcon: FontAwesomeIcons.github,
      semanticsLabel: 'Navegar a dashboard de GitHub',
      keyName: 'github',
    ),
    _NavItem(
      route: AppRoutes.stackoverflow,
      label: 'StackOverflow Data',
      faIcon: FontAwesomeIcons.stackOverflow,
      semanticsLabel: 'Navegar a dashboard de StackOverflow',
      keyName: 'stackoverflow',
    ),
    _NavItem(
      route: AppRoutes.reddit,
      label: 'Reddit Data',
      faIcon: FontAwesomeIcons.reddit,
      semanticsLabel: 'Navegar a dashboard de Reddit',
      keyName: 'reddit',
    ),
  ];

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  static const int _maxRestoreAttempts = 30;
  late final ScrollController _pageScrollController;
  late final FocusNode _scrollFocusNode;
  double? _pendingHomeScrollOffset;
  int _restoreAttempts = 0;

  @override
  void initState() {
    super.initState();
    _pageScrollController = ScrollController();
    _scrollFocusNode = FocusNode(debugLabel: 'main-scroll-focus');
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLocation != widget.currentLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageScrollController.hasClients) {
          final bool returningHome = widget.currentLocation == AppRoutes.home;
          final double? savedOffset = ref.read(homeReturnScrollOffsetProvider);
          if (returningHome && savedOffset != null) {
            _pendingHomeScrollOffset = savedOffset;
            _restoreAttempts = 0;
            _scheduleHomeRestore();
            return;
          }
          _pageScrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    _scrollFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MainScreenView(
      parent: widget,
      scrollController: _pageScrollController,
      scrollFocusNode: _scrollFocusNode,
      onScrollKeyEvent: _handleScrollKeys,
    );
  }

  KeyEventResult _handleScrollKeys(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final LogicalKeyboardKey key = event.logicalKey;
    const double lineStep = 150;
    const double pageStep = 560;

    if (key == LogicalKeyboardKey.arrowDown) {
      _jumpBy(lineStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _jumpBy(-lineStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown || key == LogicalKeyboardKey.space) {
      _jumpBy(pageStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      _jumpBy(-pageStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _jumpTo(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      if (_pageScrollController.hasClients) {
        _jumpTo(_pageScrollController.position.maxScrollExtent);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _jumpBy(double delta) {
    if (!_pageScrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _pageScrollController.position;
    final double target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _pageScrollController.jumpTo(target);
  }

  void _jumpTo(double offset) {
    if (!_pageScrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _pageScrollController.position;
    final double target = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _pageScrollController.jumpTo(target);
  }

  void _scheduleHomeRestore() {
    final double? pendingOffset = _pendingHomeScrollOffset;
    if (pendingOffset == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.currentLocation != AppRoutes.home) {
        return;
      }
      if (!_pageScrollController.hasClients) {
        _retryHomeRestore();
        return;
      }
      final ScrollPosition position = _pageScrollController.position;
      final double desired = pendingOffset;
      final double max = position.maxScrollExtent;
      if (max <= 0 && desired > 0) {
        _retryHomeRestore();
        return;
      }
      final double target = desired.clamp(position.minScrollExtent, max);
      if ((position.pixels - target).abs() > 0.5) {
        _pageScrollController.jumpTo(target);
      }

      final bool restored = desired <= position.minScrollExtent || max >= desired;
      if (!restored) {
        _retryHomeRestore();
        return;
      }

      _pendingHomeScrollOffset = null;
      ref.read(homeReturnScrollOffsetProvider.notifier).state = null;
    });
  }

  void _retryHomeRestore() {
    if (!mounted) {
      return;
    }
    if (_restoreAttempts >= _maxRestoreAttempts) {
      _pendingHomeScrollOffset = null;
      ref.read(homeReturnScrollOffsetProvider.notifier).state = null;
      return;
    }
    _restoreAttempts += 1;
    Future.delayed(const Duration(milliseconds: 120), _scheduleHomeRestore);
  }
}

class _MainScreenView extends StatelessWidget {
  final MainScreen parent;
  final ScrollController scrollController;
  final FocusNode scrollFocusNode;
  final KeyEventResult Function(FocusNode, KeyEvent) onScrollKeyEvent;

  const _MainScreenView({
    required this.parent,
    required this.scrollController,
    required this.scrollFocusNode,
    required this.onScrollKeyEvent,
  });

  static List<_NavItem> get _navItems => MainScreen._navItems;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        if (width < 760) {
          return _buildMobileScaffold(context);
        }
        if (width < 1100) {
          return _buildRailScaffold(context);
        }
        return _buildDesktopScaffold(context);
      },
    );
  }

  Widget _buildDesktopScaffold(BuildContext context) {
    final int selectedIndex = _selectedIndex(parent.currentLocation);
    return Scaffold(
      body: Row(
        children: <Widget>[
          Container(
            key: const Key('sidebar-desktop'),
            width: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF1E1B4B), Color(0xFF0F172A)],
              ),
            ),
            child: SafeArea(
              child: FocusTraversalGroup(
                child: Column(
                  children: <Widget>[
                    _buildSidebarHeader(),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _navItems.length,
                        itemBuilder: (BuildContext context, int index) {
                          final _NavItem item = _navItems[index];
                          return _buildDesktopNavItem(
                            context,
                            item,
                            isSelected: selectedIndex == index,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildContentArea(context, selectedIndex)),
        ],
      ),
    );
  }

  Widget _buildRailScaffold(BuildContext context) {
    final int selectedIndex = _selectedIndex(parent.currentLocation);
    return Scaffold(
      body: Row(
        children: <Widget>[
          Container(
            key: const Key('navigation-rail'),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF1E1B4B), Color(0xFF0F172A)],
              ),
            ),
            child: SafeArea(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: (int index) {
                  context.go(_navItems[index].route);
                },
                backgroundColor: Colors.transparent,
                selectedIconTheme: const IconThemeData(color: Colors.white),
                unselectedIconTheme: IconThemeData(color: Color(0xFFCBD5E1)),
                selectedLabelTextStyle: const TextStyle(color: Colors.white),
                unselectedLabelTextStyle: TextStyle(color: Color(0xFFCBD5E1)),
                labelType: NavigationRailLabelType.all,
                destinations: _navItems.map((item) {
                  return NavigationRailDestination(
                    icon: _buildIcon(item, false),
                    selectedIcon: _buildIcon(item, true),
                    label: Text(item.label),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(child: _buildContentArea(context, selectedIndex)),
        ],
      ),
    );
  }

  Widget _buildMobileScaffold(BuildContext context) {
    final int selectedIndex = _selectedIndex(parent.currentLocation);
    final String headerLabel =
        _headerLabel(parent.currentLocation, selectedIndex);
    return Scaffold(
      key: const Key('mobile-scaffold'),
      appBar: AppBar(
        key: const Key('appbar-mobile'),
        title: Text(headerLabel),
        scrolledUnderElevation: 0,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: <Widget>[
              _buildDrawerHeader(),
              for (int index = 0; index < _navItems.length; index++)
                _buildDrawerNavItem(
                  context,
                  _navItems[index],
                  isSelected: selectedIndex == index,
                ),
            ],
          ),
        ),
      ),
      body: _buildScrollableBody(),
    );
  }

  Widget _buildContentArea(BuildContext context, int selectedIndex) {
    return Container(
      color: const Color(0xFFF4F6FB),
      child: Column(
        children: <Widget>[
          _buildHeader(selectedIndex),
          Expanded(child: _buildScrollableBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(int selectedIndex) {
    final String headerLabel =
        _headerLabel(parent.currentLocation, selectedIndex);
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                headerLabel,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableBody() {
    return PrimaryScrollController(
      controller: scrollController,
      child: Focus(
        autofocus: true,
        focusNode: scrollFocusNode,
        onKeyEvent: onScrollKeyEvent,
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          child: SingleChildScrollView(
            controller: scrollController,
            primary: false,
            physics: const ClampingScrollPhysics(),
            child: parent.child,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/brand/logo-tech-trends.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tech Trends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/brand/logo-tech-trends.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tech Trends',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('Navegación'),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem(
    BuildContext context,
    _NavItem item, {
    required bool isSelected,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.semanticsLabel,
      child: InkWell(
        key: Key('nav-${item.keyName}'),
        onTap: () => context.go(item.route),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF818CF8) : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              _buildIcon(item, isSelected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.normal,
                    fontSize: 13.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerNavItem(
    BuildContext context,
    _NavItem item, {
    required bool isSelected,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.semanticsLabel,
      child: ListTile(
        key: Key('drawer-nav-${item.keyName}'),
        leading: _buildIcon(item, isSelected),
        title: Text(item.label),
        selected: isSelected,
        onTap: () {
          Navigator.of(context).pop();
          context.go(item.route);
        },
      ),
    );
  }

  Widget _buildIcon(_NavItem item, bool isSelected) {
    if (item.faIcon != null) {
      return FaIcon(
        item.faIcon,
        size: 18,
        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
      );
    }
    return Icon(
      item.icon,
      size: 20,
      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith(AppRoutes.github)) return 1;
    if (location.startsWith(AppRoutes.stackoverflow)) return 2;
    if (location.startsWith(AppRoutes.reddit)) return 3;
    if (location.startsWith('/trends/')) return 0;
    return 0;
  }

  String _headerLabel(String location, int selectedIndex) {
    if (location.startsWith('/trends/')) {
      return 'Análisis por tecnología';
    }
    return _navItems[selectedIndex].label;
  }
}

class _NavItem {
  final String route;
  final String label;
  final IconData? icon;
  final IconData? faIcon;
  final String semanticsLabel;
  final String keyName;

  const _NavItem({
    required this.route,
    required this.label,
    this.icon,
    this.faIcon,
    required this.semanticsLabel,
    required this.keyName,
  });
}
