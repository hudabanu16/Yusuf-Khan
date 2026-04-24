import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';

class PaginationBar extends StatelessWidget {
  final int totalItems;
  final int totalPages;
  final int startIndex;
  final int endIndex;
  final int rowsPerPage;
  final int currentPage;
  final ValueChanged<int?> onRowsChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PaginationBar({
    super.key,
    required this.totalItems,
    required this.totalPages,
    required this.startIndex,
    required this.endIndex,
    required this.rowsPerPage,
    required this.currentPage,
    required this.onRowsChanged,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final visibleStart = totalItems == 0 ? 0 : startIndex + 1;
    final visibleEnd = totalItems == 0 ? 0 : endIndex;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryText(visibleStart, visibleEnd),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: DropdownButtonFormField<int>(
                          initialValue: rowsPerPage,
                          onChanged: onRowsChanged,
                          isDense: true,
                          isExpanded: true,
                          decoration: _dropdownDecoration(),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: primaryColor,
                          ),
                          items: const [
                            DropdownMenuItem(value: 10, child: Text('10')),
                            DropdownMenuItem(value: 25, child: Text('25')),
                            DropdownMenuItem(value: 50, child: Text('50')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildPageChip(),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPrevious,
                        style: _paginationButtonStyle(),
                        icon: const Icon(Icons.chevron_left, size: 18),
                        label: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onNext,
                        style: _paginationButtonStyle(),
                        icon: const Icon(Icons.chevron_right, size: 18),
                        label: const Text('Next'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildSummaryText(visibleStart, visibleEnd),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<int>(
                  initialValue: rowsPerPage,
                  onChanged: onRowsChanged,
                  isDense: true,
                  isExpanded: true,
                  decoration: _dropdownDecoration(),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: primaryColor,
                  ),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onPrevious,
                style: _paginationButtonStyle(),
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Previous'),
              ),
              const SizedBox(width: 10),
              _buildPageChip(),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onNext,
                style: _paginationButtonStyle(),
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Next'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryText(int visibleStart, int visibleEnd) {
    return Text(
      'Showing $visibleStart to $visibleEnd of $totalItems users',
      style: const TextStyle(
        color: mutedTextColor,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
    );
  }

  Widget _buildPageChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor),
      ),
      child: Text(
        'Page $currentPage of $totalPages',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: primaryColor,
          fontSize: 13,
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      labelText: 'Rows',
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cardBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cardBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentColor),
      ),
      floatingLabelStyle: const TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  ButtonStyle _paginationButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: const BorderSide(color: cardBorderColor),
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}