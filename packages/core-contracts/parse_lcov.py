import os

target_files = [
    "src/contracts/AdmiralsQuartersWhitelist.sol",
    "src/contracts/FleetCommanderConfigProviderWhitelist.sol",
    "src/contracts/FleetCommanderDao.sol",
    "src/contracts/FleetCommanderWhitelist.sol",
    "src/contracts/periphery/RoundsVaultExchanger.sol"
]

current_file = None
uncovered_lines = {}
uncovered_functions = {}

with open("lcov.info", "r") as f:
    for line in f:
        line = line.strip()
        if line.startswith("SF:"):
            fname = line.split("SF:")[1]
            if any(fname.endswith(target) for target in target_files):
                current_file = [t for t in target_files if fname.endswith(t)][0]
                uncovered_lines[current_file] = []
                uncovered_functions[current_file] = []
            else:
                current_file = None
        elif current_file:
            if line.startswith("DA:"):
                parts = line.split("DA:")[1].split(",")
                line_num = int(parts[0])
                hits = int(parts[1])
                if hits == 0:
                    uncovered_lines[current_file].append(line_num)
            elif line.startswith("FNDA:"):
                parts = line.split("FNDA:")[1].split(",")
                hits = int(parts[0])
                func_name = parts[1]
                if hits == 0:
                    uncovered_functions[current_file].append(func_name)

for file in target_files:
    print(f"File: {file}")
    funcs = uncovered_functions.get(file, [])
    print(f"Uncovered Functions ({len(funcs)}): {funcs}")
    lines = uncovered_lines.get(file, [])
    
    # summarize lines
    if not lines:
        print("Uncovered Lines: None")
    else:
        ranges = []
        start = lines[0]
        prev = lines[0]
        for l in lines[1:]:
            if l == prev + 1:
                prev = l
            else:
                ranges.append(f"{start}-{prev}" if start != prev else str(start))
                start = l
                prev = l
        ranges.append(f"{start}-{prev}" if start != prev else str(start))
        print(f"Uncovered Lines: {', '.join(ranges)}")
    print("-" * 40)
