import 'package:flutter/material.dart';

/// Modern responsive dialog wrapper that adapts to screen size
class ModernResponsiveDialog extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? headerColor;
  final Widget body;
  final List<Widget>? actions;
  final bool showActions;
  
  const ModernResponsiveDialog({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.headerColor,
    this.actions,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth <= 480;
    final isTablet = screenWidth > 480 && screenWidth <= 768;
    
    // Responsive sizing
    double dialogWidth;
    if (isMobile) {
      dialogWidth = screenWidth - 32; // Full width with margins
    } else if (isTablet) {
      dialogWidth = screenWidth * 0.85;
    } else {
      dialogWidth = 520; // Desktop fixed width
    }
    
    final dialogMaxHeight = isMobile
        ? screenHeight * 0.85
        : screenHeight * 0.9;
    
    final headerPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : const EdgeInsets.all(20);
    
    final contentPadding = isMobile
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(20);
    
    final titleFontSize = isMobile ? 16.0 : 18.0;
    final iconSize = isMobile ? 20.0 : 24.0;
    
    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogMaxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: headerPadding,
              decoration: BoxDecoration(
                color: headerColor ?? const Color(0xFFDC2626),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: iconSize),
                    SizedBox(width: isMobile ? 8 : 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white, size: iconSize),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: contentPadding,
                child: body,
              ),
            ),
            
            // Actions
            if (showActions && actions != null && actions!.isNotEmpty)
              Container(
                padding: contentPadding,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: isMobile
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: actions!.map((action) {
                          // Make buttons full width on mobile
                          if (action is ElevatedButton || action is OutlinedButton || action is TextButton) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SizedBox(
                                height: 48,
                                child: action,
                              ),
                            );
                          }
                          return action;
                        }).toList(),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!.map((action) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: action,
                          );
                        }).toList(),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper extension for responsive form styling
extension ResponsiveFormStyle on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width <= 480;
  bool get isTablet => MediaQuery.of(this).size.width > 480 && MediaQuery.of(this).size.width <= 768;
  bool get isDesktop => MediaQuery.of(this).size.width > 768;
  
  double get formFieldSpacing => isMobile ? 16.0 : 20.0;
  double get sectionSpacing => isMobile ? 20.0 : 24.0;
  double get labelFontSize => isMobile ? 14.0 : 16.0;
  double get inputFontSize => isMobile ? 16.0 : 18.0;
  double get iconSize => isMobile ? 20.0 : 24.0;
  
  EdgeInsets get formFieldPadding => EdgeInsets.symmetric(
    horizontal: isMobile ? 12 : 16,
    vertical: isMobile ? 12 : 16,
  );
  
  EdgeInsets get infoBannerPadding => EdgeInsets.all(isMobile ? 12 : 16);
  
  TextStyle get labelStyle => TextStyle(
    fontSize: labelFontSize,
    fontWeight: FontWeight.bold,
  );
  
  TextStyle get inputStyle => TextStyle(
    fontSize: inputFontSize,
  );
}
