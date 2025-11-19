import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/shop_service.dart';
import '../../utils/responsive_utils.dart';
import '../../theme/ucash_typography.dart';
import '../../theme/ucash_containers.dart';

class ReportFiltersWidget extends StatefulWidget {
  final bool showShopFilter;
  final int? selectedShopId;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(int?)? onShopChanged;
  final Function(DateTime?, DateTime?)? onDateRangeChanged;
  final VoidCallback? onReset;

  const ReportFiltersWidget({
    super.key,
    this.showShopFilter = false,
    this.selectedShopId,
    this.startDate,
    this.endDate,
    this.onShopChanged,
    this.onDateRangeChanged,
    this.onReset,
  });

  @override
  State<ReportFiltersWidget> createState() => _ReportFiltersWidgetState();
}

class _ReportFiltersWidgetState extends State<ReportFiltersWidget> {
  String _selectedPeriod = 'custom';
  bool _isExpanded = false; // Already set to false to hide filters by default
  
  final Map<String, String> _periodOptions = {
    'today': 'Aujourd\'hui',
    'week': 'Cette semaine',
    'month': 'Ce mois',
    'year': 'Cette année',
    'custom': 'Période personnalisée',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
        ),
      ),
      child: Padding(
        padding: ResponsiveUtils.getFluidPadding(
          context,
          mobile: const EdgeInsets.all(12),
          tablet: const EdgeInsets.all(14),
          desktop: const EdgeInsets.all(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header adaptatif
            _buildFilterHeader(context.isSmallScreen),
            
            // Filtres avec animation d'ouverture/fermeture
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                        
                        // Filtres adaptatifs
                        _buildResponsiveFilters(context.isSmallScreen, context.isTablet),
                        
                        // Résumé de la période sélectionnée
                        if (widget.startDate != null || widget.endDate != null)
                          Container(
                            margin: EdgeInsets.only(top: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                            padding: ResponsiveUtils.getFluidPadding(
                              context,
                              mobile: const EdgeInsets.all(6),
                              tablet: const EdgeInsets.all(7),
                              desktop: const EdgeInsets.all(8),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                              ),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline, 
                                  color: Colors.blue[700], 
                                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 14, tablet: 15, desktop: 16),
                                ),
                                SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
                                Flexible(
                                  child: Text(
                                    _getPeriodSummary(),
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 11.5, desktop: 12),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _applyPeriodFilter(String period) {
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    switch (period) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'week':
        final weekday = now.weekday;
        startDate = now.subtract(Duration(days: weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'custom':
        // Ne pas modifier les dates pour la période personnalisée
        return;
    }

    if (widget.onDateRangeChanged != null) {
      widget.onDateRangeChanged!(startDate, endDate);
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null && widget.onDateRangeChanged != null) {
      widget.onDateRangeChanged!(date, widget.endDate);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.endDate ?? DateTime.now(),
      firstDate: widget.startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null && widget.onDateRangeChanged != null) {
      widget.onDateRangeChanged!(widget.startDate, date);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getPeriodSummary() {
    if (widget.startDate != null && widget.endDate != null) {
      return 'Du ${_formatDate(widget.startDate!)} au ${_formatDate(widget.endDate!)}';
    } else if (widget.startDate != null) {
      return 'À partir du ${_formatDate(widget.startDate!)}';
    } else if (widget.endDate != null) {
      return 'Jusqu\'au ${_formatDate(widget.endDate!)}';
    }
    return '';
  }

  Widget _buildFilterHeader(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_list, 
                color: Colors.grey[600], 
                size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
              ),
              SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
              Text(
                'Filtres',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 15, tablet: 16, desktop: 17),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              // Bouton toggle pour afficher/cacher les filtres
              IconButton(
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[600],
                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
                ),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                tooltip: _isExpanded ? 'Masquer les filtres' : 'Afficher les filtres',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (widget.onReset != null && _isExpanded) ...[
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 9, desktop: 10)),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedPeriod = 'custom';
                  });
                  widget.onReset!();
                },
                icon: Icon(
                  Icons.clear, 
                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 14, tablet: 15, desktop: 16),
                ),
                label: Text(
                  'Effacer les filtres',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 13, tablet: 14, desktop: 15),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.filter_list, 
          color: Colors.grey[600], 
          size: ResponsiveUtils.getFluidIconSize(context, mobile: 22, tablet: 23, desktop: 24),
        ),
        SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 11, desktop: 12)),
        Text(
          'Filtres',
          style: TextStyle(
            fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 18, tablet: 19, desktop: 20),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
          ),
        ),
        const Spacer(),
        // Bouton toggle pour afficher/cacher les filtres
        IconButton(
          icon: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.grey[600],
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 22, tablet: 23, desktop: 24),
          ),
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
          tooltip: _isExpanded ? 'Masquer les filtres' : 'Afficher les filtres',
        ),
        SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
        if (widget.onReset != null && _isExpanded)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedPeriod = 'custom';
              });
              widget.onReset!();
            },
            icon: Icon(
              Icons.clear, 
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 16, tablet: 17, desktop: 18),
            ),
            label: Text(
              'Reset',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
          ),
      ],
    );
  }

  Widget _buildResponsiveFilters(bool isMobile, bool isTablet) {
    if (isMobile) {
      return Column(
        children: [
          // Sélection de shop (si activée)
          if (widget.showShopFilter) ...[
            Consumer<ShopService>(
              builder: (context, shopService, child) {
                return DropdownButtonFormField<int?>(
                  value: widget.selectedShopId,
                  decoration: InputDecoration(
                    labelText: 'Shop',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 8, desktop: 10),
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.store,
                      size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                    ),
                    contentPadding: ResponsiveUtils.getFluidPadding(
                      context,
                      mobile: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    labelStyle: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    ),
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Tous les shops',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        ),
                      ),
                    ),
                    ...shopService.shops.map((shop) => DropdownMenuItem<int?>(
                      value: shop.id,
                      child: Text(
                        shop.designation,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        ),
                      ),
                    )),
                  ],
                  onChanged: widget.onShopChanged,
                  dropdownColor: Colors.white,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  ),
                );
              },
            ),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 12)),
          ],
          
          // Sélection de période
          DropdownButtonFormField<String>(
            value: _selectedPeriod,
            decoration: InputDecoration(
              labelText: 'Période',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 8, desktop: 10),
                ),
              ),
              prefixIcon: Icon(
                Icons.date_range,
                size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
              ),
              contentPadding: ResponsiveUtils.getFluidPadding(
                context,
                mobile: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              labelStyle: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
              ),
            ),
            items: _periodOptions.entries.map((entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                ),
              ),
            )).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
              });
              _applyPeriodFilter(value!);
            },
            dropdownColor: Colors.white,
            style: TextStyle(
              color: Colors.black87,
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
            ),
          ),
          
          // Dates personnalisées (si période personnalisée)
          if (_selectedPeriod == 'custom') ...[
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 12)),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectStartDate(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Début',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 8, desktop: 10),
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          size: ResponsiveUtils.getFluidIconSize(context, mobile: 16, tablet: 18, desktop: 20),
                        ),
                        contentPadding: ResponsiveUtils.getFluidPadding(
                          context,
                          mobile: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        labelStyle: TextStyle(
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 13, tablet: 14, desktop: 15),
                        ),
                      ),
                      child: Text(
                        widget.startDate != null
                            ? _formatDate(widget.startDate!)
                            : 'Sélectionner',
                        style: TextStyle(
                          color: widget.startDate != null ? Colors.black : Colors.grey[600],
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 12)),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectEndDate(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fin',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 8, desktop: 10),
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          size: ResponsiveUtils.getFluidIconSize(context, mobile: 16, tablet: 18, desktop: 20),
                        ),
                        contentPadding: ResponsiveUtils.getFluidPadding(
                          context,
                          mobile: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        labelStyle: TextStyle(
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 13, tablet: 14, desktop: 15),
                        ),
                      ),
                      child: Text(
                        widget.endDate != null
                            ? _formatDate(widget.endDate!)
                            : 'Sélectionner',
                        style: TextStyle(
                          color: widget.endDate != null ? Colors.black : Colors.grey[600],
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Layout desktop/tablet avec Wrap adaptatif
    return Wrap(
      spacing: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 16),
      runSpacing: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 16),
      children: [
        // Sélection de shop (si activée)
        if (widget.showShopFilter)
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: context.fluidWidth(mobile: 180, tablet: 200, desktop: 250),
              maxWidth: context.fluidWidth(mobile: 200, tablet: 220, desktop: 280),
            ),
            child: Consumer<ShopService>(
              builder: (context, shopService, child) {
                return DropdownButtonFormField<int?>(
                  value: widget.selectedShopId,
                  decoration: InputDecoration(
                    labelText: 'Shop',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 8, desktop: 10),
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.store,
                      size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                    ),
                    contentPadding: ResponsiveUtils.getFluidPadding(
                      context,
                      mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    labelStyle: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 15, tablet: 16, desktop: 17),
                    ),
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Tous les shops',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 15, tablet: 16, desktop: 17),
                        ),
                      ),
                    ),
                    ...shopService.shops.map((shop) => DropdownMenuItem<int?>(
                      value: shop.id,
                      child: Text(
                        shop.designation,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 15, tablet: 16, desktop: 17),
                        ),
                      ),
                    )),
                  ],
                  onChanged: widget.onShopChanged,
                  dropdownColor: Colors.white,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 15, tablet: 16, desktop: 17),
                  ),
                );
              },
            ),
          ),
        
        // Sélection de période
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: context.fluidWidth(mobile: 140, tablet: 160, desktop: 200),
            maxWidth: context.fluidWidth(mobile: 160, tablet: 180, desktop: 220),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedPeriod,
            decoration: InputDecoration(
              labelText: 'Période',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 8, desktop: 10),
                ),
              ),
              prefixIcon: Icon(
                Icons.date_range,
                size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
              ),
              contentPadding: ResponsiveUtils.getFluidPadding(
                context,
                mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              labelStyle: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 15, tablet: 16, desktop: 17),
              ),
            ),
            items: _periodOptions.entries.map((entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 15, tablet: 16, desktop: 17),
                ),
              ),
            )).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
              });
              _applyPeriodFilter(value!);
            },
            dropdownColor: Colors.white,
            style: TextStyle(
              color: Colors.black87,
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 15, tablet: 16, desktop: 17),
            ),
          ),
        ),
        
        // Date de début (si période personnalisée)
        if (_selectedPeriod == 'custom')
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: context.fluidWidth( mobile: 120, tablet: 140, desktop: 180),
              maxWidth: context.fluidWidth( mobile: 140, tablet: 160, desktop: 200),
            ),
            child: InkWell(
              onTap: () => _selectStartDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date de début',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 8, desktop: 10),
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.calendar_today,
                    size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                  ),
                  contentPadding: ResponsiveUtils.getFluidPadding(
                    context,
                    mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  labelStyle: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  ),
                ),
                child: Text(
                  widget.startDate != null
                      ? _formatDate(widget.startDate!)
                      : 'Sélectionner',
                  style: TextStyle(
                    color: widget.startDate != null ? Colors.black : Colors.grey[600],
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 15, tablet: 16, desktop: 17),
                  ),
                ),
              ),
            ),
          ),
        
        // Date de fin (si période personnalisée)
        if (_selectedPeriod == 'custom')
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: context.fluidWidth( mobile: 120, tablet: 140, desktop: 180),
              maxWidth: context.fluidWidth( mobile: 140, tablet: 160, desktop: 200),
            ),
            child: InkWell(
              onTap: () => _selectEndDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date de fin',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 8, desktop: 10),
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.calendar_today,
                    size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                  ),
                  contentPadding: ResponsiveUtils.getFluidPadding(
                    context,
                    mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  labelStyle: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  ),
                ),
                child: Text(
                  widget.endDate != null
                      ? _formatDate(widget.endDate!)
                      : 'Sélectionner',
                  style: TextStyle(
                    color: widget.endDate != null ? Colors.black : Colors.grey[600],
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 15, tablet: 16, desktop: 17),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
