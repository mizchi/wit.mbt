"""Compare WIT interfaces, worlds, metadata, and invalid-input behavior."""
import argparse
import difflib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = (ROOT / "testdata/current.wit", ROOT / "testdata/file-scope", ROOT / "testdata/transitive.wit")


def run(command, *, success=True):
    result = subprocess.run([str(arg) for arg in command], cwd=ROOT, capture_output=True, text=True, timeout=60)
    if success and result.returncode:
        raise RuntimeError(f"{' '.join(map(str, command))}\n{result.stdout}{result.stderr}")
    return result


def semantics(resolve):
    def package_name(package):
        return resolve["packages"][package]["name"] if package is not None else ""

    def world_name(index):
        world = resolve["worlds"][index]
        return package_name(world.get("package")) + "/" + world["name"]

    anonymous = {}
    for world_id, world in enumerate(resolve["worlds"]):
        for direction in ("imports", "exports"):
            for name, item in world[direction].items():
                if "interface" in item:
                    index = item["interface"]["id"]
                    if resolve["interfaces"][index]["name"] is None:
                        anonymous[index] = world_name(world_id) + "/" + direction + "/" + name

    def interface_name(index):
        interface = resolve["interfaces"][index]
        if interface["name"] is None:
            return anonymous[index]
        return package_name(interface.get("package")) + "/" + interface["name"]

    def metadata(item):
        return {
            "docs": item.get("docs", {}).get("contents"),
            "stability": item.get("stability"),
            "external-id": item.get("external-id", item.get("external_id")),
        }

    def type_ref(value):
        if isinstance(value, int):
            definition = resolve["types"][value]
            if definition["kind"] == "resource":
                owner = definition["owner"]
                if "interface" in owner:
                    scope = interface_name(owner["interface"])
                elif "world" in owner:
                    scope = world_name(owner["world"])
                else:
                    raise AssertionError("resource has no owner")
                return {"resource": scope + "/" + definition["name"]}
            return type_kind(definition["kind"])
        return value

    def type_kind(kind):
        if not isinstance(kind, dict):
            return kind
        if "type" in kind:
            return type_ref(kind["type"])
        if "fixed-length-list" in kind:
            element, size = kind["fixed-length-list"]
            return {"fixed-length-list": [type_ref(element), size]}
        if "map" in kind:
            return {"map": [type_ref(value) for value in kind["map"]]}
        if "result" in kind:
            return {"result": {name: type_ref(value) for name, value in kind["result"].items()}}
        if "handle" in kind:
            return {"handle": {name: type_ref(value) for name, value in kind["handle"].items()}}
        if "tuple" in kind:
            return {"tuple": [type_ref(value) for value in kind["tuple"]["types"]]}
        if "record" in kind:
            return {"record": [{**metadata(field), "name": field["name"], "type": type_ref(field["type"])} for field in kind["record"]["fields"]]}
        if "variant" in kind:
            return {"variant": [{**metadata(case), "name": case["name"], "type": type_ref(case.get("type"))} for case in kind["variant"]["cases"]]}
        if "flags" in kind or "enum" in kind:
            return kind
        return {name: type_ref(value) for name, value in kind.items()}

    def function(func):
        kind = func["kind"]
        if isinstance(kind, dict):
            kind = {name: type_ref(value) for name, value in kind.items()}
        return {
            **metadata(func), "kind": kind, "name": func["name"],
            "params": [{"name": param["name"], "type": type_ref(param["type"])} for param in func["params"]],
            "result": type_ref(func.get("result")),
        }

    def world_items(items):
        normalized = {}
        for name, item in items.items():
            if "interface" in item:
                value = item["interface"]
                if name == "interface-" + str(value["id"]):
                    name = "[interface]" + interface_name(value["id"])
                normalized[name] = {**metadata(value), "interface": interface_name(value["id"])}
            elif "function" in item:
                normalized[name] = {"function": function(item["function"])}
            else:
                normalized[name] = {"type": type_ref(item["type"])}
        return normalized

    return {
        "interfaces": {
            interface_name(index): {
                **metadata(interface),
                "types": {name: {"kind": type_ref(value), **metadata(resolve["types"][value])} for name, value in interface["types"].items()},
                "functions": {name: function(func) for name, func in interface["functions"].items()},
            }
            for index, interface in enumerate(resolve["interfaces"])
        },
        "worlds": {
            world_name(index): {**metadata(world), "imports": world_items(world["imports"]), "exports": world_items(world["exports"])}
            for index, world in enumerate(resolve["worlds"])
        },
    }


