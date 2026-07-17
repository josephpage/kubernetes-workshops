#!/usr/bin/env node
// Synchronise les README et docs de conventions du dépôt vers website/src/content/docs/.
// Les fichiers sources restent la seule source de vérité : ce script régénère
// les fichiers générés à chaque exécution (voir "prestart"/"prebuild").
//
// N'utilise que des modules natifs Node (aucune dépendance externe).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const WEBSITE_ROOT = path.resolve(__dirname, '..');
const REPO_ROOT = path.resolve(WEBSITE_ROOT, '..');
const DOCS_OUT_DIR = path.join(WEBSITE_ROOT, 'src', 'content', 'docs');

const GITHUB_REPO_BLOB_BASE =
  'https://github.com/josephpage/kubernetes-workshops/blob/main';
const GITHUB_REPO_TREE_BASE =
  'https://github.com/josephpage/kubernetes-workshops/tree/main';

// ---------------------------------------------------------------------------
// Table de mapping : source (relative à la racine du dépôt) -> destination
// (relative à website/src/content/docs/), avec frontmatter optionnel.
// ---------------------------------------------------------------------------
const FILE_MAPPING = [
  {
    source: 'README.md',
    destination: 'introduction.md',
  },
  {
    source: 'demos/crossplane/README.md',
    destination: 'ateliers/crossplane.md',
  },
  {
    source: 'demos/kratix/README.md',
    destination: 'ateliers/kratix.md',
  },
  {
    source: 'demos/kubeception/README.md',
    destination: 'ateliers/kubeception.md',
  },
  {
    source: 'demos/kong/README.md',
    destination: 'ateliers/kong.md',
  },
  {
    source: 'docs/workshop-template.md',
    destination: 'conventions/workshop-template.md',
  },
  {
    source: 'docs/workshop-quality-checklist.md',
    destination: 'conventions/workshop-quality-checklist.md',
  },
  {
    source: 'docs/agent-workflows.md',
    destination: 'conventions/agent-workflows.md',
  },
  {
    source: 'docs/repo-analysis.md',
    destination: 'conventions/repo-analysis.md',
  },
  {
    source: 'docs/kratix-vs-crossplane-comparison.md',
    destination: 'comparatifs/kratix-vs-crossplane-comparison.md',
  },
  {
    source: 'docs/platform-engineering-recommendations.md',
    destination: 'comparatifs/platform-engineering-recommendations.md',
  },
  {
    source: 'clusters/azure-managed/README.md',
    destination: 'environnements/azure-managed.md',
  },
  {
    source: 'clusters/scaleway-kapsule/README.md',
    destination: 'environnements/scaleway-kapsule.md',
  },
];

// ---------------------------------------------------------------------------
// Index : chemin source (relatif à la racine du dépôt, normalisé en posix)
// -> entrée de mapping. Sert à résoudre les liens relatifs entre sources.
// ---------------------------------------------------------------------------
const sourceToMapping = new Map();
for (const entry of FILE_MAPPING) {
  sourceToMapping.set(toPosix(entry.source), entry);
}

function toPosix(p) {
  return p.split(path.sep).join('/');
}

function log(message) {
  console.log(`[sync-docs] ${message}`);
}

