import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';

class ProductionListScaffold<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Stream<List<T>> stream;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? headerAction;
  final Widget? intro;

  const ProductionListScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.stream,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptyMessage,
    this.headerAction,
    this.intro,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: zBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: zBlueSoft,
                child: Icon(icon, color: zBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: zText,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: zMuted,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (headerAction != null) ...[
                const SizedBox(width: 12),
                headerAction!,
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (intro != null) ...[intro!, const SizedBox(height: 12)],
        Expanded(
          child: StreamBuilder<List<T>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: zBlue),
                );
              }

              if (snapshot.hasError) {
                return _ProductionEmptyState(
                  icon: Icons.error_outline,
                  title: 'Unable to load records',
                  message: snapshot.error.toString(),
                );
              }

              final items = snapshot.data ?? <T>[];
              if (items.isEmpty) {
                return _ProductionEmptyState(
                  icon: icon,
                  title: emptyTitle,
                  message: emptyMessage,
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return itemBuilder(context, items[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductionEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ProductionEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: zBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: zMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: zText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: zMuted,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductionListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  const ProductionListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: zBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: zBlueSoft,
              child: Icon(icon, color: zBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Untitled' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: zText,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: zMuted,
                      fontSize: 12.6,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: const TextStyle(
                color: zMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: zMuted),
            ],
          ],
        ),
      ),
    );
  }
}
