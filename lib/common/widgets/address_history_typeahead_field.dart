import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:pickles_and_pies/helper/address_fields_history_helper.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/styles.dart';

/// Text field that suggests previously-entered values for address
/// sub-fields (house, street/road, floor/ZIP) using [flutter_typeahead].
///
/// Drop-in replacement for [CustomTextField] when the form input
/// should auto-complete from locally saved history.
///
/// History is read from [AddressFieldsHistoryHelper] which keeps a
/// per-field list in `SharedPreferences`. Tapping a suggestion fills
/// the controller; typing a new value and committing saves it for
/// the next time the field is rendered.
class AddressHistoryTypeAheadField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final TextInputAction inputAction;
  final TextInputType inputType;
  final String labelText;
  final String hintText;
  final String? titleText;
  final bool required;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final HistoryFieldType fieldType;
  final Function(String value)? onSaveHistory;

  const AddressHistoryTypeAheadField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.fieldType,
    this.focusNode,
    this.nextFocus,
    this.inputAction = TextInputAction.next,
    this.inputType = TextInputType.text,
    this.hintText = '',
    this.titleText,
    this.required = false,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.onSaveHistory,
  });

  @override
  State<AddressHistoryTypeAheadField> createState() =>
      _AddressHistoryTypeAheadFieldState();
}

enum HistoryFieldType { house, street, floor }

class _AddressHistoryTypeAheadFieldState
    extends State<AddressHistoryTypeAheadField> {
  FocusNode? _internalFocus;

  FocusNode get _focusNode {
    if (widget.focusNode != null) return widget.focusNode!;
    _internalFocus ??= FocusNode();
    return _internalFocus!;
  }

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocus = FocusNode();
    }
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _internalFocus?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitHistory(widget.controller.text);
    }
  }

  List<String> _suggestionsFor(String pattern) {
    final List<String> history = _readHistory();
    if (pattern.trim().isEmpty) return history;
    final String lower = pattern.toLowerCase();
    return history
        .where((String e) => e.toLowerCase().contains(lower))
        .toList();
  }

  List<String> _readHistory() {
    switch (widget.fieldType) {
      case HistoryFieldType.house:
        return AddressFieldsHistoryHelper.getHouseHistory();
      case HistoryFieldType.street:
        return AddressFieldsHistoryHelper.getStreetHistory();
      case HistoryFieldType.floor:
        return AddressFieldsHistoryHelper.getFloorHistory();
    }
  }

  void _commitHistory(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return;
    switch (widget.fieldType) {
      case HistoryFieldType.house:
        AddressFieldsHistoryHelper.saveHouseToHistory(trimmed);
        break;
      case HistoryFieldType.street:
        AddressFieldsHistoryHelper.saveStreetToHistory(trimmed);
        break;
      case HistoryFieldType.floor:
        AddressFieldsHistoryHelper.saveFloorToHistory(trimmed);
        break;
    }
    widget.onSaveHistory?.call(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(context),
        TypeAheadField<String>(
          hideOnEmpty: true,
          controller: widget.controller,
          focusNode: _focusNode,
          debounceDuration: const Duration(milliseconds: 120),
          suggestionsCallback: (pattern) async {
            return _suggestionsFor(pattern);
          },
          builder: (context, controller, focusNode) => _buildTextField(
            context,
            controller,
            focusNode,
          ),
          itemBuilder: (context, String suggestion) =>
              _buildSuggestion(context, suggestion),
          onSelected: (String suggestion) => _handleSelected(
              context, suggestion),
          decorationBuilder: (context, child) => Material(
            type: MaterialType.card,
            elevation: 4,
            color: Theme.of(context).cardColor,
            child: child,
          ),
          errorBuilder: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    final String text = widget.titleText ?? widget.labelText;
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      child: RichText(
        text: TextSpan(
          text: text,
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          children: widget.required
              ? const <InlineSpan>[
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
                ]
              : const <InlineSpan>[],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
    FocusNode focusNode,
  ) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: widget.inputAction,
      keyboardType: widget.inputType,
      textCapitalization: widget.capitalization,
      inputFormatters: _inputFormatters(),
      onChanged: (String text) {
        widget.onChanged?.call(text);
      },
      onSubmitted: (String text) {
        _commitHistory(text);
        _moveFocus(context);
        widget.onSubmitted?.call(text);
      },
      onEditingComplete: () {
        _commitHistory(widget.controller.text);
      },
      decoration: _inputDecoration(context),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: Dimensions.fontSizeDefault,
          ),
    );
  }

  void _moveFocus(BuildContext context) {
    if (widget.nextFocus != null) {
      FocusScope.of(context).requestFocus(widget.nextFocus);
    }
  }

  List<TextInputFormatter>? _inputFormatters() {
    if (widget.fieldType == HistoryFieldType.floor) {
      return <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z\- ]')),
      ];
    }
    return null;
  }

  void _handleSelected(BuildContext context, String suggestion) {
    widget.controller.text = suggestion;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _commitHistory(suggestion);
    _moveFocus(context);
    widget.onSubmitted?.call(suggestion);
  }

  Widget _buildSuggestion(BuildContext context, String suggestion) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeSmall,
      ),
      child: Row(
        children: [
          Icon(
            _iconForType(),
            size: 18,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Text(
              suggestion,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType() {
    switch (widget.fieldType) {
      case HistoryFieldType.house:
        return Icons.home_work_outlined;
      case HistoryFieldType.street:
        return Icons.signpost_outlined;
      case HistoryFieldType.floor:
        return Icons.local_post_office;
    }
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double borderWidth = width > 800 ? 0.7 : 0.3;
    return InputDecoration(
      hintText:
          widget.hintText.isEmpty ? widget.labelText : widget.hintText,
      contentPadding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeDefault,
        horizontal: Dimensions.paddingSizeDefault,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        borderSide: BorderSide(
          style: BorderStyle.solid,
          width: borderWidth,
          color: Theme.of(context).disabledColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        borderSide:
            BorderSide(color: Theme.of(context).primaryColor, width: 1),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        borderSide: BorderSide(
          style: BorderStyle.solid,
          width: 0.3,
          color: Theme.of(context).primaryColor,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        borderSide: BorderSide(
          style: BorderStyle.solid,
          color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
        ),
      ),
      hintStyle: Theme.of(context).textTheme.displayMedium!.copyWith(
            fontSize: Dimensions.fontSizeDefault,
            color: Theme.of(context).disabledColor,
          ),
      filled: true,
      fillColor: Theme.of(context).cardColor,
    );
  }
}



