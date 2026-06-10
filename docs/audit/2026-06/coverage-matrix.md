# NatSpec coverage matrix — summer-earn-protocol

Coverage = items with @notice (functions/events/errors/contract-level)
plus doc-commented internal items, over the documentable surface of the
package source dir (tests, scripts, mocks and inherited external-library
members excluded). `full` additionally requires complete @param/@return.

| Package | Contracts | Pub/ext fns (notice / full) | State vars | Events | Errors | Internal items | Coverage | Verdict |
|---|---|---|---|---|---|---|---|---|
| rewards-contracts | 4/6 | 36/79 (36 full) | 1/4 | 1/11 | 2/25 | 7/19 | 35.4% | sparse |
| intent-system | 7/9 | 45/59 (45 full) | 5/20 | 0/15 | 0/30 | 5/9 | 43.7% | sparse |
| rwa-oracles | 5/12 | 23/36 (23 full) | 18/21 | 0/8 | 0/12 | 3/3 | 53.3% | sparse |
| gov-contracts | 20/34 | 188/322 (162 full) | 5/41 | 24/24 | 54/64 | 85/89 | 65.5% | partial |
| voting-decay | 0/2 | 0/0 (0 full) | 1/1 | 0/6 | 1/3 | 25/26 | 71.1% | partial |
| core-contracts | 153/253 | 2405/3139 (2226 full) | 122/159 | 188/209 | 254/366 | 551/738 | 75.5% | partial |
| dutch-auction | 6/7 | 4/5 (4 full) | 0/2 | 4/4 | 12/12 | 17/17 | 91.5% | partial |
| chain-bridge | 25/26 | 162/173 (147 full) | 19/21 | 44/44 | 66/66 | 63/83 | 91.8% | partial |
| access-contracts | 7/8 | 139/144 (133 full) | 4/4 | 3/3 | 21/21 | 15/25 | 92.2% | thorough |
| config-contracts | 7/7 | 45/45 (45 full) | 0/1 | 6/6 | 7/8 | 1/1 | 97.1% | thorough |
| deployment | 0/0 | 0/0 (0 full) | 0/0 | 0/0 | 0/0 | 0/0 | 100.0% | empty |
| math-utils | 1/1 | 0/0 (0 full) | 0/0 | 0/0 | 0/0 | 2/2 | 100.0% | thorough |
| percentage | 2/2 | 0/0 (0 full) | 0/0 | 0/0 | 0/0 | 35/35 | 100.0% | thorough |
| price-utils | 1/1 | 0/0 (0 full) | 0/0 | 0/0 | 0/0 | 7/7 | 100.0% | thorough |
