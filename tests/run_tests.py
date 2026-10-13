#!/usr/bin/env python3
"""Runs tests/*.spec.luau against the pure shared modules using the standalone
`luau` CLI. Roblox-only globals (Color3, script.Parent) are shimmed so the
economy math can be verified without Roblox Studio.

Usage:  python3 tests/run_tests.py [path/to/luau]
"""
import glob, os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
MODULES = ["Config", "CloudlingData", "Formulas", "Products", "QuestData"]

SHIM = """
Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
           new = function(r, g, b) return { R = r, G = g, B = b } end }
local __mods, __cache = {}, {}
local function __req(name)
  if __cache[name] == nil then __cache[name] = __mods[name]() end
  return __cache[name]
end
"""

def bundle(spec_path):
    parts = [SHIM]
    for m in MODULES:
        src = open(os.path.join(ROOT, "src/shared", m + ".luau")).read()
        src = re.sub(r"require\(script\.Parent\.(\w+)\)", r'__req("\1")', src).replace("--!nonstrict", "")
        parts.append(f"__mods[{m!r}] = function()\n{src}\nend\n")
    parts.append("local Config, CloudlingData, Formulas, Products, QuestData = __req('Config'), __req('CloudlingData'), __req('Formulas'), __req('Products'), __req('QuestData')\n")
    parts.append(open(spec_path).read())
    return "\n".join(parts)

failed = 0
for spec in sorted(glob.glob(os.path.join(ROOT, "tests", "*.spec.luau"))):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(bundle(spec))
    r = subprocess.run([LUAU, f.name], capture_output=True, text=True)
    print(r.stdout, end="")
    if r.returncode != 0:
        failed += 1
        print(r.stderr)
    os.unlink(f.name)
sys.exit(1 if failed else 0)
