import 'package:flutter/material.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

class HomeHistoryCard extends StatelessWidget {
  final dynamic history;
  final VoidCallback onTap;

  const HomeHistoryCard({
    super.key,
    required this.history,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF85A2).withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: -10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: history.thumbnail == null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFFD1DC).withOpacity(0.3),
                            const Color(0xFFFF85A2).withOpacity(0.2),
                          ],
                        )
                      : null,
                  image: history.thumbnail != null
                      ? DecorationImage(
                          image: MemoryImage(history.thumbnail!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: history.thumbnail == null
                    ? const Center(
                        child: Icon(
                          Icons.image,
                          size: 48,
                          color: Color(0xFFFF85A2),
                        ),
                      )
                    : null,
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Text(
                  history.getTimeAgo(context),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeHistoryEmptyPlaceholder extends StatelessWidget {
  const HomeHistoryEmptyPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 56,
              color: const Color(0xFFFF85A2).withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noHistoryTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noHistorySubtitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
