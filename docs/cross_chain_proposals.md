Hub fleet model on L2 with direct isolated access to markets on satellite chains (CrossChainArkProxy → DeFi protocol) #NewFleet
Proposal A

We create a standalone hub fleet on Base that operates as hub (similar to Governance). Capital is deployed on Base as well as connected satellite chains. Feeder chains send deposits to Base where it’s distributed out. Each chain therefore has:
An entry point
Funds are fed to the Hub controller on Base
The Hub controller on Base then distributes funds capital to DeFi protocols from there
Funds are not mixed with existing fleets with new ArkProxy contracts being deployed on satellite chains to directly control & own positions
Hub fleet model on L2 which takes positions in origin and satellite chain fleets #NewFleet
Proposal B

Similar to Proposal A except the the ArkProxy contracts take positions in existing fleets

Fleet to Fleet model where each fleet takes a position in each other fleet #ExistingFleetAddOn
Proposal C

Existing fleets are “upgraded’ with one CrossChainArk for each satellite chain fleet. Rebalances take place between to attempt to normalise fleet yields for each instance. IE If Mainnet USDC fleet is returning 8% and Base USDC fleet is returning 10%. Then the Mainnet fleet will continue to in-flow funds until the yields are equal.

Chain specific cross-chain fleets that take positions in neighbouring chains #NewFleet
Proposal D

Similar to Proposal C except rather than just adding a CrossChainArk to existing fleets we create new cross-chain-only fleets that take positions in existing fleets.

