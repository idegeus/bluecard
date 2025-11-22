import 'package:flutter/material.dart';
import 'host_screen.dart';
import 'client_screen.dart';
import '../widgets/suit_card.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        height: screenHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2E15), Color(0xFF06210F), Color(0xFF04170B)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 28),
                // Dynamische schaal afhankelijk van schermhoogte
                Builder(
                  builder: (context) {
                    final h = MediaQuery.of(context).size.height;
                    final double titleSize = h < 600 ? 42.0 : 52.0;
                    final double gapAfterTitle = h < 600 ? 6.0 : 10.0;
                    return Column(
                      children: [
                        Text(
                          'BlueCard',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 8,
                                color: Colors.black.withValues(alpha: 0.55),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: gapAfterTitle),
                        Text(
                          'Speel offline kaartspellen met je vrienden',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: h < 600 ? 14 : 16,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: 20),
                // Kaarten fan (wrap voor kleine schermen minder ruimte)
                LayoutBuilder(
                  builder: (context, box) {
                    final h = MediaQuery.of(context).size.height;
                    final double fanHeight = h < 600 ? 110.0 : 140.0;
                    // Laat _CardFan zelf zijn benodigde hoogte bepalen om overflow te voorkomen.
                    return _CardFan(fanHeight: fanHeight);
                  },
                ),
                SizedBox(height: 24),
                Text(
                  'Kies je rol',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                _RoleButton(
                  icon: Icons.router,
                  title: 'Host',
                  subtitle: 'Start een nieuw spel',
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => HostScreen()),
                    );
                  },
                ),
                SizedBox(height: 18),
                _RoleButton(
                  icon: Icons.smartphone,
                  title: 'Speler',
                  subtitle: 'Verbind met een spel',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ClientScreen()),
                    );
                  },
                ),
                SizedBox(height: 28),
                Opacity(
                  opacity: 0.6,
                  child: Text(
                    '© 2025 BlueCard',
                    style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                  ),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 350),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.9),
                        color.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: Colors.white),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[500],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFan extends StatelessWidget {
  final double fanHeight;
  final List<SuitCardData> cards = const [
    SuitCardData('A', '♠', Colors.white),
    SuitCardData('K', '♥', Colors.red),
    SuitCardData('Q', '♣', Colors.white),
    SuitCardData('J', '♦', Colors.red),
    SuitCardData('10', '♠', Colors.white),
  ];

  const _CardFan({required this.fanHeight});

  @override
  Widget build(BuildContext context) {
    final scaleFactor = fanHeight / 140.0;
    final effectiveScale = scaleFactor.clamp(0.6, 1.0);
    final extraVerticalSpace = 40.0 * effectiveScale;
    final totalHeight = fanHeight + extraVerticalSpace;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < cards.length; i++)
            Transform.rotate(
              angle: (i - (cards.length - 1) / 2) * 0.14 * effectiveScale,
              child: Transform.translate(
                offset: Offset(
                  (i - (cards.length - 1) / 2) * 28 * effectiveScale,
                  6 * effectiveScale,
                ),
                child: Transform.scale(
                  scale: effectiveScale,
                  child: SuitCard(
                    data: cards[i],
                    // Pas hoogte aan op schaal om interne layout ruim te houden
                    height: 150 * effectiveScale + 10,
                    width: 90 * effectiveScale + 4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
