export const SITE_URL = "https://morse-code.huyakhuyak.productions";
export const TAGLINE = "Learn Morse code in idle minutes.";
export const CONTACT = "mykola@socket.agency";
/** App Store Connect record id; the Smart App Banner shows once the app is live. */
export const APP_STORE_ID = "6824568488";
export const SOURCE_URL = "https://github.com/huyakhuyak-productions/morse-code.huyakhuyak.productions";
/** Public link of the TestFlight group "Friends"; anyone with it can join the beta. */
export const TESTFLIGHT_URL = "https://testflight.apple.com/join/w4vFmtRW";

/**
 * The landing page's one button. It carries the TestFlight public link until release, then the
 * App Store page. It must always carry a real https URL.
 */
export const GET_APP: { label: string; href: string } = {
  label: "Join the TestFlight",
  href: TESTFLIGHT_URL,
};
