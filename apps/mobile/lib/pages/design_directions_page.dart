import 'package:flutter/material.dart';

import '../widgets/page_header.dart';

class DesignDirectionsPage extends StatefulWidget {
  const DesignDirectionsPage({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  State<DesignDirectionsPage> createState() => _DesignDirectionsPageState();
}

class _DesignDirectionsPageState extends State<DesignDirectionsPage> {
  int selectedIndex = 0;

  static const concepts = [
    _ConceptMeta(
      letter: 'A',
      name: '动态',
      subtitle: '朋友圈式信息流',
      background: Color(0xFFF6F8FB),
      foreground: Color(0xFF18202A),
      accent: Color(0xFF3A7BFF),
    ),
    _ConceptMeta(
      letter: 'B',
      name: '笔记',
      subtitle: '小红书式图墙',
      background: Color(0xFFFFF5F8),
      foreground: Color(0xFF231722),
      accent: Color(0xFFFF4F8B),
    ),
    _ConceptMeta(
      letter: 'C',
      name: '碎语',
      subtitle: '文字优先的轻动态',
      background: Color(0xFFFAFAF7),
      foreground: Color(0xFF1A1A1A),
      accent: Color(0xFF2F6F5E),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final concept = concepts[selectedIndex];

    return Scaffold(
      backgroundColor: concept.background,
      body: SafeArea(
        child: DefaultTextStyle(
          style: TextStyle(
            color: concept.foreground,
            fontFamily: 'GenkiNotoSansSC',
            height: 1.28,
            letterSpacing: 0,
          ),
          child: Column(
            children: [
              if (widget.showAppBar)
                PageHeader(
                  title: 'UI 实验室',
                  foregroundColor: concept.foreground,
                ),
              _DirectionPicker(
                concepts: concepts,
                selectedIndex: selectedIndex,
                onSelect: (index) => setState(() => selectedIndex = index),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(selectedIndex),
                    child: switch (selectedIndex) {
                      0 => const _MyMomentsDirection(),
                      1 => const _MyNotesDirection(),
                      _ => const _MyEchoDirection(),
                    },
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

class _DirectionPicker extends StatelessWidget {
  const _DirectionPicker({
    required this.concepts,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_ConceptMeta> concepts;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final current = concepts[selectedIndex];

    return Container(
      color: current.background,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: current.foreground,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: current.foreground.withValues(alpha: 0.58),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${selectedIndex + 1}/${concepts.length}',
                style: TextStyle(
                  color: current.foreground.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: concepts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = concepts[index];
                final selected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => onSelect(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? current.accent
                          : current.foreground.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? current.accent
                            : current.foreground.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.letter,
                          style: TextStyle(
                            color: selected
                                ? _onAccent(current.accent)
                                : current.foreground,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.name,
                          style: TextStyle(
                            color: selected
                                ? _onAccent(current.accent)
                                : current.foreground.withValues(alpha: 0.78),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MyMomentsDirection extends StatelessWidget {
  const _MyMomentsDirection();

  static const bg = Color(0xFFF6F8FB);
  static const ink = Color(0xFF18202A);
  static const blue = Color(0xFF3A7BFF);
  static const card = Color(0xFFFFFFFF);
  static const photo = Color(0xFF9BC5FF);

  @override
  Widget build(BuildContext context) {
    return _Shell(
      background: bg,
      foreground: ink,
      accent: blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [blue, Color(0xFF6FA8FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const Positioned(
                right: 28,
                bottom: -22,
                child: _Avatar(
                  label: 'R',
                  color: Colors.white,
                  textColor: blue,
                  size: 54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: const [
                Expanded(
                  child: Text(
                    'Ritsuka',
                    style: TextStyle(
                      color: ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _PostButton(accent: blue, label: '发布'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MomentPost(
            foreground: ink,
            accent: blue,
            card: card,
            photo: photo,
            text: '心心念念几个月的东西终于到手了。不想发到真社交，但还是想被看见一下。',
            likes: 'Mika、Qiao 等 18 人觉得很赞',
            comments: const [('Mika', '这个颜色太适合你了'), ('Sen', '第一张照片有种安静的光感')],
          ),
          _MomentPost(
            foreground: ink,
            accent: blue,
            card: card,
            photo: const Color(0xFFFFB6D1),
            text: '咖啡、干净的桌面、新袜子。小幸福存档。',
            likes: 'Aki 等 9 人觉得很赞',
            comments: const [('Aki', '稳稳的小幸福')],
          ),
        ],
      ),
    );
  }
}

class _MyNotesDirection extends StatelessWidget {
  const _MyNotesDirection();

  static const bg = Color(0xFFFFF5F8);
  static const ink = Color(0xFF231722);
  static const pink = Color(0xFFFF4F8B);
  static const cyan = Color(0xFF51D1F6);
  static const yellow = Color(0xFFFFD166);

  @override
  Widget build(BuildContext context) {
    return _Shell(
      background: bg,
      foreground: ink,
      accent: pink,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        children: [
          _PageHeader(
            title: '我的笔记',
            subtitle: '今天的小记',
            foreground: ink,
            accent: pink,
            icon: Icons.add_circle,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                child: _NoteTile(
                  foreground: ink,
                  accent: pink,
                  color: pink,
                  height: 178,
                  text: '那件外套终于到了',
                  likes: '42',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    _NoteTile(
                      foreground: ink,
                      accent: pink,
                      color: cyan,
                      height: 118,
                      text: '桌面小整理',
                      likes: '21',
                    ),
                    SizedBox(height: 10),
                    _NoteTile(
                      foreground: ink,
                      accent: pink,
                      color: yellow,
                      height: 132,
                      text: '今晚的餐拍出来挺贵气',
                      likes: '88',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyEchoDirection extends StatelessWidget {
  const _MyEchoDirection();

  static const bg = Color(0xFFFAFAF7);
  static const ink = Color(0xFF1A1A1A);
  static const accent = Color(0xFF2F6F5E);
  static const mediaA = Color(0xFFE8EEE9);
  static const mediaB = Color(0xFFF0E9DC);

  @override
  Widget build(BuildContext context) {
    return _Shell(
      background: bg,
      foreground: ink,
      accent: accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PageHeader(
              title: '碎语',
              subtitle: '记录此刻',
              foreground: ink,
              accent: accent,
              icon: Icons.edit,
            ),
          ),
          const SizedBox(height: 10),
          _ThreadPost(
            foreground: ink,
            accent: accent,
            text: '不需要所有人看到。只需要有人看到的感觉。',
            mediaColor: mediaA,
            replies: const [
              ('Aki', '这就是这个 app 存在的意义吧。'),
              ('Lan', '小小的听众，真实的舒服。'),
            ],
          ),
          _ThreadPost(
            foreground: ink,
            accent: accent,
            text: '买了那件外套。镜子说可以。',
            mediaColor: mediaB,
            replies: const [('Qiao', '镜子没错。'), ('Mika', '多发几张照片。')],
          ),
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.child,
  });

  final Color background;
  final Color foreground;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      child: Column(
        children: [
          Expanded(child: child),
          _BottomNav(foreground: foreground, accent: accent),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.foreground,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color foreground;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: foreground,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _onAccent(accent), size: 22),
        ),
      ],
    );
  }
}

class _MomentPost extends StatelessWidget {
  const _MomentPost({
    required this.foreground,
    required this.accent,
    required this.card,
    required this.photo,
    required this.text,
    required this.likes,
    required this.comments,
  });

  final Color foreground;
  final Color accent;
  final Color card;
  final Color photo;
  final String text;
  final String likes;
  final List<(String, String)> comments;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: foreground.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(label: 'R', color: accent, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ritsuka', style: _heavy(foreground, 15)),
                const SizedBox(height: 6),
                Text(text, style: _body(foreground, 15)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _PhotoBlock(color: photo, height: 112)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PhotoBlock(
                        color: photo.withValues(alpha: 0.72),
                        height: 112,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.favorite, color: accent, size: 16),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        likes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.58),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final comment in comments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${comment.$1}：${comment.$2}',
                            style: TextStyle(
                              color: foreground,
                              fontSize: 12,
                              height: 1.24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.foreground,
    required this.accent,
    required this.color,
    required this.height,
    required this.text,
    required this.likes,
  });

  final Color foreground;
  final Color accent;
  final Color color;
  final double height;
  final String text;
  final String likes;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhotoBlock(color: color, height: height, icon: Icons.image),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _heavy(foreground, 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Avatar(label: 'R', color: accent, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ritsuka',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.62),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.favorite_border,
                      color: foreground.withValues(alpha: 0.5),
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      likes,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.62),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionStrip extends StatelessWidget {
  const _ReactionStrip({required this.foreground, required this.accent});

  final Color foreground;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Reaction(
          icon: Icons.favorite,
          text: '36',
          color: accent,
          foreground: foreground,
        ),
        const SizedBox(width: 12),
        _Reaction(
          icon: Icons.chat_bubble,
          text: '12',
          color: foreground.withValues(alpha: 0.6),
          foreground: foreground,
        ),
        const SizedBox(width: 12),
        _Reaction(
          icon: Icons.repeat,
          text: '4',
          color: foreground.withValues(alpha: 0.6),
          foreground: foreground,
        ),
      ],
    );
  }
}

class _Reaction extends StatelessWidget {
  const _Reaction({
    required this.icon,
    required this.text,
    required this.color,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(text, style: _heavy(foreground, 12)),
      ],
    );
  }
}

class _ThreadPost extends StatelessWidget {
  const _ThreadPost({
    required this.foreground,
    required this.accent,
    required this.text,
    required this.mediaColor,
    required this.replies,
  });

  final Color foreground;
  final Color accent;
  final String text;
  final Color mediaColor;
  final List<(String, String)> replies;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: foreground.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _Avatar(label: 'R', color: accent, size: 42),
              Container(
                width: 2,
                height: 188,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: foreground.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Ritsuka', style: _heavy(foreground, 15)),
                    const SizedBox(width: 6),
                    Text(
                      '刚刚',
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(text, style: _body(foreground, 18)),
                const SizedBox(height: 10),
                _PhotoBlock(color: mediaColor, height: 112, icon: Icons.image),
                const SizedBox(height: 10),
                _ReactionStrip(foreground: foreground, accent: accent),
                const SizedBox(height: 10),
                for (final reply in replies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      '${reply.$1}：${reply.$2}',
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  const _PostButton({required this.accent, required this.label});

  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _onAccent(accent),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({
    required this.color,
    required this.height,
    this.icon = Icons.photo,
  });

  final Color color;
  final double height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.86), size: 30),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.label,
    required this.color,
    required this.size,
    this.textColor,
  });

  final String label;
  final Color color;
  final double size;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? _onAccent(color),
          fontSize: size * 0.36,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.foreground, required this.accent});

  final Color foreground;
  final Color accent;

  static const _labels = ['首页', '发布', '我的'];
  static const _icons = [
    Icons.home_rounded,
    Icons.add_box_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        border: Border(
          top: BorderSide(color: foreground.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < _labels.length; index++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _icons[index],
                    color: index == 0
                        ? accent
                        : foreground.withValues(alpha: 0.38),
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: index == 0
                          ? accent
                          : foreground.withValues(alpha: 0.42),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

@immutable
class _ConceptMeta {
  const _ConceptMeta({
    required this.letter,
    required this.name,
    required this.subtitle,
    required this.background,
    required this.foreground,
    required this.accent,
  });

  final String letter;
  final String name;
  final String subtitle;
  final Color background;
  final Color foreground;
  final Color accent;
}

TextStyle _heavy(Color color, double size) {
  return TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900);
}

TextStyle _body(Color color, double size) {
  return TextStyle(
    color: color,
    fontSize: size,
    height: 1.28,
    fontWeight: FontWeight.w700,
  );
}

Color _onAccent(Color accent) {
  return accent.computeLuminance() > 0.55 ? Colors.black : Colors.white;
}
