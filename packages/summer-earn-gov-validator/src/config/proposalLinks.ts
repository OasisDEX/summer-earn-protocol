// Governance resource links surfaced on proposal pages.
//
// TODO(team): confirm the real URLs before the public-subdomain deploy. The forum
// links below are placeholders — point `forumUrl` at the governance forum home and
// `forumTemplateUrl` at the pinned "proposal template / how to write a proposal"
// thread. Snapshot/Tally links are off until a space/org is filled in.

export interface GovResourceLink {
  label: string
  href: string
  icon: string // Material Symbols name
}

const GOV_LINKS = {
  // Lazy Summer DAO governance forum (home / governance category).
  forumUrl: 'https://forum.summer.fi',
  // Pinned "proposal template / how to write a proposal" thread.
  forumTemplateUrl: 'https://forum.summer.fi',
  // Optional off-chain governance links. Leave undefined to hide.
  // tallyOrg  → https://www.tally.xyz/gov/<org>
  tallyOrg: undefined as string | undefined,
  // snapshotSpace → https://snapshot.org/#/<space>
  snapshotSpace: undefined as string | undefined,
}

// The links shown on every proposal page. Optional ones (Tally/Snapshot) only
// appear once configured above.
export function getProposalResourceLinks(): GovResourceLink[] {
  const links: GovResourceLink[] = [
    { label: 'Forum', href: GOV_LINKS.forumUrl, icon: 'forum' },
    { label: 'Proposal template', href: GOV_LINKS.forumTemplateUrl, icon: 'description' },
  ]

  if (GOV_LINKS.tallyOrg) {
    links.push({
      label: 'Tally',
      href: `https://www.tally.xyz/gov/${GOV_LINKS.tallyOrg}`,
      icon: 'how_to_vote',
    })
  }
  if (GOV_LINKS.snapshotSpace) {
    links.push({
      label: 'Snapshot',
      href: `https://snapshot.org/#/${GOV_LINKS.snapshotSpace}`,
      icon: 'bolt',
    })
  }

  return links
}
