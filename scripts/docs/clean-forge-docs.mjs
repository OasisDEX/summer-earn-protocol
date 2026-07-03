#!/usr/bin/env node
/**
 * Post-processor for `forge doc` output → GitBook-ready markdown.
 *
 * forge doc emits one mdbook page per documented item
 * (<out>/src/<src-tree>/<File>.sol/<kind>.<Name>.md) plus mdbook scaffolding.
 * This script, per package:
 *   - drops scaffolding (book.toml, css/js, README stubs, mdbook SUMMARY.md)
 *   - skips mocks/ and test/ pages
 *   - merges all items of one .sol file into a single kebab-case page
 *   - rewrites mdbook-absolute links to relative GitBook links (+ anchors)
 *   - normalizes Git Source links to blob/main with the full monorepo path
 *     (forge embeds the current commit SHA, which would churn every page on
 *     every commit and trip the drift check)
 *   - prepends front-matter (description from the item's @notice) and a
 *     do-not-edit banner
 *   - writes _nav.json (ordered page tree) for the SUMMARY generator
 *
 * Zero npm dependencies: must run under bare Node in CI of two repos.
 *
 * CLI: node clean-forge-docs.mjs <pkgDir> <outDir> <pkgRelPath>
 * Module: import { cleanPackage } from './clean-forge-docs.mjs'
 */

import * as fs from 'node:fs'
import * as path from 'node:path'

const REPO_URL = 'https://github.com/OasisDEX/summer-earn-protocol'
const EXCLUDE_RE = /(^|\/)(tests?|scripts?|mocks?|examples?)(\/|$)|Mock|\.t\.sol$|\.s\.sol$/i
const KIND_ORDER = ['abstract', 'contract', 'library', 'interface', 'function', 'struct', 'enum', 'error', 'event', 'constants']
const DIR_ORDER = ['contracts', 'interfaces', 'libraries', 'libs', 'base', 'adapters', 'router', 'types', 'events', 'errors', 'utils', 'helpers']

export function kebab(name) {
  return name
    .replace(/\.sol$/, '')
    .replace(/([a-z0-9])([A-Z])/g, '$1-$2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1-$2')
    .toLowerCase()
}

function dirSortKey(dir) {
  const head = dir.split('/')[0]
  const idx = DIR_ORDER.indexOf(head)
  return [idx === -1 ? DIR_ORDER.length : idx, dir]
}

/** Collect item pages: map "<dirRel>/<File>.sol" -> [{kind, name, body}] */
function collectItems(genSrcRoot, srcDirName) {
  const files = new Map()
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(dir, entry.name)
      if (entry.isDirectory()) {
        walk(full)
        continue
      }
      if (!entry.name.endsWith('.md')) continue
      const parent = path.basename(path.dirname(full))
      if (!parent.endsWith('.sol')) continue // README stubs, SUMMARY.md
      const m = entry.name.match(/^(\w+)\.(.+)\.md$/)
      if (!m) continue
      const solRel = path.relative(genSrcRoot, path.dirname(full)) // e.g. src/contracts/IntentHandler.sol
      if (EXCLUDE_RE.test(solRel)) continue
      const key = solRel
      if (!files.has(key)) files.set(key, [])
      files.get(key).push({ kind: m[1], name: m[2], body: fs.readFileSync(full, 'utf8') })
    }
  }
  const root = path.join(genSrcRoot, srcDirName)
  if (fs.existsSync(root)) walk(root)
  for (const items of files.values()) {
    items.sort((a, b) => {
      const ka = KIND_ORDER.indexOf(a.kind)
      const kb = KIND_ORDER.indexOf(b.kind)
      if (ka !== kb) return (ka === -1 ? 99 : ka) - (kb === -1 ? 99 : kb)
      return a.name.localeCompare(b.name)
    })
  }
  return files
}

/** Build link map: "/src/<solRel>/<kind>.<Name>.md" -> {page, anchor|null} */
function buildLinkMap(files, pageFor) {
  const map = new Map()
  for (const [solRel, items] of files) {
    const page = pageFor(solRel)
    items.forEach((item, i) => {
      map.set(`/${solRel}/${item.kind}.${item.name}.md`, {
        page,
        anchor: items.length > 1 && i > 0 ? item.name.toLowerCase() : null,
      })
    })
  }
  return map
}

function extractDescription(body) {
  const lines = body.split('\n')
  let i = 0
  while (i < lines.length && !lines[i].startsWith('# ')) i++
  i++
  while (i < lines.length) {
    const line = lines[i].trim()
    if (!line || line.startsWith('[Git Source]')) {
      i++
      continue
    }
    if (line.startsWith('**')) {
      // skip "**Inherits:**"/"**Title:**"-style blocks and their value lines
      i++
      while (i < lines.length && lines[i].trim() && !lines[i].startsWith('#')) i++
      continue
    }
    if (line.startsWith('#')) return null
    return line.replace(/\s+/g, ' ')
  }
  return null
}

