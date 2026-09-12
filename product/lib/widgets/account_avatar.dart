import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';

/// Who is signed in, as a disc.
///
/// A Google account brings its own picture and gets it. An email account has
/// none and gets its initials in the lantern ring the account card has always
/// drawn — letters rather than a grey silhouette, because a placeholder
/// person reads as "the picture failed", and initials read as a choice.
///
/// The initials are also what sits under the picture while it loads, and
/// what stays if it never does, so a slow or offline network degrades to the
/// email look rather than to an empty circle.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 50,
  });

  final String name;
  final String? avatarUrl;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  /// Google serves profile photos at 96px unless asked for another size,
  /// which is soft on a dense screen. The size is part of the URL.
  static String _sized(String url, int pixels) => url.replaceFirstMapped(
    RegExp(r'=s\d+(-c)?$'),
    (match) => '=s$pixels${match[1] ?? ''}',
  );

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();

    final initials = Center(
      child: Text(
        _initials,
        style: TideType.gauge(size * 0.32, color: TideColors.lantern),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TideColors.lantern.withValues(alpha: 0.14),
      ),
      // In front, so a photo cannot paint over the ring.
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: TideColors.lantern.withValues(alpha: 0.35)),
      ),
      child: ClipOval(
        child: url == null
            ? initials
            : Stack(
                fit: StackFit.expand,
                children: [
                  initials,
                  Image.network(
                    _sized(url, pixels),
                    fit: BoxFit.cover,
                    cacheWidth: pixels,
                    frameBuilder: (context, child, frame, synchronous) =>
                        AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: TideMotion.tabSwitch,
                          child: child,
                        ),
                    errorBuilder: (context, error, stack) =>
                        const SizedBox.shrink(),
                  ),
                ],
              ),
      ),
    );
  }
}
