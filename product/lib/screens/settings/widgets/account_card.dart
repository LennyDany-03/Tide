import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/account_avatar.dart';
import '../../../widgets/tide_surface.dart';

/// Who is signed in.
///
/// It used to carry a plan badge, a meter counting habits toward the free
/// ceiling, and the way through to the paywall. Tide is free, so there is no
/// ceiling to draw and nothing to sell — what is left is the account itself,
/// which is what somebody opening Settings came to check.
///
/// The disc is the account's own: a Google photo when a Google identity is
/// linked — including on an email account that later added Google — and
/// initials otherwise.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.name,
    required this.email,
    required this.habitCount,
    this.avatarUrl,
  });

  final String name;
  final String email;
  final String? avatarUrl;

  /// Active habits, said plainly. Nothing counts toward anything now.
  final int habitCount;

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      color: TideColors.shelf,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          AccountAvatar(name: name, avatarUrl: avatarUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TideType.hero.copyWith(fontSize: 19),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TideType.labelMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  habitCount == 1 ? '1 habit' : '$habitCount habits',
                  style: TideType.labelMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
