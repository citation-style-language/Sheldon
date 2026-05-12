import { Octokit } from '@octokit/rest'
import { DOMParser, XMLSerializer } from '@xmldom/xmldom'
import { execSync } from 'child_process'
import CSL from 'citeproc'
import { program } from 'commander'
import { createPatch } from 'diff'
import ejs from 'ejs'
import fs from 'fs'
import { mkdtempSync } from 'fs'
import he from 'he'
import { tmpdir } from 'os'
import parseDiff from 'parse-diff'
import path from 'path'
import { fileURLToPath } from 'url'
import xpath from 'xpath'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// ---------------------------------------------------------------------------
// Template
// ---------------------------------------------------------------------------

export class Template {
  static ROOT = path.join(__dirname, 'templates')

  static load(name, ext = '.md.ejs') {
    const filePath = path.join(Template.ROOT, `${name}${ext}`)
    return new Template(fs.readFileSync(filePath, 'utf-8'), name)
  }

  constructor(text, name = null) {
    this.text = text
    this.name = name
  }

  render(locals = {}) {
    return ejs.render(this.text, locals)
  }
}

// ---------------------------------------------------------------------------
// GitHubAction
// ---------------------------------------------------------------------------

class GitHubAction {
  static async create() {
    const action = new GitHubAction()
    await action.init()
    return action
  }

  async init() {
    program
      .option('--welcome', 'post welcome comment on opened PR')
      .option('--apply', 'apply PR diff to working directory')
      .option('--report', 'post build report (auto-detect pass/fail)')
      .option('--failure', 'post build failure comment')
      .option('--success', 'post build success comment')
      .option('--token <token>', 'GitHub token')
      .option('--release <dir>', 'update timestamps for released files')
      .option('--populate <dir>', 'populate and update timestamps for all files')
      .option('-v, --verbose', 'verbose logging')
      .option('--contributor', 'disable file whitelist for contributors')
      .allowUnknownOption(false)
      .exitOverride()

    try {
      program.parse(process.argv)
    }
    catch (err) {
      console.error(err.message)
      process.exit(1)
    }

    const opts = program.opts()
    this.verbose = opts.verbose || false
    this.contributor = opts.contributor || false

    // Determine which action was requested
    const actionFlags = ['welcome', 'apply', 'report', 'failure', 'success']
    const requestedActions = actionFlags.filter(f => opts[f])

    if (requestedActions.length > 1) {
      console.error(`Can't do multiple actions at once: ${requestedActions.join(', ')}`)
      process.exit(1)
    }

    this.action = requestedActions[0] || null

    const hasMutuallyExclusive = [this.action, opts.release, opts.populate].filter(Boolean).length
    if (hasMutuallyExclusive > 1) {
      console.error("Can't combine --release or --populate with other action flags")
      process.exit(1)
    }

    if (!this.action && !opts.release && !opts.populate) {
      program.outputHelp()
      process.exit(1)
    }

    if (this.action && !opts.token) {
      console.error('Missing required option: --token')
      process.exit(1)
    }

    // Establish repo + file extension
    const githubRepo = process.env.GITHUB_REPOSITORY
    this.repo = githubRepo.split('/').pop()

    const extMap = { styles: '.csl', locales: '.xml', journals: '.tab' }
    this.ext = extMap[this.repo]
    if (!this.ext) throw new Error(`Asset extension cannot be established for repo: ${this.repo}`)

    const langmapPath = fileURLToPath(new URL('./bin/langmap.json', import.meta.url))
    this.langmap = JSON.parse(fs.readFileSync(langmapPath, 'utf-8'))

    // --populate
    if (opts.populate) {
      if (process.env.GITHUB_EVENT_NAME !== 'workflow_dispatch') {
        throw new Error('populate can only be performed on a workflow_dispatch')
      }
      this.populateDir = opts.populate
      await this.populate()
      return
    }

    // Set up Octokit + load event payload
    this.octokit = new Octokit({ auth: opts.token })

    const [owner, repoName] = githubRepo.split('/')
    this.owner = owner
    this.repoName = repoName

    this.event = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf-8'))

    const localesRaw = await this.octokit.repos.getContent({
      owner: 'citation-style-language',
      repo: 'locales',
      path: 'locales.json',
      ref: 'master',
    })
    const localesJson = JSON.parse(Buffer.from(localesRaw.data.content, 'base64').toString())
    let locales = Object.keys(localesJson['language-names']).sort()
    locales = [...new Set(locales.flatMap(lc => [lc, lc.replace(/-.*/, '')]))].sort()
    this.locales = locales

    // --release
    if (opts.release) {
      if (process.env.GITHUB_EVENT_NAME !== 'push') {
        throw new Error('release can only be performed on a push')
      }
      this.releaseDir = opts.release
      await this.release()
      return
    }

    if (process.env.GITHUB_EVENT_NAME !== 'pull_request_target') {
      throw new Error(`${this.action} can only be performed on a pull request`)
    }

    // Fetch PR diff
    const diffUrl = this.event.pull_request.diff_url
    console.log(`Loading patch from ${diffUrl}`)
    const diffResp = await fetch(diffUrl, { redirect: 'follow' })
    this.patch = await diffResp.text()

    // Parse diff into Asset list
    this.diff = []
    const files = parseDiff(this.patch)
    for (const f of files) {
      const bPath = f.to === '/dev/null' ? null : f.to
      const aPath = f.from === '/dev/null' ? null : f.from

      if (bPath && !this.contributor) {
        const ext = path.extname(bPath)
        if (![this.ext, '.json', '.yaml', '.yml'].includes(ext)) {
          throw new Error(`Unexpected ${this.repo} file ${bPath} in pull request`)
        }
      }

      if (aPath === null) {
        // created
        this.diff.push({ path: bPath, source: null })
        if (this.verbose) console.log(`Created: ${bPath}`)
      }
      else if (bPath === null) {
        // deleted
        this.diff.push({ path: null, source: aPath })
        if (this.verbose) console.log(`Deleted: ${aPath}`)
      }
      else if (aPath === bPath) {
        // modified
        this.diff.push({ path: bPath, source: aPath })
        if (this.verbose) console.log(`Modified: ${bPath}`)
      }
      else {
        // renamed
        this.diff.push({ path: bPath, source: aPath })
        if (this.verbose) console.log(`Renamed ${aPath} => ${bPath}`)
      }
    }

    // Dispatch to the requested action
    switch (this.action) {
      case 'welcome':
        await this.welcome()
        break
      case 'apply':
        await this.apply()
        break
      case 'report':
        await this.report()
        break
      case 'failure':
        await this.report(false)
        break
      case 'success':
        await this.report(true)
        break
      default:
        throw new Error(`Unexpected action ${this.action}`)
    }
  }

