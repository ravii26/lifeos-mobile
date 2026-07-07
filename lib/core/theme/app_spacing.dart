/// Radius and spacing tokens — mirrors the `--r-*` / `--gap` scale in
/// `lifeos-client/design/lifeos/project/app/ds.css`, the canonical design
/// spec. Use these instead of new magic numbers so mobile and web stay on
/// the same scale; see `DESIGN_SYSTEM.md` for the full token reference.
class AppRadius {
  AppRadius._();

  static const xs = 6.0;
  static const sm = 9.0;
  static const md = 13.0;
  static const lg = 18.0;
  static const xl = 24.0;
}

class AppSpacing {
  AppSpacing._();

  /// `--gap` in ds.css (20px at density 1).
  static const gap = 20.0;
}
