import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../widgets/data_health_badge.dart';

class MainScreen extends StatelessWidget {
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
    final int selectedIndex = _selectedIndex(currentLocation);
    return Scaffold(
      body: Row(
        children: <Widget>[
          Container(
            key: const Key('sidebar-desktop'),
            width: 220,
            decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
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
    final int selectedIndex = _selectedIndex(currentLocation);
    return Scaffold(
      body: Row(
        children: <Widget>[
          Container(
            key: const Key('navigation-rail'),
            color: const Color(0xFF1A1A2E),
            child: SafeArea(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: (int index) {
                  context.go(_navItems[index].route);
                },
                backgroundColor: const Color(0xFF1A1A2E),
                selectedIconTheme: const IconThemeData(color: Colors.white),
                unselectedIconTheme: IconThemeData(color: Colors.grey[400]),
                selectedLabelTextStyle: const TextStyle(color: Colors.white),
                unselectedLabelTextStyle: TextStyle(color: Colors.grey[400]),
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
    final int selectedIndex = _selectedIndex(currentLocation);
    return Scaffold(
      key: const Key('mobile-scaffold'),
      appBar: AppBar(
        key: const Key('appbar-mobile'),
        title: Text(_navItems[selectedIndex].label),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: DataHealthBadge(compact: true),
          ),
        ],
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
      color: const Color(0xFFF5F6FA),
      child: Column(
        children: <Widget>[
          _buildHeader(selectedIndex),
          Expanded(child: _buildScrollableBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(int selectedIndex) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _navItems[selectedIndex].label,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const DataHealthBadge(),
        ],
      ),
    );
  }

  Widget _buildScrollableBody() {
    return PrimaryScrollController.none(
      child: Scrollbar(
        child: SingleChildScrollView(primary: false, child: child),
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
              gradient: const LinearGradient(
                colors: <Color>[Colors.blue, Colors.indigo],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics, color: Colors.white, size: 28),
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
    return const DrawerHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.analytics, size: 40, color: Color(0xFF1A1A2E)),
          SizedBox(height: 8),
          Text(
            'Tech Trends',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text('Navigation'),
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
                ? Colors.blue.withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: <Widget>[
              _buildIcon(item, isSelected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.normal,
                    fontSize: 13,
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
        color: isSelected ? Colors.white : Colors.grey[400],
      );
    }
    return Icon(
      item.icon,
      size: 20,
      color: isSelected ? Colors.white : Colors.grey[400],
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith(AppRoutes.github)) return 1;
    if (location.startsWith(AppRoutes.stackoverflow)) return 2;
    if (location.startsWith(AppRoutes.reddit)) return 3;
    return 0;
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