function fail(message) {
  console.error(`[sync-docs] ERREUR: ${message}`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Étape a) Vider seulement les chemins générés (préserve index.mdx/404.md).
// ---------------------------------------------------------------------------
const GENERATED_PATHS = ['introduction.md', 'ateliers', 'comparatifs', 'conventions', 'environnements'];

function resetGeneratedContent() {
  for (const rel of GENERATED_PATHS) {
    fs.rmSync(path.join(DOCS_OUT_DIR, rel), { recursive: true, force: true });
  }
  fs.mkdirSync(DOCS_OUT_DIR, { recursive: true });
  log('contenu généré réinitialisé dans src/content/docs/.');
}

// ---------------------------------------------------------------------------
// Extraction du titre H1 (requis par Starlight).
// ---------------------------------------------------------------------------
function extractTitle(body, sourceRelPath) {
  const match = body.match(/^#\s+(.+?)\s*$/m);
  if (!match) fail(`pas de titre H1 dans "${sourceRelPath}" (requis par Starlight).`);
  const title = match[1].trim();
  const idx = body.indexOf(match[0]);
  const stripped = (body.slice(0, idx) + body.slice(idx + match[0].length)).replace(/^\s*\n/, '');
  return { title, body: stripped };
}

// ---------------------------------------------------------------------------
// Date de dernière mise à jour (best-effort via git log).
// ---------------------------------------------------------------------------
function sourceLastUpdated(sourceRelPath) {
  try {
    const out = execSync(`git log -1 --format=%cs -- "${sourceRelPath}"`, { cwd: REPO_ROOT, encoding: 'utf8' }).trim();
    return out || null; // format YYYY-MM-DD
  } catch { return null; }
}

// ---------------------------------------------------------------------------
// Frontmatter YAML : parsing minimal + fusion + sérialisation.
// ---------------------------------------------------------------------------
const FRONTMATTER_RE = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/;

function splitFrontmatter(content) {
  const match = content.match(FRONTMATTER_RE);
  if (!match) {
    return { frontmatter: {}, body: content };
  }
  const raw = match[1];
  const frontmatter = {};
  for (const line of raw.split(/\r?\n/)) {
    if (!line.trim()) continue;
    const idx = line.indexOf(':');
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    let value = line.slice(idx + 1).trim();
    // Retire les guillemets simples/doubles englobants.
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    frontmatter[key] = value;
  }
  return { frontmatter, body: content.slice(match[0].length) };
}

function serializeFrontmatterValue(value, isDate) {
  if (typeof value === 'number') return String(value);
  if (typeof value === 'boolean') return String(value);
  if (isDate) return value; // YYYY-MM-DD non-quoté pour le champ lastUpdated
  // Chaîne : on quote si nécessaire (présence de ':' ou caractères spéciaux YAML).
  const needsQuotes = /[:#\[\]{}]/.test(value) || value === '';
  return needsQuotes ? JSON.stringify(value) : value;
}

function buildFrontmatter(existing, additions) {
  const merged = { ...existing, ...additions };
  const lines = ['---'];
  for (const [key, value] of Object.entries(merged)) {
    const isDate = key === 'lastUpdated';
    lines.push(`${key}: ${serializeFrontmatterValue(value, isDate)}`);
  }
  lines.push('---', '');
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// Étape e) Réécriture des liens Markdown relatifs.
// ---------------------------------------------------------------------------
const MD_LINK_RE = /(!?\[[^\]]*\])\(([^)]+)\)/g;

function isIgnorableLink(target) {
  return (
    /^[a-z][a-z0-9+.-]*:/i.test(target) || // schéma (http:, https:, mailto:, etc.)
    target.startsWith('#') ||
    target.trim() === ''
  );
}

function splitTargetAndAnchor(target) {
  const hashIdx = target.indexOf('#');
  if (hashIdx === -1) return { path: target, anchor: '' };
  return { path: target.slice(0, hashIdx), anchor: target.slice(hashIdx) };
}

function rewriteLinksInContent(content, sourceRelPath) {
  const sourceDirAbs = path.dirname(path.join(REPO_ROOT, sourceRelPath));
  const currentMapping = sourceToMapping.get(toPosix(sourceRelPath));
  const currentDestDirAbs = path.dirname(
    path.join(DOCS_OUT_DIR, currentMapping.destination),
  );

  return content.replace(MD_LINK_RE, (full, labelPart, rawTarget) => {
    const target = rawTarget.trim();
    if (isIgnorableLink(target)) {
      return full;
    }

    const { path: targetPathPart, anchor } = splitTargetAndAnchor(target);
    if (targetPathPart === '') {
      // Lien de type "#ancre" déjà filtré, mais on protège quand même.
      return full;
    }

    // Résout le chemin absolu (sur disque) de la cible.
    const targetAbs = path.resolve(sourceDirAbs, targetPathPart);
    const targetRelToRepo = toPosix(path.relative(REPO_ROOT, targetAbs));

    const targetMapping = sourceToMapping.get(targetRelToRepo);

    if (targetMapping) {
      // La cible est un fichier source synchronisé : on pointe vers la route absolue du site.
      const route = '/' + targetMapping.destination.replace(/\.md$/, '') + '/';
      return `${labelPart}(${route}${anchor})`;
    }

    // Sinon : lien vers un fichier/dossier hors périmètre synchronisé -> GitHub.
    let existsAsDir = false;
    try {
      existsAsDir = fs.statSync(targetAbs).isDirectory();
    } catch {
      existsAsDir = false;
    }
    const base = existsAsDir ? GITHUB_REPO_TREE_BASE : GITHUB_REPO_BLOB_BASE;
    const githubUrl = `${base}/${targetRelToRepo}${anchor}`;
    return `${labelPart}(${githubUrl})`;
  });
}

// ---------------------------------------------------------------------------
// Étape b/d/e) Copie + frontmatter + réécriture des liens.
// ---------------------------------------------------------------------------
function syncFile(entry) {
  const sourceAbs = path.join(REPO_ROOT, entry.source);
  if (!fs.existsSync(sourceAbs)) {
    fail(
      `fichier source manquant: "${entry.source}" (attendu pour générer "${entry.destination}").`,
    );
  }

  const rawContent = fs.readFileSync(sourceAbs, 'utf8');
  const { frontmatter: existingFrontmatter, body } = splitFrontmatter(rawContent);

  // Extraire le titre H1 et le retirer du corps
  const { title, body: bodyWithoutH1 } = extractTitle(body, entry.source);

  // Récupérer la date lastUpdated (best-effort)
  const lastUpdated = sourceLastUpdated(entry.source);

  const additions = {
    title,
    editUrl: `${GITHUB_REPO_BLOB_BASE}/${toPosix(entry.source)}`,
    ...(lastUpdated ? { lastUpdated } : {}),
    ...(entry.frontmatter ?? {}),
  };

  const frontmatterBlock = buildFrontmatter(existingFrontmatter, additions);
  const rewrittenBody = rewriteLinksInContent(bodyWithoutH1, entry.source);

  const finalContent = `${frontmatterBlock}\n${rewrittenBody}`;

  const destAbs = path.join(DOCS_OUT_DIR, entry.destination);
  fs.mkdirSync(path.dirname(destAbs), { recursive: true });
  fs.writeFileSync(destAbs, finalContent, 'utf8');
}

function run() {
  resetGeneratedContent();

  let count = 0;
  for (const entry of FILE_MAPPING) {
    syncFile(entry);
    count += 1;
  }

  log(`${count} fichier(s) synchronisé(s) vers "${path.relative(REPO_ROOT, DOCS_OUT_DIR)}".`);
}

run();
