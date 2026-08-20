#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import subprocess
import tempfile
import tomllib
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping


PYTHON_ALIASES = ("python", "python3")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--component", action="append", required=True)
    parser.add_argument("--wheels", type=Path, required=True)
    parser.add_argument("--python-version", required=True)
    parser.add_argument("--python-import", action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--wasmer", required=True)
    return parser.parse_args()


def parse_components(values: Iterable[str]) -> dict[str, Path]:
    components: dict[str, Path] = {}
    for value in values:
        name, separator, raw_path = value.partition("=")
        if not separator or not name or not raw_path:
            raise ValueError(f"invalid component: {value!r}")
        if name in components:
            raise ValueError(f"duplicate component: {name}")
        components[name] = Path(raw_path)
    return components


def single_webc(path: Path) -> Path:
    webcs = sorted(path.rglob("*.webc"))
    if len(webcs) != 1:
        raise ValueError(f"expected one WebC under {path}, found {len(webcs)}")
    return webcs[0]


def unpack(wasmer: str, webc: Path, destination: Path) -> None:
    subprocess.run(
        [
            wasmer,
            "package",
            "unpack",
            "--quiet",
            "--format",
            "package",
            "--out-dir",
            str(destination),
            str(webc),
        ],
        check=True,
    )


def safe_source(root: Path, value: str) -> Path:
    relative = PurePosixPath(value)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError(f"path escapes package: {value}")
    source = (root / relative).resolve(strict=True)
    if not source.is_relative_to(root.resolve()):
        raise ValueError(f"path escapes package: {value}")
    return source


def same_file(left: Path, right: Path) -> bool:
    if left.stat().st_size != right.stat().st_size:
        return False
    with left.open("rb") as left_file, right.open("rb") as right_file:
        while True:
            left_chunk = left_file.read(1024 * 1024)
            right_chunk = right_file.read(1024 * 1024)
            if left_chunk != right_chunk:
                return False
            if not left_chunk:
                return True


def merge_entry(source: Path, destination: Path) -> None:
    if not destination.exists() and not destination.is_symlink():
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.is_symlink():
            destination.symlink_to(os.readlink(source))
        elif source.is_dir():
            shutil.copytree(source, destination, symlinks=True)
        else:
            shutil.copy2(source, destination)
        return

    if source.is_symlink() or destination.is_symlink():
        if not source.is_symlink() or not destination.is_symlink():
            raise ValueError(f"filesystem collision: {destination}")
        if os.readlink(source) != os.readlink(destination):
            raise ValueError(f"symlink collision: {destination}")
        return

    if source.is_dir() and destination.is_dir():
        for child in source.iterdir():
            merge_entry(child, destination / child.name)
        return

    if source.is_file() and destination.is_file() and same_file(source, destination):
        return
    raise ValueError(f"filesystem collision: {destination}")


def merge_tree(source: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for child in source.iterdir():
        merge_entry(child, destination / child.name)


def toml_value(value: Any) -> str:
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return "[" + ", ".join(toml_value(item) for item in value) + "]"
    raise TypeError(f"unsupported TOML value: {value!r}")


def emit_table(lines: list[str], name: str, values: Mapping[str, Any]) -> None:
    scalars = {
        key: value
        for key, value in values.items()
        if not isinstance(value, dict)
    }
    nested = {key: value for key, value in values.items() if isinstance(value, dict)}
    if scalars:
        lines.append(f"[{name}]")
        lines.extend(f"{key} = {toml_value(value)}" for key, value in scalars.items())
        lines.append("")
    for key, value in nested.items():
        emit_table(lines, f"{name}.{key}", value)


def render_manifest(
    modules: Iterable[Mapping[str, Any]],
    commands: Iterable[Mapping[str, Any]],
    filesystems: Mapping[str, str],
    licenses: Iterable[str],
) -> str:
    lines = [
        "[package]",
        'name = "local/sandbox"',
        'version = "0.0.0"',
        f"license = {toml_value(' AND '.join(sorted(set(licenses))))}",
        'entrypoint = "bash"',
        "",
    ]
    if filesystems:
        lines.append("[fs]")
        lines.extend(
            f"{toml_value(guest)} = {toml_value(source)}"
            for guest, source in sorted(filesystems.items())
        )
        lines.append("")
    for module in modules:
        lines.append("[[module]]")
        lines.extend(f"{key} = {toml_value(value)}" for key, value in module.items())
        lines.append("")
    for command in commands:
        annotations = command.get("annotations", {})
        lines.append("[[command]]")
        lines.extend(
            f"{key} = {toml_value(value)}"
            for key, value in command.items()
            if key != "annotations"
        )
        lines.append("")
        if annotations:
            emit_table(lines, "command.annotations", annotations)
    return "\n".join(lines)


def wheel_destination(
    name: PurePosixPath,
    prefix: Path,
    site_packages: Path,
    python_version: str,
) -> Path | None:
    if name.is_absolute() or ".." in name.parts:
        raise ValueError(f"wheel path escapes installation root: {name}")
    if not name.parts:
        return None
    if name.parts[0].endswith(".data"):
        if len(name.parts) < 3:
            return None
        scheme = name.parts[1]
        relative = Path(*name.parts[2:])
        destinations = {
            "purelib": site_packages,
            "platlib": site_packages,
            "scripts": prefix / "bin",
            "data": prefix,
            "headers": prefix / "include" / f"python{python_version}",
        }
        if scheme not in destinations:
            raise ValueError(f"unknown wheel installation scheme: {scheme}")
        return destinations[scheme] / relative
    return site_packages / Path(*name.parts)


def write_wheel_entry(
    archive: zipfile.ZipFile, member: zipfile.ZipInfo, destination: Path
) -> None:
    mode = member.external_attr >> 16
    if stat.S_ISLNK(mode):
        raise ValueError(f"wheel contains symlink: {member.filename}")
    if member.is_dir():
        destination.mkdir(parents=True, exist_ok=True)
        return
    data = archive.read(member)
    if destination.exists():
        if destination.is_file() and destination.read_bytes() == data:
            return
        raise ValueError(f"wheel file collision: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    os.chmod(destination, stat.S_IMODE(mode) or 0o644)


def install_wheels(wheels: Path, prefix: Path, python_version: str) -> None:
    site_packages = prefix / "lib" / f"python{python_version}" / "site-packages"
    site_packages.mkdir(parents=True, exist_ok=True)
    wheel_paths = sorted(wheels.glob("*.whl"))
    if not wheel_paths:
        raise ValueError(f"no wheels found under {wheels}")
    for wheel in wheel_paths:
        with zipfile.ZipFile(wheel) as archive:
            for member in archive.infolist():
                destination = wheel_destination(
                    PurePosixPath(member.filename),
                    prefix,
                    site_packages,
                    python_version,
                )
                if destination is not None:
                    write_wheel_entry(archive, member, destination)


def assemble(
    wasmer: str,
    components: Mapping[str, Path],
    wheels: Path,
    python_version: str,
    package_root: Path,
) -> None:
    modules: dict[str, dict[str, Any]] = {}
    commands: dict[str, dict[str, Any]] = {}
    filesystems: dict[str, str] = {}
    filesystem_roots: dict[str, Path] = {}
    licenses: set[str] = set()

    for component, path in sorted(components.items()):
        unpacked = package_root.parent / "unpacked" / component
        unpacked.mkdir(parents=True)
        unpack(wasmer, single_webc(path), unpacked)
        manifest = tomllib.loads((unpacked / "wasmer.toml").read_text(encoding="utf-8"))
        license_name = manifest.get("package", {}).get("license")
        if license_name:
            licenses.add(str(license_name))

        for module_value in manifest.get("module", []):
            module = dict(module_value)
            name = str(module["name"])
            if name in modules:
                raise ValueError(f"duplicate module {name!r} from {component}")
            source = safe_source(unpacked, str(module["source"]))
            destination = package_root / "modules" / name
            merge_entry(source, destination)
            module["source"] = f"./modules/{name}"
            modules[name] = module

        for guest, source_value in manifest.get("fs", {}).items():
            guest_path = str(guest)
            source = safe_source(unpacked, str(source_value))
            if guest_path not in filesystem_roots:
                destination = package_root / "fs" / f"mount-{len(filesystem_roots):02d}"
                filesystem_roots[guest_path] = destination
                filesystems[guest_path] = f"./{destination.relative_to(package_root)}"
            merge_tree(source, filesystem_roots[guest_path])

        for command_value in manifest.get("command", []):
            command = dict(command_value)
            name = str(command["name"])
            if name in commands:
                raise ValueError(f"duplicate command {name!r} from {component}")
            commands[name] = command

    missing_modules = {
        str(command["module"])
        for command in commands.values()
        if str(command["module"]) not in modules
    }
    if missing_modules:
        rendered = ", ".join(sorted(missing_modules))
        raise ValueError(f"commands reference missing modules: {rendered}")
    if "/usr/local" not in filesystem_roots:
        raise ValueError("Python component does not mount /usr/local")

    versioned_python = f"python{python_version}"
    if versioned_python not in commands:
        raise ValueError(f"missing Python command: {versioned_python}")
    for alias in PYTHON_ALIASES:
        if alias in commands:
            raise ValueError(f"Python alias already exists: {alias}")
        commands[alias] = {**commands[versioned_python], "name": alias}

    install_wheels(wheels, filesystem_roots["/usr/local"], python_version)
    package_root.mkdir(parents=True, exist_ok=True)
    manifest_text = render_manifest(
        modules.values(), commands.values(), filesystems, licenses
    )
    parsed_manifest = tomllib.loads(manifest_text)
    if parsed_manifest.get("dependencies"):
        raise ValueError("sandbox manifest contains dependencies")
    (package_root / "wasmer.toml").write_text(manifest_text, encoding="utf-8")


def verify(
    wasmer: str,
    webc: Path,
    destination: Path,
    python_version: str,
    python_imports: Iterable[str],
) -> None:
    destination.mkdir()
    unpack(wasmer, webc, destination)
    manifest = tomllib.loads((destination / "wasmer.toml").read_text(encoding="utf-8"))
    if manifest.get("dependencies"):
        raise ValueError("built sandbox contains dependencies")
    command_names = {command["name"] for command in manifest.get("command", [])}
    missing_aliases = set(PYTHON_ALIASES) - command_names
    if missing_aliases:
        rendered = ", ".join(sorted(missing_aliases))
        raise ValueError(f"built sandbox misses commands: {rendered}")
    usr_local = safe_source(destination, manifest["fs"]["/usr/local"])
    site_packages = usr_local / "lib" / f"python{python_version}" / "site-packages"
    if not any(path.name.endswith(".dist-info") for path in site_packages.iterdir()):
        raise ValueError("built sandbox contains no installed wheels")

    home = destination.parent / "home"
    home.mkdir()
    environment = os.environ | {
        "HOME": str(home),
        "WASMER_CACHE_DIR": str(home / "cache"),
        "WASMER_DIR": str(home / "wasmer"),
    }
    environment.pop("PYTHONHOME", None)
    import_statement = f"import {', '.join(python_imports)}; print('imports-ok')"
    checks = [
        (
            "python",
            ["-c", import_statement],
            "imports-ok\n",
        ),
        (
            "bash",
            [
                "-c",
                "printf '%s\\n' '{\"ok\":true}' | jq -M -r .ok | grep true",
            ],
            "true\n",
        ),
        (
            "bash",
            [
                "-c",
                "python -c \"import sys; assert sys.prefix == '/usr/local'; "
                "print('python-shell-ok')\"",
            ],
            "python-shell-ok\n",
        ),
    ]
    for entrypoint, arguments, expected in checks:
        process = subprocess.run(
            [
                wasmer,
                "run",
                "--quiet",
                str(webc),
                "--entrypoint",
                entrypoint,
                "--",
                *arguments,
            ],
            capture_output=True,
            text=True,
            env=environment,
        )
        if process.returncode != 0 or process.stdout != expected:
            raise ValueError(
                f"{entrypoint} check failed with exit {process.returncode}, "
                f"stdout {process.stdout!r}, stderr {process.stderr!r}, "
                f"expected stdout {expected!r}"
            )


def main() -> int:
    args = parse_args()
    components = parse_components(args.component)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="sandbox-webc-") as temp_dir:
        root = Path(temp_dir)
        package_root = root / "package"
        assemble(
            args.wasmer,
            components,
            args.wheels,
            args.python_version,
            package_root,
        )
        subprocess.run(
            [
                args.wasmer,
                "package",
                "build",
                "--quiet",
                "--out",
                str(args.output),
                str(package_root / "wasmer.toml"),
            ],
            check=True,
        )
        verify(
            args.wasmer,
            args.output,
            root / "verified",
            args.python_version,
            args.python_import,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
