import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Layout responsive moderne pour UCASH
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;
  final double mobileBreakpoint;
  final double tabletBreakpoint;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.desktop,
    this.tablet,
    this.mobileBreakpoint = 600,
    this.tabletBreakpoint = 1024,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < mobileBreakpoint) {
          return mobile;
        } else if (constraints.maxWidth < tabletBreakpoint) {
          return tablet ?? desktop;
        } else {
          return desktop;
        }
      },
    );
  }
}

/// Sidebar moderne et responsive
class ModernSidebar extends StatefulWidget {
  final List<SidebarItem> items;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final Widget? header;
  final Widget? footer;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const ModernSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.header,
    this.footer,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<ModernSidebar> createState() => _ModernSidebarState();
}

class _ModernSidebarState extends State<ModernSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );
    
    _widthAnimation = Tween<double>(
      begin: 280,
      end: 80,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.defaultCurve,
    ));
  }

  @override
  void didUpdateWidget(ModernSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      if (widget.isCollapsed) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        return Container(
          width: _widthAnimation.value,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: AppTheme.mediumShadow,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(AppTheme.radiusLarge),
              bottomRight: Radius.circular(AppTheme.radiusLarge),
            ),
          ),
          child: Column(
            children: [
              // Header
              if (widget.header != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing20),
                  child: widget.isCollapsed
                      ? const Icon(
                          Icons.account_balance_wallet,
                          color: AppTheme.primaryRed,
                          size: 32,
                        )
                      : widget.header!,
                ),
                const Divider(height: 1),
              ],
              
              // Toggle button
              if (widget.onToggleCollapse != null) ...[
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  child: IconButton(
                    onPressed: widget.onToggleCollapse,
                    icon: AnimatedRotation(
                      turns: widget.isCollapsed ? 0.5 : 0,
                      duration: AppTheme.normalAnimation,
                      child: const Icon(Icons.chevron_left),
                    ),
                    tooltip: widget.isCollapsed ? 'Étendre' : 'Réduire',
                  ),
                ),
                const Divider(height: 1),
              ],
              
              // Menu items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final isSelected = index == widget.selectedIndex;
                    
                    return _SidebarItemWidget(
                      item: item,
                      isSelected: isSelected,
                      isCollapsed: widget.isCollapsed,
                      onTap: () => widget.onItemSelected(index),
                    );
                  },
                ),
              ),
              
              // Footer
              if (widget.footer != null) ...[
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: widget.footer!,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SidebarItemWidget extends StatefulWidget {
  final SidebarItem item;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarItemWidget({
    required this.item,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_SidebarItemWidget> createState() => _SidebarItemWidgetState();
}

class _SidebarItemWidgetState extends State<_SidebarItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: AppTheme.fastAnimation,
      vsync: this,
    );
    
    _hoverAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: AppTheme.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _hoverController.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _hoverController.reverse();
        },
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppTheme.primaryRed.withOpacity(0.1)
                    : _isHovered
                        ? AppTheme.primaryRed.withOpacity(0.05)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: widget.isSelected
                    ? Border.all(
                        color: AppTheme.primaryRed.withOpacity(0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                      vertical: AppTheme.spacing12,
                    ),
                    child: Row(
                      children: [
                        // Icône
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacing8),
                          decoration: BoxDecoration(
                            color: widget.isSelected
                                ? AppTheme.primaryRed
                                : _isHovered
                                    ? AppTheme.primaryRed.withOpacity(0.1)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: Icon(
                            widget.item.icon,
                            color: widget.isSelected
                                ? Colors.white
                                : _isHovered
                                    ? AppTheme.primaryRed
                                    : AppTheme.textSecondary,
                            size: 20,
                          ),
                        ),
                        
                        // Titre et badge
                        if (!widget.isCollapsed) ...[
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.item.title,
                                  style: TextStyle(
                                    color: widget.isSelected
                                        ? AppTheme.primaryRed
                                        : AppTheme.textPrimary,
                                    fontWeight: widget.isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                if (widget.item.subtitle != null)
                                  Text(
                                    widget.item.subtitle!,
                                    style: const TextStyle(
                                      color: AppTheme.textLight,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          // Badge
                          if (widget.item.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing8,
                                vertical: AppTheme.spacing4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.item.badgeColor ?? AppTheme.primaryRed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.item.badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ] else if (widget.item.badge != null) ...[
                          const SizedBox(width: AppTheme.spacing4),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.item.badgeColor ?? AppTheme.primaryRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Modèle pour les éléments de sidebar
class SidebarItem {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? badge;
  final Color? badgeColor;

  const SidebarItem({
    required this.title,
    required this.icon,
    this.subtitle,
    this.badge,
    this.badgeColor,
  });
}

/// AppBar moderne et responsive
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onMenuPressed;

  const ModernAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBackButton = false,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              // Leading
              if (leading != null)
                leading!
              else if (showBackButton)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios),
                  tooltip: 'Retour',
                )
              else if (onMenuPressed != null)
                IconButton(
                  onPressed: onMenuPressed,
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menu',
                ),
              
              // Titre
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Actions
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}

/// Bottom navigation moderne
class ModernBottomNavigation extends StatelessWidget {
  final List<BottomNavItem> items;
  final int selectedIndex;
  final Function(int) onItemSelected;

  const ModernBottomNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusLarge),
          topRight: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: AppTheme.spacing8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == selectedIndex;
              
              return _BottomNavItemWidget(
                item: item,
                isSelected: isSelected,
                onTap: () => onItemSelected(index),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItemWidget extends StatefulWidget {
  final BottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_BottomNavItemWidget> createState() => _BottomNavItemWidgetState();
}

class _BottomNavItemWidgetState extends State<_BottomNavItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.fastAnimation,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => _animationController.forward(),
                onTapUp: (_) => _animationController.reverse(),
                onTapCancel: () => _animationController.reverse(),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppTheme.primaryRed.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          Icon(
                            widget.item.icon,
                            color: widget.isSelected
                                ? AppTheme.primaryRed
                                : AppTheme.textSecondary,
                            size: 24,
                          ),
                          if (widget.item.badge != null)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppTheme.error,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  widget.item.badge!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        widget.item.title,
                        style: TextStyle(
                          color: widget.isSelected
                              ? AppTheme.primaryRed
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: widget.isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Modèle pour les éléments de bottom navigation
class BottomNavItem {
  final String title;
  final IconData icon;
  final String? badge;

  const BottomNavItem({
    required this.title,
    required this.icon,
    this.badge,
  });
}
