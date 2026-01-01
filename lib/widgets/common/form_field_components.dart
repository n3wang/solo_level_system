// lib/widgets/common/form_field_components.dart
import 'package:flutter/material.dart';

/// A reusable text field component with consistent styling
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool required;
  final int maxLines;
  final TextInputType keyboardType;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$labelText *' : labelText,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator:
          validator ??
          (required
              ? (value) {
                  if (value?.isEmpty ?? true) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null),
    );
  }
}

/// A reusable dropdown component with consistent styling
class CustomDropdownField<T> extends StatelessWidget {
  final T value;
  final String labelText;
  final List<DropdownMenuItem<T>> items;
  final Function(T?) onChanged;
  final bool required;

  const CustomDropdownField({
    super.key,
    required this.value,
    required this.labelText,
    required this.items,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: required ? '$labelText *' : labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      items: items,
      onChanged: onChanged,
      validator: required
          ? (value) {
              if (value == null) {
                return 'Please select an option';
              }
              return null;
            }
          : null,
    );
  }
}

/// A reusable number input field
class NumberInputField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final int? min;
  final int? max;
  final bool required;
  final Function(int?)? onChanged;

  const NumberInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.min,
    this.max,
    this.required = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      required: required,
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final number = int.tryParse(value);
        onChanged?.call(number);
      },
      validator: (value) {
        if (required && (value?.isEmpty ?? true)) {
          return 'This field is required';
        }
        if (value?.isNotEmpty == true) {
          final number = int.tryParse(value!);
          if (number == null) {
            return 'Please enter a valid number';
          }
          if (min != null && number < min!) {
            return 'Minimum value is $min';
          }
          if (max != null && number > max!) {
            return 'Maximum value is $max';
          }
        }
        return null;
      },
    );
  }
}

/// A reusable multi-select chip component
class MultiSelectChips extends StatelessWidget {
  final String title;
  final List<ChipOption> options;
  final List<dynamic> selectedValues;
  final Function(List<dynamic>) onSelectionChanged;

  const MultiSelectChips({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.map((option) {
            final isSelected = selectedValues.contains(option.value);
            return FilterChip(
              label: Text(option.label),
              selected: isSelected,
              onSelected: (selected) {
                final newSelection = List.from(selectedValues);
                if (selected) {
                  newSelection.add(option.value);
                } else {
                  newSelection.remove(option.value);
                }
                onSelectionChanged(newSelection);
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
              checkmarkColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Data class for chip options
class ChipOption {
  final dynamic value;
  final String label;

  const ChipOption({required this.value, required this.label});
}
