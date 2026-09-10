import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AppFormField extends StatefulWidget {
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool isPassword;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLines;
  final bool? enabled;
  final String? initialValue;
  final void Function(String)? onChanged;
  final void Function(String?)? onSaved;

  const AppFormField({
    Key? key,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.enabled,
    this.initialValue,
    this.onChanged,
    this.onSaved,
  }) : super(key: key);

  @override
  State<AppFormField> createState() => _AppFormFieldState();
}

class _AppFormFieldState extends State<AppFormField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    Widget? builtSuffix = widget.suffixIcon;
    if (widget.isPassword) {
      builtSuffix = IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: AppColors.secondary,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    return TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      enabled: widget.enabled,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      onChanged: widget.onChanged,
      onSaved: widget.onSaved,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: AppColors.secondary)
            : null,
        suffixIcon: builtSuffix,
      ),
    );
  }
}
