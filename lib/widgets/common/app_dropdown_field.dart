import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

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
    Key? key,
    this.labelText,
    this.hintText,
    required this.items,
    this.value,
    this.onChanged,
    this.onSaved,
    this.validator,
    this.prefixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      onSaved: onSaved,
      validator: validator,
      icon: const Icon(Icons.expand_more, color: AppColors.secondary),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.secondary)
            : null,
      ),
    );
  }
}
