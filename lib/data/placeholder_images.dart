// ============================================================
// PLACEHOLDER IMAGES
// ============================================================
// Images are bundled as local assets (assets/images/) so the app
// works fully offline with no network dependency.
// Each getter maps to one of the downloaded photos.

class PlaceholderImages {
  /// Resolves a bundled asset path under assets/images/.
  static String _asset(String name) => 'assets/images/$name.jpg';

  // ============================================================
  // VENDOR COVER IMAGES
  // ============================================================
  static String get greenFarm => _asset('farmland'); // farmland
  static String get yummyBunch => _asset('market'); // market stall
  static String get freshOffFlesh => _asset('meat'); // raw meat
  static String get heartOfRed => _asset('apples'); // red apples
  static String get realGreen => _asset('vegetables'); // veggies
  static String get cerealsGreetings => _asset('wheat'); // wheat ears
  static String get goldenOils => _asset('oil_market'); // market stall with palm oil

  // ============================================================
  // VENDOR LOGOS
  // ============================================================
  static String get greenFarmLogo => _asset('farmland');
  static String get yummyBunchLogo => _asset('market');
  static String get freshOffFleshLogo => _asset('meat');
  static String get heartOfRedLogo => _asset('apples');
  static String get realGreenLogo => _asset('vegetables');
  static String get cerealsGreetingsLogo => _asset('wheat');
  static String get goldenOilsLogo => _asset('oil_market');

  // ============================================================
  // PRODUCT IMAGES - GRAINS
  // ============================================================
  static String get rice => _asset('rice'); // rice bowl
  static String get millet => _asset('wheat'); // wheat ears
  static String get maize => _asset('corn'); // corn cobs
  static String get sorghum => _asset('wheat'); // wheat ears
  static String get beans => _asset('beans'); // beans
  static String get soybeans => _asset('beans'); // beans

  // ============================================================
  // PRODUCT IMAGES - VEGETABLES
  // ============================================================
  static String get tomatoes => _asset('tomatoes'); // tomatoes
  static String get tomatoesCrate => _asset('tomatoes_crate'); // tomatoes
  static String get freshVegetables => _asset('vegetables'); // veggies
  static String get peppers => _asset('peppers'); // chili peppers
  static String get onions => _asset('onions'); // onions
  static String get cabbage => _asset('cabbage'); // cabbage

  // ============================================================
  // PRODUCT IMAGES - HERBS
  // ============================================================
  static String get scentLeaves => _asset('herbs'); // fresh herbs

  // ============================================================
  // PRODUCT IMAGES - TUBERS & ROOTS
  // ============================================================
  static String get potatoes => _asset('potatoes'); // potatoes

  // ============================================================
  // PRODUCT IMAGES - OILS
  // ============================================================
  static String get palmOil => _asset('palm_oil'); // bottles of red palm oil
  static String get groundnutOil => _asset('groundnut_oil'); // peanut oil bottle
  static String get vegetableOil => _asset('vegetable_oil'); // vegetable oil bottle

  // ============================================================
  // PRODUCT IMAGES - FRUITS
  // ============================================================
  static String get freshApples => _asset('apples'); // red apples
  static String get oranges => _asset('oranges'); // oranges
  static String get bananas => _asset('bananas'); // bananas

  // ============================================================
  // PRODUCT IMAGES - PROTEINS
  // ============================================================
  static String get freshProtein => _asset('meat'); // raw meat
  static String get chicken => _asset('chicken'); // chicken
  static String get fish => _asset('fish'); // fish on ice

  // ============================================================
  // PRODUCT IMAGES - EGGS & BUNDLES
  // ============================================================
  static String get eggsTray => _asset('eggs'); // eggs

  // ============================================================
  // BRANDING — official bundled logo assets (not placeholders)
  // ============================================================

  /// Official GROWBOX logo (bundled PNG): white planter icon with orange
  /// "Grow" / white "box" wordmark on a transparent background.
  ///
  /// White art — use on dark surfaces (green splash/registration banners,
  /// dark-theme backgrounds).
  static String get growboxLogo => 'assets/images/growbox_logo.png';

  /// GROWBOX logo dark-art variant (bundled PNG) — use on light surfaces
  /// (light-theme backgrounds). Pick between the two variants using the
  /// current theme's brightness at the call site.
  static String get growboxLogoLight => 'assets/images/growbox_logo_light.png';

  /// Official multicolor Google "G" logo (bundled PNG).
  static String get googleLogo => 'assets/images/google_logo.png';
}