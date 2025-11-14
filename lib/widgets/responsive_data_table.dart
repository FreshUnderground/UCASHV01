import 'package:flutter/material.dart';
import 'responsive_card.dart';

/// Table de données responsive qui s'adapte à toutes les tailles d'écran
class ResponsiveDataTable extends StatelessWidget {
  final List<ResponsiveDataColumn> columns;
  final List<ResponsiveDataRow> rows;
  final String? title;
  final List<Widget>? actions;
  final Widget? emptyWidget;
  final bool showCheckboxColumn;
  final bool sortAscending;
  final int? sortColumnIndex;
  final Function(int, bool)? onSort;

  const ResponsiveDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.title,
    this.actions,
    this.emptyWidget,
    this.showCheckboxColumn = false,
    this.sortAscending = true,
    this.sortColumnIndex,
    this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    
    if (rows.isEmpty && emptyWidget != null) {
      return emptyWidget!;
    }

    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec titre et actions
          if (title != null || actions != null)
            _buildHeader(context),
          
          // Table ou liste selon la taille d'écran
          if (isMobile)
            _buildMobileList(context)
          else
            _buildDesktopTable(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (title != null)
            Text(
              title!,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 768 ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
          if (actions != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions!,
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: showCheckboxColumn,
        sortAscending: sortAscending,
        sortColumnIndex: sortColumnIndex,
        columns: columns.map((col) => DataColumn(
          label: Text(
            col.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onSort: col.onSort,
        )).toList(),
        rows: rows.map((row) => DataRow(
          cells: row.cells.map((cell) => DataCell(cell)).toList(),
          onSelectChanged: row.onTap != null ? (_) => row.onTap!() : null,
        )).toList(),
      ),
    );
  }

  Widget _buildMobileList(BuildContext context) {
    return Column(
      children: rows.map((row) => _buildMobileCard(context, row)).toList(),
    );
  }

  Widget _buildMobileCard(BuildContext context, ResponsiveDataRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: row.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < columns.length && i < row.cells.length; i++)
                if (row.cells[i] is! IconButton && row.cells[i] is! PopupMenuButton)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            '${columns[i].label}:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: row.cells[i]),
                      ],
                    ),
                  ),
              // Actions en bas pour mobile
              if (row.cells.any((cell) => cell is IconButton || cell is PopupMenuButton))
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: row.cells
                      .where((cell) => cell is IconButton || cell is PopupMenuButton)
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colonne de données responsive
class ResponsiveDataColumn {
  final String label;
  final Function(int, bool)? onSort;

  const ResponsiveDataColumn({
    required this.label,
    this.onSort,
  });
}

/// Ligne de données responsive
class ResponsiveDataRow {
  final List<Widget> cells;
  final VoidCallback? onTap;

  const ResponsiveDataRow({
    required this.cells,
    this.onTap,
  });
}

/// Widget de liste responsive avec recherche et filtres
class ResponsiveListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final String? title;
  final List<Widget>? actions;
  final Widget? emptyWidget;
  final String Function(T)? searchFilter;
  final List<ResponsiveFilter<T>>? filters;
  final bool showSearch;

  const ResponsiveListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.title,
    this.actions,
    this.emptyWidget,
    this.searchFilter,
    this.filters,
    this.showSearch = true,
  });

  @override
  State<ResponsiveListView<T>> createState() => _ResponsiveListViewState<T>();
}

class _ResponsiveListViewState<T> extends State<ResponsiveListView<T>> {
  final _searchController = TextEditingController();
  final Map<String, dynamic> _filterValues = {};
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_applyFilters);
  }

  @override
  void didUpdateWidget(ResponsiveListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _applyFilters();
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredItems = widget.items.where((item) {
        // Filtre de recherche
        if (widget.searchFilter != null && _searchController.text.isNotEmpty) {
          final searchText = widget.searchFilter!(item).toLowerCase();
          if (!searchText.contains(_searchController.text.toLowerCase())) {
            return false;
          }
        }

        // Filtres personnalisés
        if (widget.filters != null) {
          for (final filter in widget.filters!) {
            final filterValue = _filterValues[filter.key];
            if (filterValue != null && !filter.predicate(item, filterValue)) {
              return false;
            }
          }
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (widget.title != null || widget.actions != null)
            _buildHeader(),
          
          // Barre de recherche et filtres
          if (widget.showSearch || widget.filters != null)
            _buildSearchAndFilters(),
          
          // Liste des éléments
          if (_filteredItems.isEmpty && widget.emptyWidget != null)
            widget.emptyWidget!
          else
            ..._filteredItems.map((item) => widget.itemBuilder(context, item)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.title != null)
            Text(
              widget.title!,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 768 ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
          if (widget.actions != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.actions!,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Barre de recherche
          if (widget.showSearch)
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          
          // Filtres
          if (widget.filters != null) ...[
            const SizedBox(height: 12),
            ResponsiveGrid(
              forceColumns: context.isMobile ? 1 : widget.filters!.length > 3 ? 3 : widget.filters!.length,
              children: widget.filters!.map((filter) => _buildFilter(filter)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilter(ResponsiveFilter<T> filter) {
    return DropdownButtonFormField<dynamic>(
      value: _filterValues[filter.key],
      decoration: InputDecoration(
        labelText: filter.label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('Tous')),
        ...filter.options.map((option) => DropdownMenuItem(
          value: option.value,
          child: Text(option.label),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _filterValues[filter.key] = value;
        });
        _applyFilters();
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

/// Filtre pour ResponsiveListView
class ResponsiveFilter<T> {
  final String key;
  final String label;
  final List<FilterOption> options;
  final bool Function(T item, dynamic value) predicate;

  const ResponsiveFilter({
    required this.key,
    required this.label,
    required this.options,
    required this.predicate,
  });
}

/// Option de filtre
class FilterOption {
  final String label;
  final dynamic value;

  const FilterOption({
    required this.label,
    required this.value,
  });
}

/// Widget d'état vide responsive
class ResponsiveEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const ResponsiveEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveCard(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: context.isMobile ? 64 : 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: context.isMobile ? 16 : 24),
            Text(
              title,
              style: TextStyle(
                fontSize: context.isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: context.isMobile ? 8 : 12),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: context.isMobile ? 14 : 16,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: context.isMobile ? 16 : 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
