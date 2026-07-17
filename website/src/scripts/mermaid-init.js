// Rend les diagrammes Mermaid côté client et suit le thème clair/sombre.
// Chargé sur chaque page via injectScript (astro.config.mjs) ; le paquet
// mermaid n'est téléchargé (chunk séparé) que si la page contient un
// diagramme, grâce à l'import dynamique.
const blocks = document.querySelectorAll('pre.mermaid');

if (blocks.length > 0) {
  const { default: mermaid } = await import('mermaid');

  const sources = new Map();
  blocks.forEach((el) => sources.set(el, el.textContent));

  async function render() {
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
}
