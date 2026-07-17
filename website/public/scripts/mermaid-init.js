// Rend les diagrammes Mermaid côté client et suit le thème clair/sombre.
import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';

const sources = new Map();
document.querySelectorAll('pre.mermaid').forEach((el) => sources.set(el, el.textContent));

async function render() {
  if (sources.size === 0) return;
  const theme = document.documentElement.dataset.theme === 'light' ? 'neutral' : 'dark';
  for (const [el, code] of sources) {
    el.removeAttribute('data-processed');
    el.textContent = code;
  }
  mermaid.initialize({ startOnLoad: false, theme });
  await mermaid.run({ nodes: [...sources.keys()] });
}

render();
new MutationObserver(render).observe(document.documentElement, {
  attributes: true,
  attributeFilter: ['data-theme'],
});
