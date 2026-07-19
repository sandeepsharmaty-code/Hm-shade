/// Purpose      : Reusable search input widget.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart
/// Description  : Standard search bar used by the Search tab and the
///                Knowledge Base tab's filter row, so both share one
///                search presentation and behaviour (debounced-ready
///                onChanged hook, clear button) rather than each
///                screen implementing its own.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/material.dart';

/// Standard application search field with a built-in clear button.
class SearchBox extends StatefulWidget {
  const SearchBox({
    super.key,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
  });

  /// Placeholder text shown when empty.
  final String hint;

  /// Called on every keystroke with the current query text.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the query (e.g. presses enter).
  final ValueChanged<String>? onSubmitted;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (BuildContext context, TextEditingValue value, _) {
            if (value.text.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _handleClear,
            );
          },
        ),
      ),
    );
  }
}