def compare(actual, expected, label):
    actual, expected = semantics(actual), semantics(expected)
    if actual != expected:
        diff = difflib.unified_diff(json.dumps(expected, ensure_ascii=False, indent=2, sort_keys=True).splitlines(), json.dumps(actual, ensure_ascii=False, indent=2, sort_keys=True).splitlines(), fromfile="upstream", tofile="wit.mbt", lineterm="")
        raise AssertionError(label + "\n" + "\n".join(diff))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", help="Path to the pinned wit-spec-probe; otherwise use installed wasm-tools for shared fixtures")
    args = parser.parse_args()

    def reference(path):
        return [args.reference, path] if args.reference else ["wasm-tools", "component", "wit", path, "--json", "--all-features"]

    run(["python3", "scripts/generate-conformance-tests.py", "--check"])
    run(["moon", "build", "src/main", "--target", "js"])
    run(["moon", "build", "src/main", "--target", "native"])
    commands = {"js": ["node", ROOT / "_build/js/debug/build/main/main.js"], "native": [ROOT / "_build/native/debug/build/main/main.exe"]}
    fixtures = FIXTURES + ((ROOT / "testdata/gates.wit",) if args.reference else ())
    for fixture in fixtures:
        expected = json.loads(run(reference(fixture)).stdout)
        for target, command in commands.items():
            actual = json.loads(run(command + ["--all-features", fixture]).stdout)["resolve"]
            compare(actual, expected, f"{target}: {fixture.name}")
            print(f"{target}: {fixture.name}: interfaces, worlds, and metadata match")

    for target, command in commands.items():
        gates = ROOT / "testdata/gates.wit"
        for flags, names in [([], {"run", "old"}), (["--features", "preview", "--target-version", "1.0.0"], {"run", "preview"})]:
            actual = json.loads(run(command + flags + [gates, "app"]).stdout)["resolve"]
            if set(actual["interfaces"][0]["functions"]) != names:
                raise AssertionError(f"{target}: CLI feature/version options did not filter the APIs")
        selected = json.loads(run(command + [gates]).stdout)
        if selected["resolve"]["worlds"][selected["world_id"]]["name"] != "app":
            raise AssertionError(f"{target}: default world selection retained a hidden world")
        if run(command + ["--features"], success=False).returncode == 0:
            raise AssertionError(f"{target}: missing feature argument was accepted")

    corpus = json.loads((ROOT / "testdata/conformance.json").read_text())
    with tempfile.TemporaryDirectory(prefix="wit-spec-check-") as directory:
        for case in corpus["cases"]:
            path = Path(directory) / (case["name"] + ".wit")
            path.write_text(case["source"])
            expected = None
            if args.reference:
                oracle = run(reference(path), success=False)
                if (oracle.returncode == 0) != case["accepted"]:
                    raise AssertionError("pinned oracle disagrees with corpus: " + case["name"])
                if case["accepted"]:
                    expected = json.loads(oracle.stdout)
            for target, command in commands.items():
                actual = run(command + ["--all-features", path], success=False)
                if (actual.returncode == 0) != case["accepted"]:
                    raise AssertionError(f"{target}: acceptance differs for {case['name']}: {actual.stdout}{actual.stderr}")
                if expected is not None:
                    compare(json.loads(actual.stdout)["resolve"], expected, f"{target}: {case['name']}")
        print(f"{len(corpus['cases'])} conformance cases passed on JS and native; oracle revision {corpus['upstream_revision']}")


if __name__ == "__main__":
    main()
