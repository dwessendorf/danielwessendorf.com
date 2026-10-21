// Draws depth contour lines (Lake Starnberg goes down to about 128 m) behind the homepage portrait.
(function () {
  const canvas = document.querySelector("[data-contours]");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const RINGS = 9;
  // Ring index → [label, angle in radians]. Angles are staggered so the labels do not stack.
  const DEPTH_LABELS = { 1: ["−120 m", -2.7], 4: ["−80 m", -2.3], 7: ["−40 m", -1.9] };
  // Fixed harmonics so the shape is identical on every load.
  const HARMONICS = [
    { k: 2, amp: 0.07, phase: 0.6 },
    { k: 3, amp: 0.045, phase: 2.1 },
    { k: 5, amp: 0.02, phase: 4.0 },
  ];

  function radiusAt(base, theta, ring) {
    let r = 1;
    for (const h of HARMONICS) r += h.amp * Math.sin(h.k * theta + h.phase + ring * 0.35);
    return base * r;
  }

  function draw(progress) {
    const rect = canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, rect.width, rect.height);

    const style = getComputedStyle(canvas);
    const line = style.getPropertyValue("--dw-contour").trim();
    const deep = style.getPropertyValue("--dw-contour-deep").trim();
    const label = style.getPropertyValue("--dw-muted").trim();
    const cx = rect.width / 2;
    const cy = rect.height / 2;
    const inner = Math.min(rect.width, rect.height) * 0.27;
    const outer = Math.min(rect.width, rect.height) * 0.44;
    const visible = Math.ceil(RINGS * progress);

    for (let i = 0; i < visible; i++) {
      const base = inner + ((outer - inner) * i) / (RINGS - 1);
      // Rings drift slightly east as the water gets shallower, like a real lake basin.
      const ox = cx + i * 1.6;
      const oy = cy - i * 0.8;
      ctx.beginPath();
      for (let s = 0; s <= 180; s++) {
        const t = (s / 180) * Math.PI * 2;
        const r = radiusAt(base, t, i);
        const x = ox + r * Math.cos(t);
        const y = oy + r * Math.sin(t);
        s === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.strokeStyle = i < 3 ? deep : line;
      ctx.lineWidth = i < 3 ? 1.25 : 1;
      ctx.stroke();

      if (DEPTH_LABELS[i]) {
        // Labels sit on the upper left of each ring, right-aligned so they never leave the canvas.
        const [text, t] = DEPTH_LABELS[i];
        const r = radiusAt(base, t, i);
        ctx.font = '10px "JetBrains Mono Variable", ui-monospace, monospace';
        ctx.textAlign = "right";
        ctx.fillStyle = label;
        ctx.fillText(text, ox + r * Math.cos(t) - 4, oy + r * Math.sin(t));
      }
    }
  }

  let progress = reduceMotion ? 1 : 0;

  function animateIn() {
    if (reduceMotion) return draw(progress);
    const start = performance.now();
    const step = (now) => {
      progress = Math.min(1, (now - start) / 1100);
      draw(progress);
      if (progress < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }

  new ResizeObserver(() => draw(progress)).observe(canvas);
  // Hextra toggles the "dark" class on <html>; redraw with the new colors.
  new MutationObserver(() => draw(progress)).observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(animateIn);
  else animateIn();
})();
