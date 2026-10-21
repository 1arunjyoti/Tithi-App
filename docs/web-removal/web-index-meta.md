# Preserved SEO metadata from `web/index.html`

`web/` is generator output and can be recreated with
`flutter create . --platforms=web`, except for the hand-written meta block below.
Preserved here so a future web build (or the separate marketing site) can reuse it.

Source: `web/index.html` lines 20–40, recorded 2026-10-21 before deletion.

## Description / keywords / author

```html
<!-- SEO Meta Tags -->
<meta name="description" content="Tithi - Your Hindu Panchang Calendar. Check daily tithi, nakshatra, festivals, muhurta, and auspicious timings based on your location.">
<meta name="keywords" content="tithi, panchang, hindu calendar, festivals, nakshatra, muhurta, sunrise, sunset, moon phases, vedic astrology">
<meta name="author" content="Tithi App">
```

## Open Graph / social sharing

```html
<!-- Open Graph / Social Media -->
<meta property="og:title" content="Tithi - Hindu Panchang Calendar">
<meta property="og:description" content="Your spiritual companion for Hindu calendar, festivals, tithi, nakshatra, and auspicious timings.">
<meta property="og:type" content="website">
<meta property="og:image" content="icons/Icon-512.png">
```

## iOS standalone metadata

```html
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Tithi">
<link rel="apple-touch-icon" href="icons/Icon-192.png">
```

## Title

```html
<title>Tithi - Hindu Panchang Calendar</title>
```

## `manifest.json` fields that were hand-edited

The manifest itself is regenerable (and its four icons came from
`flutter_launcher_icons.yaml`'s now-removed `web:` block), but these fields are not
defaults:

```json
{
  "name": "Tithi - Hindu Panchang Calendar",
  "short_name": "Tithi",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#ffffff",
  "description": "Your spiritual companion for Hindu calendar, festivals, tithi, nakshatra, and auspicious timings.",
  "categories": ["lifestyle", "utilities", "education"]
}
```

## Notes for a future web build

Two problems in the original file are worth fixing rather than copying:

1. It declares `<meta name="viewport">` twice (lines 43 and 48) with conflicting
   `user-scalable=yes` / `user-scalable=no`. Keep one, with `user-scalable=yes`.
2. `og:image` is a relative path (`icons/Icon-512.png`). Open Graph requires an
   absolute URL, so link previews will not render an image as written.

The marketing site at `tithiapp.netlify.app` is a separate, hand-built site. It is the
right home for this copy — not a regenerated Flutter build.
