import 'package:flutter/material.dart';
import '../app_theme.dart';

/// A text field for the phone's own keyboard, so autocorrect, suggestions and
/// voice typing work. Nothing reaches the host until [onSend].
class TypingBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const TypingBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: context.palette.ink.withValues(alpha: 0.08),
      ),
    );
    return Container(
      color: context.palette.paper,
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(fontSize: 15, color: context.palette.ink),
              decoration: InputDecoration(
                hintText: "Type a message for the host",
                hintStyle: TextStyle(
                  color: context.palette.ink.withValues(alpha: 0.4),
                ),
                isDense: true,
                filled: true,
                fillColor: context.palette.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: BorderSide(color: context.palette.ink),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => IconButton.filled(
              onPressed: value.text.isEmpty ? null : onSend,
              tooltip: "Send to host",
              style: IconButton.styleFrom(
                backgroundColor: context.palette.ink,
                foregroundColor: context.palette.paper,
                disabledBackgroundColor: context.palette.surface,
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
