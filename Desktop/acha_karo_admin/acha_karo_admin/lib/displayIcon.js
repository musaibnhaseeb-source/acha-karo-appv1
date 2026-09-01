// Real fix here, needed in multiple places — an icon field can be a real image URL (often 80+
// characters), and every place that displayed {icon} directly as raw text would have that full
// URL dumped into a small, fixed-size circle, breaking the layout entirely. This shows a short,
// honest placeholder instead when the value is a URL, and the real emoji/character otherwise.
export function displayIcon(icon) {
  if (!icon) return '';
  return icon.startsWith('http') ? 'http' : icon;
}
