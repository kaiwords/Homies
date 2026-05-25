import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme.dart';

class Avatar extends StatelessWidget {
  final User? user;
  final double size;
  const Avatar({super.key, required this.user, this.size = 32});

  factory Avatar.sm(User? u) => Avatar(user: u, size: 26);
  factory Avatar.lg(User? u) => Avatar(user: u, size: 44);

  @override
  Widget build(BuildContext context) {
    if (user == null) return SizedBox(width: size, height: size);
    final hue = user!.id.codeUnits.fold<int>(0, (a, b) => a + b) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.4, 0.6).toColor();
    return Tooltip(
      message: user!.name,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: HomiesColors.surface, width: 1.5),
        ),
        child: Text(
          user!.initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * 0.36),
        ),
      ),
    );
  }
}

class AvatarStack extends StatelessWidget {
  final List<User?> users;
  const AvatarStack({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    final list = users.where((u) => u != null).toList();
    return SizedBox(
      width: 26.0 + (list.length - 1) * 18.0,
      height: 26,
      child: Stack(
        children: [
          for (var i = 0; i < list.length; i++)
            Positioned(left: i * 18.0, child: Avatar(user: list[i], size: 26)),
        ],
      ),
    );
  }
}