function rewriteLinks(body, linkMap, ownPage, gitbookRoot) {
  return body.replace(/\]\((\/src\/[^)]+\.md)\)/g, (full, target) => {
    const hit = linkMap.get(target)
    if (!hit) return full // external/unknown — leave as-is (visible in review)
    let rel = path.relative(path.dirname(path.join(gitbookRoot, ownPage)), path.join(gitbookRoot, hit.page))
    if (!rel.startsWith('.')) rel = './' + rel
    return `](${rel}${hit.anchor ? '#' + hit.anchor : ''})`
  })
}

function normalizeGitSource(body, pkgRelPath) {
  return body.replace(
    /\[Git Source\]\(https:\/\/github\.com\/[^/]+\/[^/]+\/blob\/[0-9a-f]+\/([^)]+)\)/g,
    (_m, srcPath) => `[Git Source](${REPO_URL}/blob/main/${pkgRelPath}/${srcPath})`,
  )
}

function demote(body) {
  return body
    .split('\n')
    .map((l) => (/^#{1,5} /.test(l) ? '#' + l : l))
    .join('\n')
}

/**
 * @param {string} pkgDir absolute path to the package
 * @param {string} outDir absolute path of the destination dir inside gitbook/
 * @param {string} pkgRelPath e.g. "packages/intent-system"
 * @param {string} gitbookRoot absolute path of the gitbook/ root (for relative links)
 * @returns nav tree for the SUMMARY generator
 */
export function cleanPackage(pkgDir, outDir, pkgRelPath, gitbookRoot, srcDirName = 'src') {
  const genSrcRoot = path.join(pkgDir, 'docs', 'generated', 'src')
  if (!fs.existsSync(genSrcRoot)) {
    throw new Error(`no forge doc output at ${genSrcRoot} — run \`forge doc\` first`)
  }
  const files = collectItems(genSrcRoot, srcDirName)
  const outRel = path.relative(gitbookRoot, outDir)
  const pageFor = (solRel) => {
    // src/contracts/Foo.sol -> <outRel>/contracts/foo.md
    const within = solRel.split('/').slice(1) // drop leading src dir
    const fileName = kebab(within.pop())
    return path.join(outRel, ...within, `${fileName}.md`)
  }
  const linkMap = buildLinkMap(files, pageFor)

  fs.rmSync(outDir, { recursive: true, force: true })
  const nav = new Map() // dirRel -> [{title, file}]

  for (const [solRel, items] of [...files.entries()].sort()) {
    const page = pageFor(solRel)
    const pageAbs = path.join(gitbookRoot, page)
    const primary = items[0]
    const description = extractDescription(primary.body)

    let content
    if (items.length === 1) {
      content = primary.body
    } else {
      const stem = path.basename(solRel, '.sol')
      content = `# ${stem}\n\n` + items.map((it) => demote(it.body)).join('\n\n')
    }
    content = normalizeGitSource(content, pkgRelPath)
    content = rewriteLinks(content, linkMap, page, gitbookRoot)

    const fm = description ? `---\ndescription: >-\n  ${description.replace(/\n/g, ' ')}\n---\n\n` : ''
    const banner = `<!-- AUTOGENERATED by forge doc + scripts/docs/clean-forge-docs.mjs — do not edit. Edit the NatSpec in ${pkgRelPath}/${solRel} instead. -->\n\n`

    fs.mkdirSync(path.dirname(pageAbs), { recursive: true })
    fs.writeFileSync(pageAbs, fm + banner + content.trimEnd() + '\n')

    const dirRel = path.dirname(solRel).split('/').slice(1).join('/') // without src/
    if (!nav.has(dirRel)) nav.set(dirRel, [])
    nav.get(dirRel).push({ title: path.basename(solRel, '.sol'), file: page })
  }

  const tree = [...nav.entries()]
    .sort((a, b) => {
      const [ia, sa] = dirSortKey(a[0])
      const [ib, sb] = dirSortKey(b[0])
      return ia - ib || sa.localeCompare(sb)
    })
    .map(([dir, pages]) => ({ dir, pages: pages.sort((a, b) => a.title.localeCompare(b.title)) }))

  const navJson = { package: path.basename(pkgDir), out: outRel, tree }
  fs.writeFileSync(path.join(outDir, '_nav.json'), JSON.stringify(navJson, null, 2) + '\n')
  return navJson
}

// CLI entry
if (process.argv[1] && import.meta.url.endsWith(path.basename(process.argv[1]))) {
  const [pkgDir, outDir, pkgRelPath] = process.argv.slice(2)
  if (!pkgDir || !outDir || !pkgRelPath) {
    console.error('usage: node clean-forge-docs.mjs <pkgDir> <outDir> <pkgRelPath> [gitbookRoot]')
    process.exit(1)
  }
  const gitbookRoot = process.argv[5] ?? path.resolve(outDir, '..', '..')
  const nav = cleanPackage(path.resolve(pkgDir), path.resolve(outDir), pkgRelPath, path.resolve(gitbookRoot))
  console.log(`${nav.package}: ${nav.tree.reduce((n, g) => n + g.pages.length, 0)} pages`)
}
