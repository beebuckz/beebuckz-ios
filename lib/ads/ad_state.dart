/// Tracks whether any full-screen ad (rewarded / interstitial / app-open) is
/// currently on screen, so app-open ads don't stack on top of another ad
/// (e.g. when returning to the app right after a rewarded video closes).
class AdState {
  static bool fullscreenVisible = false;
}
