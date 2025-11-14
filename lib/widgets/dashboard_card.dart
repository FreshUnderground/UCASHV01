import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_typography.dart';
import '../theme/ucash_containers.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: context.fluidSpacing(mobile: 3, tablet: 4, desktop: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20),
        ),
        child: Container(
          padding: context.fluidPadding(
            mobile: const EdgeInsets.all(12),
            tablet: const EdgeInsets.all(16),
            desktop: const EdgeInsets.all(20),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.12),
                color.withOpacity(0.06),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Container d'icône avec taille fluide
              Container(
                padding: EdgeInsets.all(
                  context.fluidSpacing(mobile: 8, tablet: 12, desktop: 16),
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 12, desktop: 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.1),
                      blurRadius: context.fluidSpacing(mobile: 4, tablet: 6, desktop: 8),
                      offset: Offset(0, context.fluidSpacing(mobile: 2, tablet: 3, desktop: 4)),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: context.fluidIcon(mobile: 20, tablet: 28, desktop: 36),
                  color: color,
                ),
              ),
              
              // Espacement fluide
              context.verticalSpace(mobile: 8, tablet: 12, desktop: 16),
              
              // Texte avec typographie responsive
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.label.copyWith(
                    color: color.withOpacity(0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
