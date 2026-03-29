import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/widget/note_item.dart';
import 'package:pocketmind/providers/nav_providers.dart';
import 'package:pocketmind/service/note_service.dart';

class NoteFeedPagedView extends StatefulWidget {
  const NoteFeedPagedView({
    super.key,
    required this.notes,
    required this.currentLayout,
    required this.noteService,
    required this.itemKeyPrefix,
    this.scrollController,
    this.pageSize = 20,
    this.prefetchScreenRatio = 1.5,
    this.gridPadding = const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    this.listPadding = const EdgeInsets.symmetric(horizontal: 4),
  });

  final List<Note> notes;
  final NoteLayout currentLayout;
  final NoteService noteService;
  final String itemKeyPrefix;
  final ScrollController? scrollController;
  final int pageSize;
  final double prefetchScreenRatio;
  final EdgeInsetsGeometry gridPadding;
  final EdgeInsetsGeometry listPadding;

  @override
  State<NoteFeedPagedView> createState() => _NoteFeedPagedViewState();
}

class _NoteFeedPagedViewState extends State<NoteFeedPagedView> {
  late final bool _isExternalController;
  late final ScrollController _controller;
  late int _visibleCount;

  @override
  void initState() {
    super.initState();
    _isExternalController = widget.scrollController != null;
    _controller = widget.scrollController ?? ScrollController();
    _visibleCount = math.min(widget.pageSize, widget.notes.length);
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant NoteFeedPagedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetVisible = math.min(widget.notes.length, _visibleCount);
    if (targetVisible != _visibleCount) {
      _visibleCount = targetVisible;
    }
    if (_visibleCount == 0 && widget.notes.isNotEmpty) {
      _visibleCount = math.min(widget.pageSize, widget.notes.length);
    }
    if (widget.notes.length > _visibleCount && _controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeLoadMore();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    if (!_isExternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotes = widget.notes.take(_visibleCount).toList(growable: false);

    if (widget.currentLayout == NoteLayout.grid) {
      return MasonryGridView.count(
        controller: _controller,
        key: PageStorageKey('${widget.itemKeyPrefix}_grid_view'),
        crossAxisCount: 2,
        cacheExtent: 500,
        padding: widget.gridPadding,
        itemCount: visibleNotes.length,
        itemBuilder: (context, index) {
          final note = visibleNotes[index];
          return RepaintBoundary(
            child: NoteItem(
              note: note,
              noteService: widget.noteService,
              isWaterfall: true,
              key: ValueKey('${widget.itemKeyPrefix}_${note.id}'),
            ),
          );
        },
      );
    }

    return ListView.builder(
      controller: _controller,
      key: PageStorageKey('${widget.itemKeyPrefix}_list_view'),
      cacheExtent: 500,
      padding: widget.listPadding,
      itemCount: visibleNotes.length,
      itemBuilder: (context, index) {
        final note = visibleNotes[index];
        return RepaintBoundary(
          child: NoteItem(
            note: note,
            noteService: widget.noteService,
            isWaterfall: false,
            key: ValueKey('${widget.itemKeyPrefix}_${note.id}'),
          ),
        );
      },
    );
  }

  void _onScroll() {
    _maybeLoadMore();
  }

  void _maybeLoadMore() {
    if (!_controller.hasClients) return;
    if (_visibleCount >= widget.notes.length) return;

    final prefetchExtent = MediaQuery.of(context).size.height * widget.prefetchScreenRatio;
    final extentAfter = _controller.position.extentAfter;
    if (extentAfter <= prefetchExtent) {
      setState(() {
        _visibleCount = math.min(widget.notes.length, _visibleCount + widget.pageSize);
      });
    }
  }
}
