import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Card moderne avec animations fluides
class ModernCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool elevated;
  final Color? backgroundColor;
  final List<BoxShadow>? customShadow;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.elevated = true,
    this.backgroundColor,
    this.customShadow,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.fastAnimation,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.defaultCurve,
    ));
    
    _elevationAnimation = Tween<double>(
      begin: widget.elevated ? 2.0 : 0.0,
      end: widget.elevated ? 8.0 : 2.0,
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
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: widget.margin ?? const EdgeInsets.all(AppTheme.spacing8),
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              boxShadow: widget.customShadow ?? 
                (widget.elevated 
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: _elevationAnimation.value * 2,
                        offset: Offset(0, _elevationAnimation.value / 2),
                      ),
                    ]
                  : null),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: widget.onTap != null ? (_) => _animationController.forward() : null,
                onTapUp: widget.onTap != null ? (_) => _animationController.reverse() : null,
                onTapCancel: widget.onTap != null ? () => _animationController.reverse() : null,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                child: Padding(
                  padding: widget.padding ?? const EdgeInsets.all(AppTheme.spacing16),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bouton moderne avec animations
class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final ModernButtonStyle style;
  final Size? size;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.style = ModernButtonStyle.primary,
    this.size,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
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
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: _buildButton(context),
        );
      },
    );
  }

  Widget _buildButton(BuildContext context) {
    final colors = _getButtonColors(context);
    
    return Container(
      width: widget.size?.width,
      height: widget.size?.height ?? 56,
      decoration: BoxDecoration(
        gradient: colors.gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: widget.style == ModernButtonStyle.primary
            ? AppTheme.softShadow
            : null,
        border: widget.style == ModernButtonStyle.outline
            ? Border.all(color: colors.borderColor!, width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onPressed,
          onTapDown: widget.onPressed != null ? (_) => _animationController.forward() : null,
          onTapUp: widget.onPressed != null ? (_) => _animationController.reverse() : null,
          onTapCancel: widget.onPressed != null ? () => _animationController.reverse() : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.textColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: colors.textColor,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                      ],
                      Text(
                        widget.text,
                        style: TextStyle(
                          color: colors.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  _ButtonColors _getButtonColors(BuildContext context) {
    switch (widget.style) {
      case ModernButtonStyle.primary:
        return _ButtonColors(
          gradient: AppTheme.primaryGradient,
          textColor: Colors.white,
        );
      case ModernButtonStyle.secondary:
        return _ButtonColors(
          gradient: LinearGradient(
            colors: [AppTheme.accentBlue, AppTheme.accentBlue.withOpacity(0.8)],
          ),
          textColor: Colors.white,
        );
      case ModernButtonStyle.success:
        return _ButtonColors(
          gradient: LinearGradient(
            colors: [AppTheme.success, AppTheme.success.withOpacity(0.8)],
          ),
          textColor: Colors.white,
        );
      case ModernButtonStyle.outline:
        return _ButtonColors(
          gradient: const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
          textColor: AppTheme.primaryRed,
          borderColor: AppTheme.primaryRed,
        );
      case ModernButtonStyle.ghost:
        return _ButtonColors(
          gradient: LinearGradient(
            colors: [AppTheme.primaryRed.withOpacity(0.1), AppTheme.primaryRed.withOpacity(0.05)],
          ),
          textColor: AppTheme.primaryRed,
        );
    }
  }
}

class _ButtonColors {
  final LinearGradient gradient;
  final Color textColor;
  final Color? borderColor;

  _ButtonColors({
    required this.gradient,
    required this.textColor,
    this.borderColor,
  });
}

enum ModernButtonStyle {
  primary,
  secondary,
  success,
  outline,
  ghost,
}

/// Input moderne avec animations
class ModernTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLines;

  const ModernTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _borderColorAnimation;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _animationController = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );
    
    _borderColorAnimation = ColorTween(
      begin: const Color(0xFFE5E7EB),
      end: AppTheme.primaryRed,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.defaultCurve,
    ));

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
        if (_isFocused) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label != null) ...[
              AnimatedDefaultTextStyle(
                duration: AppTheme.fastAnimation,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isFocused ? AppTheme.primaryRed : AppTheme.textSecondary,
                ),
                child: Text(widget.label!),
              ),
              const SizedBox(height: AppTheme.spacing8),
            ],
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: _isFocused ? AppTheme.softShadow : null,
              ),
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focusNode,
                obscureText: widget.obscureText,
                validator: widget.validator,
                keyboardType: widget.keyboardType,
                maxLines: widget.maxLines,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(
                          widget.prefixIcon,
                          color: _isFocused ? AppTheme.primaryRed : AppTheme.textLight,
                        )
                      : null,
                  suffixIcon: widget.suffixIcon != null
                      ? IconButton(
                          icon: Icon(
                            widget.suffixIcon,
                            color: _isFocused ? AppTheme.primaryRed : AppTheme.textLight,
                          ),
                          onPressed: widget.onSuffixIconTap,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide(color: _borderColorAnimation.value!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide(color: _borderColorAnimation.value!, width: 2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Badge moderne avec animations
class ModernBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final ModernBadgeStyle style;

  const ModernBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.style = ModernBadgeStyle.primary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getBadgeColors();
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? colors.backgroundColor).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: textColor ?? colors.textColor,
            ),
            const SizedBox(width: AppTheme.spacing4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor ?? colors.textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeColors _getBadgeColors() {
    switch (style) {
      case ModernBadgeStyle.primary:
        return _BadgeColors(
          backgroundColor: AppTheme.primaryRed,
          textColor: Colors.white,
        );
      case ModernBadgeStyle.success:
        return _BadgeColors(
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
        );
      case ModernBadgeStyle.warning:
        return _BadgeColors(
          backgroundColor: AppTheme.warning,
          textColor: Colors.white,
        );
      case ModernBadgeStyle.info:
        return _BadgeColors(
          backgroundColor: AppTheme.info,
          textColor: Colors.white,
        );
      case ModernBadgeStyle.light:
        return _BadgeColors(
          backgroundColor: const Color(0xFFF3F4F6),
          textColor: AppTheme.textPrimary,
        );
    }
  }
}

class _BadgeColors {
  final Color backgroundColor;
  final Color textColor;

  _BadgeColors({
    required this.backgroundColor,
    required this.textColor,
  });
}

enum ModernBadgeStyle {
  primary,
  success,
  warning,
  info,
  light,
}

/// Loading moderne
class ModernLoading extends StatefulWidget {
  final String? message;
  final double size;

  const ModernLoading({
    super.key,
    this.message,
    this.size = 40,
  });

  @override
  State<ModernLoading> createState() => _ModernLoadingState();
}

class _ModernLoadingState extends State<ModernLoading>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _scaleAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationController.value * 2 * 3.14159,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: const Icon(
                    Icons.sync,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: AppTheme.spacing16),
          Text(
            widget.message!,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