  // -------------------------------------------------------------------------
  // copy — write a single file to target dir, stamping <updated> if needed
  // -------------------------------------------------------------------------
  copy(targetDir, assetPath, timestamp) {
    if (path.extname(assetPath) !== this.ext) {
      fs.copyFileSync(assetPath, path.join(targetDir, assetPath))
      return
    }
    if (!timestamp) throw new Error(`No timestamp for ${assetPath}`)
    if (this.verbose) console.log(`updating timestamp on ${path.join(targetDir, assetPath)} to ${timestamp}`)

    const doc = fs.readFileSync(assetPath, 'utf-8')
    const updated = doc.replace(/<updated>[^<]+<\/updated>/, `<updated>${timestamp}</updated>`)
    if (doc === updated) throw new Error(`Failed to patch ${assetPath} to ${timestamp}`)
    fs.mkdirSync(path.dirname(path.join(targetDir, assetPath)), { recursive: true })
    fs.writeFileSync(path.join(targetDir, assetPath), updated)
  }

  // -------------------------------------------------------------------------
  // release — stamp timestamps on released files passed as remaining argv
  // -------------------------------------------------------------------------
  async release() {
    const timestamp = this.event.commits.map(c => c.timestamp).sort().pop()
    for (const asset of program.args) {
      this.copy(this.releaseDir, asset, timestamp)
    }
  }

  // -------------------------------------------------------------------------
  // populate — backfill timestamps from git log
  // -------------------------------------------------------------------------
  async populate() {
    let timestamp = null
    const cwd = path.resolve(process.cwd())
    const copied = new Set()

    const log = execSync('git log --format=format:"<<%aI>>" --name-only .').toString()
    for (const line of log.split('\n')) {
      const trimmed = line.trim()
      if (!trimmed) continue

      const tsMatch = trimmed.match(/^<<(.+)>>$/)
      if (tsMatch) {
        timestamp = tsMatch[1]
        continue
      }

      if (path.resolve(path.dirname(trimmed)) !== cwd) continue
      if (!fs.existsSync(trimmed) || !fs.statSync(trimmed).isFile()) continue
      if ((path.extname(trimmed) === this.ext || trimmed === 'publishers.json') && !copied.has(trimmed)) {
        copied.add(trimmed)
        this.copy(this.populateDir, trimmed, timestamp)
      }
    }
  }

