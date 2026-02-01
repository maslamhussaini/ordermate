import 'package:flutter/material.dart';
import 'package:ordermate/core/widgets/generic_selection_screen.dart';

class LookupField<TItem, TValue> extends StatelessWidget {
  const LookupField({
    required this.label,
    required this.items,
    required this.labelBuilder,
    required this.valueBuilder,
    required this.onChanged,
    super.key,
    this.value,
    this.onAdd,
    this.validationError,
    this.enabled = true,
    this.hint,
  });

  final String label;
  final TValue? value;
  final List<TItem> items;
  final String Function(TItem) labelBuilder;
  final TValue Function(TItem) valueBuilder;
  final ValueChanged<TValue?> onChanged;
  final Future<void> Function(String)? onAdd;
  final String? validationError;
  final bool enabled;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    // Find the current selected item object to display its label
    TItem? selectedItem;
    try {
      if (value != null) {
        selectedItem = items.firstWhere((item) => valueBuilder(item) == value);
      }
    } catch (_) {
      // If value not found in items (e.g. inactive), selectedItem stays null
    }

    final displayLabel =
        selectedItem != null ? labelBuilder(selectedItem) : (hint ?? 'Select $label');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: enabled ? () async {
                  final result = await Navigator.push<TItem>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GenericSelectionScreen<TItem>(
                        title: 'Select $label',
                        items: items,
                        labelBuilder: labelBuilder,
                      ),
                    ),
                  );

                  if (result != null) {
                    onChanged(valueBuilder(result));
                  }
                } : null,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16,),
                    errorText: validationError,
                    suffixIcon: enabled ? const Icon(Icons.arrow_drop_down) : null,
                    fillColor: enabled ? null : Colors.grey.shade200,
                    filled: !enabled,
                  ),
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      color: selectedItem != null
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Theme.of(context).hintColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            if (onAdd != null && enabled) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add),
                tooltip: 'Add new $label',
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add New $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label name',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await onAdd!(controller.text.trim());
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('$label Added Successfully!')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
