import 'dart:math';

import 'package:fleather/fleather.dart';
import 'package:fleather/l10n/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parchment/parchment.dart';

class LinkActionOverlay extends StatefulWidget {
  const LinkActionOverlay({
    super.key,
    required this.editor,
    required this.readOnly,
    required this.onClosed,
    required this.segment,
    required this.onLinkChanged,
    required this.onLinkRemoved,
    required this.onLaunchUrl,
    required this.theme,
  });

  final bool readOnly;
  final Node segment;
  final FleatherThemeData theme;
  final RenderEditor editor;
  final VoidCallback onClosed;
  final VoidCallback onLinkRemoved;
  final OnLinkChanged onLinkChanged;
  final ValueChanged<String?>? onLaunchUrl;

  @override
  State<LinkActionOverlay> createState() => _LinkActionOverlayState();
}

class _LinkActionOverlayState extends State<LinkActionOverlay> {
  final actionKey = GlobalKey();
  late final editorPosition = getEditorPosition();
  late final startPosition = positionOfDocument(widget.segment.documentOffset);
  late final endPosition = positionOfDocument(
    widget.segment.documentOffset + widget.segment.length,
  );
  double? actionWidth;

  /// Convert document offset to position
  Offset positionOfDocument(int documentOffset) {
    final globalTextPosition = TextPosition(offset: documentOffset);
    final childAtPosition = widget.editor.childAtPosition(globalTextPosition);
    final localTextPosition =
        childAtPosition.globalToLocalPosition(globalTextPosition);
    final localOffsetForCaret =
        childAtPosition.getOffsetForCaret(localTextPosition);
    return childAtPosition.localToGlobal(localOffsetForCaret);
  }

  /// Return editor global position
  Offset getEditorPosition() {
    final globalTextPosition =
        TextPosition(offset: widget.segment.documentOffset);
    return widget.editor
        .childAtPosition(globalTextPosition)
        .localToGlobal(Offset.zero);
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox =
          actionKey.currentContext?.findRenderObject() as RenderBox?;
      setState(() {
        actionWidth = renderBox?.size.width;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final text = (widget.segment as TextNode).value;
    final link = (widget.segment as StyledNode)
        .style
        .get(ParchmentAttribute.link)!
        .value!;
    final iconButtonStyle = IconButton.styleFrom(
      fixedSize: const Size.square(32),
      minimumSize: const Size.square(32),
      iconSize: 18,
      padding: const EdgeInsets.all(0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final left = startPosition.dy != endPosition.dy
        ? editorPosition.dx
        : startPosition.dx;
    final top = endPosition.dy;
    return Stack(
      children: [
        Positioned(
          left: actionWidth == null
              ? left
              : min(left, screenWidth - actionWidth! - 8),
          top: top + 20,
          child: TapRegion(
            onTapOutside: (_) {
              widget.onClosed();
            },
            child: Card(
              key: actionKey,
              elevation: 6,
              shadowColor: Colors.black26,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 14),
                    Flexible(
                      child: InkWell(
                        hoverColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () {
                          widget.onLaunchUrl?.call(link);
                        },
                        child: Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.theme.link.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: context.l.linkDialogCopy,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: link));
                        widget.onClosed();
                      },
                      style: iconButtonStyle,
                    ),
                    if (!widget.readOnly) ...[
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: context.l.edit,
                        onPressed: () {
                          // onEdited
                          widget.onClosed();
                          showDialog(
                            context: context,
                            builder: (context) => EditLinkDialog(
                              text: text,
                              link: link,
                              onLinkChanged: widget.onLinkChanged,
                            ),
                          );
                        },
                        style: iconButtonStyle,
                      ),
                      IconButton(
                        icon: const Icon(Icons.link_off),
                        tooltip: context.l.linkDialogRemove,
                        onPressed: () {
                          widget.onClosed();
                          widget.onLinkRemoved();
                        },
                        style: iconButtonStyle,
                      ),
                    ],
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

typedef OnLinkChanged = Function(String text, String link);

class EditLinkDialog extends StatefulWidget {
  const EditLinkDialog({
    super.key,
    required this.text,
    required this.link,
    required this.onLinkChanged,
  });

  final String text;
  final String link;
  final OnLinkChanged onLinkChanged;

  @override
  State<EditLinkDialog> createState() => _EditLinkDialogState();
}

class _EditLinkDialogState extends State<EditLinkDialog> {
  late final urlController = TextEditingController(
    text: widget.link,
  );
  late final textController = TextEditingController(
    text: widget.text,
  );

  void onSubmitChanged() {
    widget.onLinkChanged(
      textController.text,
      urlController.text,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l.editLink),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: textController,
              decoration: InputDecoration(
                label: Text(context.l.text),
              ),
              autofocus: true,
              onFieldSubmitted: (value) {
                onSubmitChanged();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: urlController,
              decoration: const InputDecoration(
                label: Text('URL'),
              ),
              onFieldSubmitted: (value) {
                onSubmitChanged();
              },
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(context.l.cancel),
        ),
        FilledButton(
          onPressed: onSubmitChanged,
          child: Text(context.l.confirm),
        ),
      ],
    );
  }
}
