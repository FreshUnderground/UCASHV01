import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/shop_service.dart';

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
  bool _isExpanded = true; // État pour afficher/cacher les filtres

  final Map<String, String> _periodOptions = {
    'today': 'Aujourd\'hui',
    'week': 'Cette semaine',
    'month': 'Ce mois',
    'year': 'Cette année',
    'custom': 'Période personnalisée',
  };

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header adaptatif
            _buildFilterHeader(isMobile),
            
            // Filtres avec animation d'ouverture/fermeture
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: isMobile ? 12 : 16),
                        
                        // Filtres adaptatifs
                        _buildResponsiveFilters(isMobile, isTablet),
                        
                        // Résumé de la période sélectionnée
                        if (widget.startDate != null || widget.endDate != null)
                          Container(
                            margin: EdgeInsets.only(top: isMobile ? 8 : 12),
                            padding: EdgeInsets.all(isMobile ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _getPeriodSummary(),
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: isMobile ? 11 : 12,
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
              Icon(Icons.filter_list, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              // Bouton toggle pour afficher/cacher les filtres
              IconButton(
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[600],
                ),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                tooltip: _isExpanded ? 'Masquer les filtres' : 'Afficher les filtres',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (widget.onReset != null && _isExpanded) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedPeriod = 'custom';
                  });
                  widget.onReset!();
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Effacer les filtres'),
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
        Icon(Icons.filter_list, color: Colors.grey[600]),
        const SizedBox(width: 8),
        const Text(
          'Filtres',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const Spacer(),
        // Bouton toggle pour afficher/cacher les filtres
        IconButton(
          icon: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.grey[600],
          ),
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
          tooltip: _isExpanded ? 'Masquer les filtres' : 'Afficher les filtres',
        ),
        if (widget.onReset != null && _isExpanded)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedPeriod = 'custom';
              });
              widget.onReset!();
            },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Reset'),
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
                  decoration: const InputDecoration(
                    labelText: 'Shop',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tous les shops'),
                    ),
                    ...shopService.shops.map((shop) => DropdownMenuItem<int?>(
                      value: shop.id,
                      child: Text(shop.designation),
                    )),
                  ],
                  onChanged: widget.onShopChanged,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          
          // Sélection de période
          DropdownButtonFormField<String>(
            value: _selectedPeriod,
            decoration: const InputDecoration(
              labelText: 'Période',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.date_range),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _periodOptions.entries.map((entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            )).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
              });
              _applyPeriodFilter(value!);
            },
          ),
          
          // Dates personnalisées (si période personnalisée)
          if (_selectedPeriod == 'custom') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectStartDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Début',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        widget.startDate != null
                            ? _formatDate(widget.startDate!)
                            : 'Sélectionner',
                        style: TextStyle(
                          color: widget.startDate != null ? Colors.black : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectEndDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fin',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        widget.endDate != null
                            ? _formatDate(widget.endDate!)
                            : 'Sélectionner',
                        style: TextStyle(
                          color: widget.endDate != null ? Colors.black : Colors.grey[600],
                          fontSize: 14,
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
      spacing: isTablet ? 12 : 16,
      runSpacing: isTablet ? 12 : 16,
      children: [
        // Sélection de shop (si activée)
        if (widget.showShopFilter)
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: isTablet ? 200 : 250,
              maxWidth: isTablet ? 220 : 280,
            ),
            child: Consumer<ShopService>(
              builder: (context, shopService, child) {
                return DropdownButtonFormField<int?>(
                  value: widget.selectedShopId,
                  decoration: const InputDecoration(
                    labelText: 'Shop',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tous les shops'),
                    ),
                    ...shopService.shops.map((shop) => DropdownMenuItem<int?>(
                      value: shop.id,
                      child: Text(shop.designation),
                    )),
                  ],
                  onChanged: widget.onShopChanged,
                );
              },
            ),
          ),
        
        // Sélection de période
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: isTablet ? 160 : 200,
            maxWidth: isTablet ? 180 : 220,
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedPeriod,
            decoration: const InputDecoration(
              labelText: 'Période',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.date_range),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _periodOptions.entries.map((entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            )).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
              });
              _applyPeriodFilter(value!);
            },
          ),
        ),
        
        // Date de début (si période personnalisée)
        if (_selectedPeriod == 'custom')
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: isTablet ? 140 : 180,
              maxWidth: isTablet ? 160 : 200,
            ),
            child: InkWell(
              onTap: () => _selectStartDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de début',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  widget.startDate != null
                      ? _formatDate(widget.startDate!)
                      : 'Sélectionner',
                  style: TextStyle(
                    color: widget.startDate != null ? Colors.black : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        
        // Date de fin (si période personnalisée)
        if (_selectedPeriod == 'custom')
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: isTablet ? 140 : 180,
              maxWidth: isTablet ? 160 : 200,
            ),
            child: InkWell(
              onTap: () => _selectEndDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de fin',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  widget.endDate != null
                      ? _formatDate(widget.endDate!)
                      : 'Sélectionner',
                  style: TextStyle(
                    color: widget.endDate != null ? Colors.black : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