  // -------------------------------------------------------------------------
  // welcome — post opening PR comment
  // -------------------------------------------------------------------------
  async welcome() {
    if (this.event.action !== 'opened') {
      throw new Error('Only call me when a new GitHub PR is opened')
    }
    const template = Template.load(path.join(this.repo, 'pull_request_opened'))
    await this.feedback(template.render())
  }

  // -------------------------------------------------------------------------
  // apply — checkout PR's changed files into workspace
  // -------------------------------------------------------------------------
  async apply() {
    const sha = this.event.pull_request.head.sha

    // First remove deletes and old rename sources
    const seenSources = new Set()
    for (const asset of this.diff) {
      if (asset.source && asset.source !== asset.path && !seenSources.has(asset.source)) {
        seenSources.add(asset.source)
        if (fs.existsSync(asset.source)) {
          if (!asset.path) console.log(`${asset.source} deleted`)
          fs.unlinkSync(asset.source)
        }
      }
    }

    // Then apply modifications / new files / renames
    const seenPaths = new Set()
    for (const asset of this.diff) {
      if (!asset.path || seenPaths.has(asset.path)) continue
      seenPaths.add(asset.path)

      if (asset.path === asset.source) {
        console.log(`${asset.path} modified`)
      }
      else if (asset.source) {
        console.log(`${asset.source} renamed to ${asset.path}`)
      }
      else {
        console.log(`${asset.path} added`)
      }
      fs.mkdirSync(path.dirname(asset.path), { recursive: true })
      fs.writeFileSync(asset.path, await this.get(asset.path, sha))
    }
  }

  // -------------------------------------------------------------------------
  // feedback — post a comment on the PR
  // -------------------------------------------------------------------------
  async feedback(msg) {
    await this.octokit.issues.createComment({
      owner: this.owner,
      repo: this.repoName,
      issue_number: this.event.number,
      body: msg,
    })
  }

