class TransferSelectionService {
  /// Returns indexes of selected items (where value = true)
  static List<int> getSelectedIndexes(Map<int, bool> selectedItems) {
    return selectedItems.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList()
      ..sort(); // ensures consistent order
  }

  /// Validates that at least one item is selected
  static bool isValidSelection(List<int> indexes) {
    return indexes.isNotEmpty;
  }
}