export const ROLES_FOR_INSTITUTION = /* GraphQL */ `
  query RolesForInstitution($institutionId: ID!) {
    institution(id: $institutionId) {
      id
      roles(first: 1000, where: { active: true }) {
        id
        name
        owner
        targetContract
        accessController
        createdTimestamp
        active
        events(first: 10, orderBy: timestamp, orderDirection: desc) {
          id
          action
          caller
          timestamp
          hash
        }
      }
    }
  }
`

export const WHITELIST_FOR_FLEET = /* GraphQL */ `
  query WhitelistForFleet($fleet: String!) {
    roles(
      first: 1000
      where: { name: "WHITELIST_ROLE", targetContract: $fleet, active: true }
      orderBy: createdTimestamp
      orderDirection: desc
    ) {
      id
      owner
      createdTimestamp
      active
    }
  }
`

export const ROLES_FOR_FLEET = /* GraphQL */ `
  query RolesForFleet($fleet: String!) {
    roles(
      first: 500
      where: { targetContract: $fleet, active: true }
      orderBy: createdTimestamp
      orderDirection: desc
    ) {
      id
      name
      owner
      accessController
      createdTimestamp
      active
    }
  }
`
