import 'package:flutter/material.dart';

import '../../backend/controllers/playback_controller.dart';
import 'application_binding.dart';
import 'design_widgets.dart';

class LiveQueueSheet extends StatelessWidget {
  const LiveQueueSheet({super.key, required this.actions});
  final FrontendActions actions;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      actions.dependencies.playback,
      actions.dependencies.library,
    ]),
    builder: (context, _) {
      final controller = actions.dependencies.playback;
      final state = controller.state;
      final data = state.data;
      final latest = {
        for (final song in actions.dependencies.library.state.data.songs)
          song.songId: song,
      };
      Future<void> act(Future<void> Function() operation) async {
        try {
          await operation();
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(actionError(error))));
          }
        }
      }

      void move(QueueOccurrence occurrence, int index) => act(
        () => controller.reorderUpcoming(
          occurrence.id,
          index,
          revision: data.revision,
        ),
      );
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Queue', style: headingStyle),
                const Text(
                  'Select an occurrence. Existing play intent is preserved. Edit upcoming occurrences using drag or move buttons.',
                  style: mutedStyle,
                ),
                if (data.queue.isEmpty) const Text('No queued songs'),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: data.queue.length,
                  onReorderItem: (oldIndex, newIndex) {
                    if (oldIndex > (data.queueIndex ?? -1)) {
                      move(data.occurrences[oldIndex], newIndex);
                    }
                  },
                  itemBuilder: (_, index) {
                    final occurrence = data.occurrences[index];
                    final song =
                        latest[data.queue[index].songId] ?? data.queue[index];
                    final upcoming = index > (data.queueIndex ?? -1);
                    return Column(
                      key: ValueKey(occurrence.id),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${index + 1} · ${index == data.queueIndex
                              ? 'Now playing / selected'
                              : upcoming
                              ? 'Upcoming'
                              : 'Previous'}',
                          style: mutedStyle,
                        ),
                        SongRow(
                          key: ValueKey('queue-occurrence-$index'),
                          song: song,
                          onTap: () => act(() => controller.selectAt(index)),
                          trailing: IconButton(
                            tooltip: 'Select queue occurrence ${index + 1}',
                            icon: Icon(
                              index == data.queueIndex
                                  ? Icons.radio_button_checked
                                  : Icons.play_arrow,
                            ),
                            onPressed: () =>
                                act(() => controller.selectAt(index)),
                          ),
                        ),
                        if (upcoming)
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.drag_handle,
                                    semanticLabel: 'Drag upcoming occurrence',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    'Move queue occurrence ${index + 1} up',
                                onPressed: index <= data.queueIndex! + 1
                                    ? null
                                    : () => move(occurrence, index - 1),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                tooltip:
                                    'Move queue occurrence ${index + 1} down',
                                onPressed: index == data.queue.length - 1
                                    ? null
                                    : () => move(occurrence, index + 1),
                                icon: const Icon(Icons.arrow_downward),
                              ),
                              IconButton(
                                tooltip: 'Remove queue occurrence ${index + 1}',
                                onPressed: () => act(
                                  () =>
                                      controller.removeUpcoming(occurrence.id),
                                ),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
                if (state.error != null) Text(actionError(state.error!)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
