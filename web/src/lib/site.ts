export const SITE_URL = "https://morse-code.huyakhuyak.productions";
export const TAGLINE = "Learn Morse code in idle minutes.";
export const CONTACT = "mykola@socket.agency";
/** App Store Connect record id; the Smart App Banner shows once the app is live. */
export const APP_STORE_ID = "6824568488";
export const SOURCE_URL = "https://github.com/huyakhuyak-productions/morse-code.huyakhuyak.productions";

/**
 * The landing page's one button: the App Store page. It must always carry a real https URL. The
 * storefront segment is required: the bare `/app/id…` link returns 404. iPhones open any
 * storefront's link in the visitor's own store.
 */
export const GET_APP: { label: string; href: string } = {
  label: "Get it on the App Store",
  href: `https://apps.apple.com/us/app/morse-lamp-learn-morse-code/id${APP_STORE_ID}`,
};
