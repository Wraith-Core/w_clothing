"""Standalone + coexistence tests for w_clothing."""
import json, unittest
from pathlib import Path
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

def parse_manifest():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("""
    M = { shared = {}, client = {}, server = {} }
    local function add(d, v)
        if type(v) == 'string' then d[#d+1] = v
        elseif type(v) == 'table' then for _, x in ipairs(v) do d[#d+1] = x end end
    end
    for _, k in ipairs({'fx_version','game','games','rdr3_warning','lua54','name','author','description','version','ui_page','w_lib','files','dependencies','escrow_ignore'}) do
        _G[k] = function() end
    end
    function shared_scripts(v) add(M.shared, v) end
    function client_scripts(v) add(M.client, v) end
    function server_scripts(v) add(M.server, v) end
    """)
    lua.execute((ROOT / "fxmanifest.lua").read_text(encoding="utf-8"))
    M = lua.globals().M
    return list(M.shared.values()), list(M.client.values()), list(M.server.values())

class WClothingTest(unittest.TestCase):
    def test_manifest_files_exist(self):
        shared, client, server = parse_manifest()
        for rel in shared + client + server:
            if rel.startswith("@"): continue
            self.assertTrue((ROOT / rel).exists(), f"Missing {rel}")
        self.assertTrue((ROOT / "web/build/index.html").exists())

    def test_locales_valid_json(self):
        ar = json.loads((ROOT / "locales/ar.json").read_text(encoding="utf-8"))
        en = json.loads((ROOT / "locales/en.json").read_text(encoding="utf-8"))
        self.assertEqual(set(ar), set(en))

if __name__ == "__main__":
    unittest.main()
