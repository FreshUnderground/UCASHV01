import 'package:flutter/material.dart';
import 'responsive_card.dart';

/// Dialog responsive qui s'adapte à toutes les tailles d'écran
class ResponsiveFormDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double? maxWidth;
  final double? maxHeight;
  final bool scrollable;
  final EdgeInsetsGeometry? contentPadding;
  final Color? backgroundColor;
  final IconData? titleIcon;

  const ResponsiveFormDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.maxWidth,
    this.maxHeight,
    this.scrollable = true,
    this.contentPadding,
    this.backgroundColor,
    this.titleIcon,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 768 && size.width <= 1024;
    final isMobile = size.width <= 768;

    // Dimensions adaptatives
    double dialogWidth;
    double dialogHeight;
    
    if (isDesktop) {
      dialogWidth = maxWidth ?? size.width * 0.4;
      dialogHeight = maxHeight ?? size.height * 0.8;
    } else if (isTablet) {
      dialogWidth = maxWidth ?? size.width * 0.7;
      dialogHeight = maxHeight ?? size.height * 0.85;
    } else {
      dialogWidth = maxWidth ?? size.width * 0.95;
      dialogHeight = maxHeight ?? size.height * 0.9;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 8 : 16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context, isMobile),
            
            // Content
            Expanded(
              child: scrollable
                ? SingleChildScrollView(
                    padding: contentPadding ?? EdgeInsets.all(isMobile ? 16 : 24),
                    child: child,
                  )
                : Padding(
                    padding: contentPadding ?? EdgeInsets.all(isMobile ? 16 : 24),
                    child: child,
                  ),
            ),
            
            // Actions
            if (actions != null) _buildActions(context, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: const BoxDecoration(
        color: Color(0xFFDC2626),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          if (titleIcon != null) ...[
            Icon(
              titleIcon,
              color: Colors.white,
              size: isMobile ? 20 : 24,
            ),
            SizedBox(width: isMobile ? 8 : 12),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            iconSize: isMobile ? 20 : 24,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: actions!.first,  // Utiliser directement le widget d'action
    );
  }
}

/// Form field responsive avec validation
class ResponsiveFormField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? hintText;
  final int? maxLines;
  final bool enabled;
  final VoidCallback? onTap;
  final bool readOnly;

  const ResponsiveFormField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.hintText,
    this.maxLines = 1,
    this.enabled = true,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: isMobile ? 6 : 8),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            obscureText: obscureText,
            maxLines: maxLines,
            enabled: enabled,
            onTap: onTap,
            readOnly: readOnly,
            style: TextStyle(fontSize: isMobile ? 14 : 16),
            decoration: InputDecoration(
              hintText: hintText,
              suffixIcon: suffixIcon,
              prefixIcon: prefixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey[100],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown responsive
class ResponsiveDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final String? hintText;
  final bool enabled;

  const ResponsiveDropdownField({
    super.key,
    required this.label,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.hintText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: isMobile ? 6 : 8),
          DropdownButtonFormField<T>(
            value: value,
            items: items,
            onChanged: enabled ? onChanged : null,
            validator: validator,
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
              ),
              contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey[100],
            ),
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// Boutons d'action responsifs
class ResponsiveActionButtons extends StatelessWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onSave;
  final String cancelText;
  final String saveText;
  final bool isLoading;
  final bool saveEnabled;

  const ResponsiveActionButtons({
    super.key,
    this.onCancel,
    this.onSave,
    this.cancelText = 'Annuler',
    this.saveText = 'Enregistrer',
    this.isLoading = false,
    this.saveEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    
    if (isMobile) {
      // Layout vertical pour mobile
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: isLoading || !saveEnabled ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(saveText, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: isLoading ? null : onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(cancelText, style: const TextStyle(fontSize: 16)),
          ),
        ],
      );
    } else {
      // Layout horizontal pour desktop/tablet
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: isLoading ? null : onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(cancelText),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isLoading || !saveEnabled ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(saveText),
          ),
        ],
      );
    }
  }
}
