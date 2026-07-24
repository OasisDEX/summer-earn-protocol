// Governance resource links surfaced on proposal pages, mirroring the welcome
// banner on forum.summer.fi.

export interface GovResourceLink {
  label: string
  href: string
  icon: string // Material Symbols name
}

const FORUM_LINKS: GovResourceLink[] = [
  { label: 'Forum', href: 'https://forum.summer.fi', icon: 'forum' },
  {
    label: 'Governance Guidelines',
    href: 'https://forum.summer.fi/t/lazy-summer-dao-governance-guidelines/258',
    icon: 'gavel',
  },
  {
    label: 'RFC Template',
    href: 'https://forum.summer.fi/t/rfc-template-request-for-comment/260',
    icon: 'rate_review',
  },
  {
    label: 'SIP Template',
    href: 'https://forum.summer.fi/t/sip-template-summer-improvement-proposal/261',
    icon: 'description',
  },
  {
    label: 'EXP Template',
    href: 'https://forum.summer.fi/t/exp-template-expedited-governance-proposal/718',
    icon: 'bolt',
  },
  {
    label: 'SIP Numbering & Overview',
    href: 'https://sheets.fileverse.io/0x7db0bA8aAAA07929cC74Eb28dFd6085272bdC4A5/3#key=5INhN4nX5EtcGu0kVZZOetMvDOcZaKceWbam6fYp0WKcW22pXvUmaMo8QcA-cKH6',
    icon: 'format_list_numbered',
  },
]

// Optional off-chain governance links. Leave undefined to hide.
const GOV_LINKS = {
  // tallyOrg  → https://www.tally.xyz/gov/<org>
  tallyOrg: undefined as string | undefined,
  // snapshotSpace → https://snapshot.org/#/<space>
  snapshotSpace: undefined as string | undefined,
}

// The links shown on every proposal page. Optional ones (Tally/Snapshot) only
// appear once configured above.
export function getProposalResourceLinks(): GovResourceLink[] {
  const links: GovResourceLink[] = [...FORUM_LINKS]

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
      icon: 'ac_unit',
    })
  }

  return links
}
