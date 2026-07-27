# NatSpec coverage matrix — summer-earn-protocol

Coverage = items with @notice (functions/events/errors/contract-level)
plus doc-commented internal items, over the documentable surface of the
package source dir (tests, scripts, mocks and inherited external-library
members excluded). `full` additionally requires complete @param/@return.

| Package | Contracts | Pub/ext fns (notice / full) | State vars | Events | Errors | Internal items | Coverage | Verdict |
|---|---|---|---|---|---|---|---|---|
| gov-contracts | 34/34 | 271/322 (257 full) | 41/41 | 24/24 | 64/64 | 89/89 | 91.1% | partial |
| rwa-oracles | 12/12 | 35/36 (35 full) | 19/21 | 5/8 | 12/12 | 3/3 | 93.5% | thorough |
| core-contracts | 247/253 | 2887/3139 (2880 full) | 158/159 | 207/209 | 366/366 | 737/738 | 94.6% | thorough |
| dutch-auction | 7/7 | 4/5 (4 full) | 2/2 | 4/4 | 12/12 | 17/17 | 97.9% | partial |
| access-contracts | 7/8 | 142/144 (136 full) | 4/4 | 3/3 | 21/21 | 24/25 | 98.0% | thorough |
| chain-bridge | 26/26 | 173/173 (173 full) | 21/21 | 44/44 | 66/66 | 83/83 | 100.0% | thorough |
| config-contracts | 7/7 | 45/45 (45 full) | 1/1 | 6/6 | 8/8 | 1/1 | 100.0% | thorough |
| deployment | 0/0 | 0/0 (0 full) | 0/0 | 0/0 | 0/0 | 0/0 | 100.0% | empty |
| intent-system | 9/9 | 59/59 (59 full) | 20/20 | 15/15 | 30/30 | 9/9 | 100.0% | thorough |
| math-utils | 1/1 | 0/0 (0 full) | 0/0 | 0/0 | 0/0 | 2/2 | 100.0% | thorough |
| percentage | 2/2 | 0/0 (0 full) | 0/0 | 0/0 | 0/0 | 35/35 | 100.0% | thorough |
| price-utils | 1/1 | 0/0 (0 full) | 0/0 | 0/0 | 0/0 | 7/7 | 100.0% | thorough |
| rewards-contracts | 6/6 | 79/79 (79 full) | 4/4 | 11/11 | 25/25 | 19/19 | 100.0% | thorough |
| voting-decay | 2/2 | 0/0 (0 full) | 1/1 | 6/6 | 3/3 | 26/26 | 100.0% | thorough |
