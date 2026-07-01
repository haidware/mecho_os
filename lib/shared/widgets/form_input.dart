import 'package:flutter/material.dart';

class FormInput extends StatelessWidget {
  final String label;
  const FormInput({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(decoration: InputDecoration(labelText: label));
  }
}
