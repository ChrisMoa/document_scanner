import 'package:flutter/material.dart';

class SearchBarWidget extends StatefulWidget {
  final Function(String) onChanged;
  final VoidCallback onClear;

  const SearchBarWidget({
    super.key,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      style: TextStyle(
        color: theme.appBarTheme.foregroundColor,
      ),
      decoration: InputDecoration(
        hintText: 'Search documents...',
        hintStyle: TextStyle(
          color: theme.appBarTheme.foregroundColor?.withOpacity(0.7),
        ),
        border: InputBorder.none,
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: theme.appBarTheme.foregroundColor,
                ),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  widget.onClear();
                },
              )
            : IconButton(
                icon: Icon(
                  Icons.close,
                  color: theme.appBarTheme.foregroundColor,
                ),
                onPressed: widget.onClear,
              ),
      ),
    );
  }
}

