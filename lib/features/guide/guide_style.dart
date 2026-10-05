import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The guide's look: big confident headlines, area colour tints, and the
/// guide's own voice in an italic serif, on a calm light ground.
class G {
  static const bg = Color(0xFFF5F5F7);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF15161C);
  static const muted = Color(0xFF5F6170);
  static const line = Color(0xFFE4E4EA);
  static const soft = Color(0xFFE9E9EF);
  static const tint = Color(0xFFE6E8FF);
  static const tintInk = Color(0xFF1F2780);
  static const good = Color(0xFF2E9E5B);
  static const goodSoft = Color(0xFFDFF3E6);

  static TextStyle display(double size, {Color color = ink, FontWeight w = FontWeight.w900}) =>
      GoogleFonts.redHatDisplay(
          fontSize: size, fontWeight: w, color: color, height: 1.05, letterSpacing: -0.6);

  static TextStyle text(double size,
          {Color color = ink, FontWeight w = FontWeight.w400, double height = 1.4}) =>
      GoogleFonts.redHatText(fontSize: size, fontWeight: w, color: color, height: height);

  static TextStyle voice(double size, {Color color = muted}) => GoogleFonts.libreCaslonText(
      fontSize: size, fontStyle: FontStyle.italic, color: color, height: 1.45);

  static TextStyle label({Color color = muted}) => GoogleFonts.redHatText(
      fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8);
}

class GButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  const GButton(this.label, {super.key, this.onTap, this.primary = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: primary ? G.ink : G.soft,
          foregroundColor: primary ? Colors.white : G.ink,
          disabledBackgroundColor: (primary ? G.ink : G.soft).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label,
            style: primary
                ? G.display(18, color: Colors.white, w: FontWeight.w800)
                : G.text(16, w: FontWeight.w700)),
      ),
    );
  }
}
