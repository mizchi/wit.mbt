"""Compare supported WIT type semantics and function JSON with wasm-tools."""

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent
FIXTURES = (ROOT / "testdata/current.wit", ROOT / "testdata/file-scope")


def run(*command):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"{' '.join(command)}\n{result.stdout}{result.stderr}")
    return result.stdout


def interface_semantics(resolve):
    # wit.mbt retains alias nodes; wasm-tools can inline the named type's kind.
    # Compare meaning rather than the allocation order of type IDs.
    def type_ref(value):
        if isinstance(value, int):
            definition = resolve["types"][value]
            if definition["kind"] == "resource":
                return {"resource": definition["name"]}
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
        return {name: type_ref(value) for name, value in kind.items()}

    def function(func):
        kind = func["kind"]
        if isinstance(kind, dict):
            kind = {name: type_ref(value) for name, value in kind.items()}
        return {
            **func,
            "kind": kind,
            "params": [{**param, "type": type_ref(param["type"])} for param in func["params"]],
            "result": type_ref(func.get("result")),
        }

    return {
        interface["name"]: {
            "types": {name: type_ref(value) for name, value in interface["types"].items()},
            "functions": {name: function(func) for name, func in interface["functions"].items()},
        }
        for interface in resolve["interfaces"]
    }


for fixture in FIXTURES:
    expected = interface_semantics(json.loads(run("wasm-tools", "component", "wit", str(fixture), "--json", "--all-features")))
    for target in ("js", "native"):
        actual = json.loads(run("moon", "run", "src/main", "--target", target, "--", str(fixture)))["resolve"]
        if interface_semantics(actual) != expected:
            raise AssertionError(f"{target}: {fixture.name}: WIT semantics differ from wasm-tools")
        print(f"{target}: {fixture.name}: type semantics and function JSON match wasm-tools")
print(run("wasm-tools", "--version").strip())
