import 'package:flutter/material.dart';

const String aiDisclosureTitle = 'Discover the story behind your photo';
const String aiDisclosureMessage =
    'Our AI creates cultural-heritage descriptions to make each discovery more '
    'informative and engaging. We work to provide valuable results, but AI can '
    'make mistakes—please verify important details.';

class AiDisclosureCard extends StatelessWidget {
  const AiDisclosureCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, color: colors.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aiDisclosureTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    aiDisclosureMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiGeneratedBadge extends StatelessWidget {
  const AiGeneratedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI-generated description',
      child: const Chip(
        avatar: Icon(Icons.auto_awesome, size: 16),
        label: Text('AI-generated'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