  // -------------------------------------------------------------------------
  // report — post pass/fail build comment
  // -------------------------------------------------------------------------
  async report(success = null) {
    const buildUrl = `https://github.com/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}`
    const vars = { build_url: buildUrl }
    const failures = []

    // Collect CI test failures
    if (fs.existsSync('spec/sheldon/ci.json')) {
      const ci = JSON.parse(fs.readFileSync('spec/sheldon/ci.json', 'utf-8'))
      for (const ex of ci.examples) {
        if (ex.status === 'passed') continue
        let entry = '<b>' + he.encode(ex.full_description.replace(/\u001b\[([;\d]+)?m/g, '')) + '</b>'
        entry += '\n```\n' + ex.exception.message.replace(/\u001b\[([;\d]+)?m/g, '').trim() + '\n```\n'
        failures.push(entry)
      }
    }

    // CSL default-locale validation
    const select = xpath.useNamespaces({ csl: 'http://purl.org/net/xbiblio/csl' })
    const sha = this.event.pull_request.head.sha
    const seenCsl = new Set()
    for (const asset of this.diff) {
      if (!asset.path || !asset.path.endsWith('.csl') || seenCsl.has(asset.path)) continue
      seenCsl.add(asset.path)

      const content = await this.get(asset.path, sha)
      const doc = new DOMParser().parseFromString(content, 'text/xml')

      const dlNodes = select('/csl:style/@default-locale', doc)
      let dl = dlNodes.length ? dlNodes[0].nodeValue : ''
      if (!dl) dl = 'en-US'

      const titleNodes = select('/csl:style/csl:info/csl:title', doc)
      const title = titleNodes.length ? titleNodes[0].textContent : ''
      const langMatch = title.match(/\((.+)\)$/)
      const language = langMatch ? langMatch[1] : null

      const cslLabel = `<b>${he.encode(path.basename(asset.path))}</b><br>`
      if (!this.locales.includes(dl)) {
        failures.push(`${cslLabel}Unexpected default-language ${JSON.stringify(dl)} (must be one of ${JSON.stringify(this.locales)}<br>\n\n`)
      }
      else if (!dl.startsWith('en-')) {
        if (language === null) {
          failures.push(`${cslLabel}title should include natural language version of default-locale ${JSON.stringify(dl)} in parentheses<br>\n\n`)
        }
        else if (this.langmap[dl] && this.langmap[dl] !== language) {
          failures.push(`${cslLabel}title should include natural language version of default-locale ${JSON.stringify(dl)} in parentheses; expected ${JSON.stringify(this.langmap[dl])} but found ${JSON.stringify(language)}<br>\n\n`)
        }
      }
    }

    if (success === null) success = failures.length === 0
    if (!success && failures.length === 0) return

    let template
    if (failures.length > 0) {
      if (this.verbose) console.log(`${failures.length} failures found`)
      template = Template.load(path.join(this.repo, 'build_failed'))
      const count = failures.length
      vars.build_details = `<details><summary>${count} test${count === 1 ? '' : 's'} failed</summary>\n\n${failures.join('\n')}\n\n</details>`
    }
    else {
      if (this.verbose) console.log('No failures found')
      template = Template.load(path.join(this.repo, 'build_passed'))
      if (this.repo === 'styles') {
        vars.build_details = await this.stylesPassed()
      }
      else if (this.repo === 'locales') {
        vars.build_details = this.localesPassed()
      }
      else {
        throw new Error(`Unexpected repo ${this.repo}`)
      }
    }

    await this.feedback(template.render(vars))
  }

  // -------------------------------------------------------------------------
  // localesPassed — no extra details for locales build success
  // -------------------------------------------------------------------------
  localesPassed() {
    return ''
  }

  // -------------------------------------------------------------------------
  // renderCitations — run citeproc-js and return HTML citations + bibliography
  // -------------------------------------------------------------------------
  renderCitations(items, styleXml, locale) {
    const itemsById = items.reduce((acc, item) => {
      acc[item.id] = item
      return acc
    }, {})

    const sys = {
      retrieveLocale(lang) {
        if (lang === 'en') lang = 'en-US'
        return fs.readFileSync(`../locales/locales-${lang}.xml`, 'utf-8')
      },
      retrieveItem(id) {
        return itemsById[id]
      },
    }

    const cp = new CSL.Engine(sys, styleXml)
    cp.updateItems(Object.keys(itemsById))

    let result = ''
    const itemList = [...items]
    while (itemList.length) {
      const citation = {
        properties: {},
        citationItems: itemList.splice(0, 2),
      }
      result += cp.previewCitationCluster(citation, [], [], 'html') + '<br/>\n'
    }

    const bibliography = cp.makeBibliography()
    if (bibliography) {
      result += '<hr/>\n'
      result += bibliography[1].join('<br/>\n') + '<br/>\n'
    }

    return result
  }

  // -------------------------------------------------------------------------
  // get — fetch file content from GitHub at a given ref
  // -------------------------------------------------------------------------
  async get(filePath, ref) {
    const resp = await this.octokit.repos.getContent({
      owner: this.owner,
      repo: this.repoName,
      path: filePath,
      ref,
    })
    return Buffer.from(resp.data.content, 'base64').toString()
  }

  // -------------------------------------------------------------------------
  // defaultLocale — parse default-locale from CSL XML string or file path
  // -------------------------------------------------------------------------
  defaultLocale(styleXmlOrPath) {
    let xml = styleXmlOrPath
    if (!xml.trimStart().startsWith('<') && fs.existsSync(styleXmlOrPath)) {
      xml = fs.readFileSync(styleXmlOrPath, 'utf-8')
    }
    const select = xpath.useNamespaces({ csl: 'http://purl.org/net/xbiblio/csl' })
    const doc = new DOMParser().parseFromString(xml, 'text/xml')
    const nodes = select('/csl:style/@default-locale', doc)
    return nodes.length ? nodes[0].nodeValue : null
  }

  // -------------------------------------------------------------------------
  // loadStyle — resolve dependent → independent CSL parent style
  // -------------------------------------------------------------------------
  loadStyle(stylesDir, uri) {
    const select = xpath.useNamespaces({ csl: 'http://purl.org/net/xbiblio/csl' })
    const id = uri.replace('http://www.zotero.org/styles/', '')
    let stylePath = path.join(stylesDir, 'dependent', `${id}.csl`)
    if (!fs.existsSync(stylePath)) stylePath = path.join(stylesDir, `${id}.csl`)

    const styleXml = fs.readFileSync(stylePath, 'utf-8')
    let doc = new DOMParser().parseFromString(styleXml, 'text/xml')
    const parents = select('/csl:style/csl:info[1]/csl:link[@rel="source" or @rel="independent-parent"][1]/@href', doc)
    if (parents.length) {
      let parent = parents[0].nodeValue
      if (parent === uri) throw new Error(`${uri} lists itself as parent style`)
      const dlNodes = select('/csl:style/@default-locale', doc)
      const defaultLocale = dlNodes.length ? dlNodes[0].nodeValue : null

      const resolvedParent = this.loadStyle(stylesDir, parent)
      doc = new DOMParser().parseFromString(resolvedParent, 'text/xml')
      if (defaultLocale) select('/csl:style', doc)[0].setAttribute('default-locale', defaultLocale)

      return new XMLSerializer().serializeToString(doc)
    }
    return styleXml
  }

  // -------------------------------------------------------------------------
  // stylesPassed — render sample citations for changed .csl files
  // -------------------------------------------------------------------------
  async stylesPassed() {
    const sha = this.event.pull_request.head.sha

    const seenPaths = new Set()
    const styles = this.diff
      .filter(a => a.path && a.path.endsWith('.csl') && !seenPaths.has(a.path) && seenPaths.add(a.path))
      .map(a => ({ path: a.path, source: a.source, baseline: null, defaultLocale: null }))

    if (styles.length === 0) {
      if (this.verbose) console.log('No styles changed')
      return ''
    }
    if (this.verbose) console.log(`${styles.length} styles changed`)

    for (const style of styles) {
      if (style.source) {
        style.baseline = await this.get(style.source, this.event.pull_request.base.sha)
      }
    }

    styles.sort((a, b) => {
      const da = path.dirname(a.path)
      const db = path.dirname(b.path)
      if (da.length === db.length) return a.path.localeCompare(b.path)
      return da.length - db.length
    })

    const max = parseInt(process.env.SHELDON_CHANGED_SHOW_MAX || '10', 10)
    let comments = styles.length > max ? `${styles.length} styles changed, showing ${max}\n\n` : ''

    const items = JSON.parse(fs.readFileSync('spec/sheldon/items.json', 'utf-8'))

    const root = process.env.GITHUB_WORKSPACE
    const pullRequestDir = path.join(root, 'pull-request')
    const styleRoot = fs.existsSync(pullRequestDir) ? pullRequestDir : root

    for (let i = 0; i < styles.length; i++) {
      const style = styles[i]
      const styleFilePath = path.join(styleRoot, style.path)
      style.defaultLocale = this.defaultLocale(styleFilePath)

      let rendered = null
      try {
        rendered = this.renderCitations(items, fs.readFileSync(styleFilePath, 'utf-8'), style.defaultLocale)
      }
      catch (e) {
        if (this.verbose) console.log(e)
      }

      if (rendered && i >= max) continue

      let baselineRendered = null
      if (style.baseline) {
        try {
          baselineRendered = this.renderCitations(items, style.baseline, this.defaultLocale(style.baseline))
        }
        catch (e) {
          if (this.verbose) console.log(e)
        }
      }

      comments += '<details>'

      let status
      if (!rendered) {
        status = 'rendering failure'
      }
      else if (baselineRendered && rendered === baselineRendered) {
        status = 'modified style; unchanged output for sample items'
      }
      else if (baselineRendered) {
        status = 'modified style'
      }
      else {
        status = 'new'
      }

      comments += `<summary>${style.path} (${status})</summary>\n`
      if (rendered) comments += `<blockquote>${rendered}</blockquote>\n`

      if (baselineRendered && rendered && baselineRendered !== rendered) {
        comments += '\n```diff\n'
        comments += createPatch(style.path, baselineRendered, rendered)
        comments += '\n```\n'
      }

      comments += '</details>'
    }

    // Run csl-formatter on changed styles in the pull-request checkout
    if (fs.existsSync(pullRequestDir)) {
      const tmpDir = mkdtempSync(path.join(tmpdir(), 'sheldon-'))
      try {
        fs.copyFileSync(path.join(__dirname, 'package.json'), path.join(tmpDir, 'package.json'))
        execSync('npm install', { cwd: tmpDir, stdio: 'inherit' })

        const formatter = path.join(tmpDir, 'node_modules', '.bin', 'style-formatter')
        for (const style of styles) {
          const stylePath = path.join(pullRequestDir, style.path)
          execSync(`${formatter} ${stylePath} ${stylePath}`)
        }

        if (this.verbose) {
          execSync('pwd', { cwd: pullRequestDir, stdio: 'inherit' })
          execSync('git status', { cwd: pullRequestDir, stdio: 'inherit' })
          execSync('git diff', { cwd: pullRequestDir, stdio: 'inherit' })
        }
      }
      finally {
        fs.rmSync(tmpDir, { recursive: true, force: true })
      }
    }

    if (this.verbose) console.log(comments)
    return comments
  }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

async function main() {
  await GitHubAction.create()
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch(err => {
    console.error(err)
    process.exit(1)
  })
}
