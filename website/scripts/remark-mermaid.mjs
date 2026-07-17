// Transforme les blocs ```mermaid en <pre class="mermaid"> rendus côté client
// par public/scripts/mermaid-init.js (chargé via head dans astro.config.mjs).
function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function walk(node) {
  if (!Array.isArray(node.children)) return;
  node.children = node.children.map((child) => {
    if (child.type === 'code' && child.lang === 'mermaid') {
      return { type: 'html', value: `<pre class="mermaid">${escapeHtml(child.value)}</pre>` };
    }
    walk(child);
    return child;
  });
}

export function remarkMermaid() {
  return (tree) => walk(tree);
}
