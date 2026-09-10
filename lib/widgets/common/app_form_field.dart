import 'package:flutter/material.dart';

class AppFormField extends StatefulWidget {
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool isPassword;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final bool? enabled;
  final String? initialValue;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final void Function(String?)? onSaved;

  const AppFormField({
    super.key,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.maxLines = 1,
    this.enabled,
    this.initialValue,
    this.onChanged,
    this.onFieldSubmitted,
    this.onSaved,
  });

  @override
  State<AppFormField> createState() => _AppFormFieldState();
}

class _AppFormFieldState extends State<AppFormField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget? builtSuffix = widget.suffixIcon;
    if (widget.isPassword) {
      builtSuffix = IconButton(
        tooltip: _obscureText ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: colors.onSurfaceVariant,
        ),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      );
    }

    return TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      enabled: widget.enabled,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onSaved: widget.onSaved,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: colors.onSurfaceVariant)
            : null,
        suffixIcon: builtSuffix,
      ),
    );
  }
}
