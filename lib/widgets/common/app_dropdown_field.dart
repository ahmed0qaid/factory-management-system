import 'package:flutter/material.dart';

class AppDropdownField<T> extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final void Function(T?)? onSaved;
  final String? Function(T?)? validator;
  final IconData? prefixIcon;

  const AppDropdownField({
    super.key,
    this.labelText,
    this.hintText,
    required this.items,
    this.value,
    this.onChanged,
    this.onSaved,
    this.validator,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      onSaved: onSaved,
      validator: validator,
      isExpanded: true,
      icon: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
      dropdownColor: scheme.surfaceContainer,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: scheme.onSurfaceVariant)
            : null,
      ),
    );
  }
}
