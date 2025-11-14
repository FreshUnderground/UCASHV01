import 'package:flutter/material.dart';

/// Utility class for creating responsive dialogs
class ResponsiveDialogUtils {
  /// Get responsive dialog width based on screen size
  static double getDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth <= 480) {
      // Mobile: Full width with small margins
      return screenWidth - 32;
    } else if (screenWidth <= 768) {
      // Tablet: 90% width
      return screenWidth * 0.9;
    } else {
      // Desktop: Fixed max width
      return 500;
    }
  }
  
  /// Get responsive dialog max height
  static double getDialogMaxHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (screenHeight <= 667) {
      // Small mobile screens (iPhone SE, etc.)
      return screenHeight * 0.85;
    } else {
      return screenHeight * 0.9;
    }
  }
  
  /// Get responsive padding for dialog content
  static EdgeInsets getDialogPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth <= 480) {
      // Mobile: Smaller padding
      return const EdgeInsets.all(16);
    } else if (screenWidth <= 768) {
      // Tablet
      return const EdgeInsets.all(20);
    } else {
      // Desktop
      return const EdgeInsets.all(24);
    }
  }
  
  /// Get responsive header padding
  static EdgeInsets getHeaderPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth <= 480) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    } else {
      return const EdgeInsets.all(20);
    }
  }
  
  /// Get responsive font size for title
  static double getTitleFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth <= 480) {
      return 16;
    } else if (screenWidth <= 768) {
      return 17;
    } else {
      return 18;
    }
  }
  
  /// Get responsive font size for labels
  static double getLabelFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth <= 480) {
      return 14;
    } else {
      return 16;
    }
  }
  
  /// Get responsive spacing between form fields
  static double getFieldSpacing(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth <= 480) {
      return 16;
    } else if (screenWidth <= 768) {
      return 20;
    } else {
      return 24;
    }
  }
  
  /// Get responsive icon size
  static double getIconSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth <= 480) {
      return 20;
    } else {
      return 24;
    }
  }
  
  /// Build responsive dialog container
  static Widget buildResponsiveDialog({
    required BuildContext context,
    required Widget header,
    required Widget body,
    required Widget actions,
  }) {
    return Dialog(
      insetPadding: MediaQuery.of(context).size.width <= 480
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: getDialogWidth(context),
        constraints: BoxConstraints(
          maxHeight: getDialogMaxHeight(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                padding: getDialogPadding(context),
                child: body,
              ),
            ),
            actions,
          ],
        ),
      ),
    );
  }
  
  /// Build responsive dialog header
  static Widget buildResponsiveHeader({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    VoidCallback? onClose,
  }) {
    return Container(
      padding: getHeaderPadding(context),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: getIconSize(context)),
          SizedBox(width: MediaQuery.of(context).size.width <= 480 ? 8 : 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: getTitleFontSize(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose ?? () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: Colors.white,
              size: getIconSize(context),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
  
  /// Build responsive actions footer
  static Widget buildResponsiveActions({
    required BuildContext context,
    required List<Widget> actions,
  }) {
    final isMobile = MediaQuery.of(context).size.width <= 480;
    
    return Container(
      padding: getDialogPadding(context),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: isMobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: actions.map((action) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: action,
                );
              }).toList(),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions.map((action) {
                return Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: action,
                );
              }).toList(),
            ),
    );
  }
}
