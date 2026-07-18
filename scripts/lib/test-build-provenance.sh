#!/usr/bin/env bash

# Deterministic provenance helpers for the fixed test DerivedData lane.
#
# This file is intentionally side-effect free when sourced. The caller owns the
# build lifecycle:
#   1. resolve the scheme from the original xcodebuild arguments;
#   2. invalidate the active stamp before build-for-testing;
#   3. hash inputs before and after the build;
#   4. write the stamp only when the build succeeded and both hashes match;
#   5. validate the stamp before every test-without-building invocation.
#
# Exact -only-testing: and -skip-testing: selectors are execution scope, not
# build provenance. Use ohana_test_build_provenance_filter_build_args when
# invoking build-for-testing, while preserving the original arguments for the
# later test-without-building invocation.

OHANA_TEST_BUILD_PROVENANCE_SCHEMA="ohana-test-build-provenance-v1"

_ohana_test_build_provenance_python_bin() {
  printf '%s\n' "${OHANA_TEST_BUILD_PROVENANCE_PYTHON_BIN:-python3}"
}

_ohana_test_build_provenance_require_python() {
  local python_bin
  python_bin="$(_ohana_test_build_provenance_python_bin)"
  if ! command -v "${python_bin}" >/dev/null 2>&1; then
    echo "Test build provenance requires python3; '${python_bin}' was not found." >&2
    return 69
  fi
}

ohana_test_build_provenance_is_selector_arg() {
  case "${1:-}" in
    -only-testing:*|-skip-testing:*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Emits every non-selector argument as a NUL-terminated value. This lets a
# Bash 3.2 caller preserve argument boundaries, spaces, and ordering:
#
#   build_args=()
#   while IFS= read -r -d '' argument; do
#     build_args+=("${argument}")
#   done < <(ohana_test_build_provenance_filter_build_args "$@")
ohana_test_build_provenance_filter_build_args() {
  local argument
  for argument in "$@"; do
    if ! ohana_test_build_provenance_is_selector_arg "${argument}"; then
      printf '%s\0' "${argument}"
    fi
  done
}

# Hashes the ordered, non-selector xcodebuild argument vector. Exact selectors
# may change between shards without invalidating a complete scheme test bundle;
# all other arguments remain part of the conservative build contract.
ohana_test_build_provenance_build_args_sha256() {
  _ohana_test_build_provenance_require_python || return
  local python_bin
  python_bin="$(_ohana_test_build_provenance_python_bin)"
  "${python_bin}" - "$@" <<'PY'
import hashlib
import sys

digest = hashlib.sha256()
digest.update(b"ohana-test-build-args-v1\0")
for argument in sys.argv[1:]:
    if argument.startswith("-only-testing:") or argument.startswith("-skip-testing:"):
        continue
    encoded = argument.encode("utf-8", "surrogateescape")
    digest.update(len(encoded).to_bytes(8, "big"))
    digest.update(encoded)
print(digest.hexdigest())
PY
}

# Hashes the actual bytes visible to Xcode beneath the supplied repo-relative
# files/directories. Unlike a commit or status hash, this includes dirty and
# untracked files in filesystem-synchronised Xcode groups. File mtimes and
# inodes are used only to detect a concurrent mutation; they are not provenance
# inputs, so a touch-only change does not invalidate a build.
#
# Usage:
#   ohana_test_build_provenance_hash_inputs REPO_ROOT PATH [PATH ...]
#
# Missing roots are represented explicitly. Symlinks are hashed by link target
# and are never followed. xcuserdata, .DS_Store, __pycache__, xcuserstate, and
# xcresult content are excluded because they are not project build inputs.
ohana_test_build_provenance_hash_inputs() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: ohana_test_build_provenance_hash_inputs REPO_ROOT PATH [PATH ...]" >&2
    return 64
  fi
  _ohana_test_build_provenance_require_python || return

  local repo_root="$1"
  shift
  local python_bin
  python_bin="$(_ohana_test_build_provenance_python_bin)"
  "${python_bin}" - "${repo_root}" "$@" <<'PY'
import hashlib
import os
import stat
import sys

EXCLUDED_DIRECTORY_NAMES = {"xcuserdata", "__pycache__"}
EXCLUDED_FILE_NAMES = {".DS_Store"}


class InputChanged(RuntimeError):
    pass


def fail(message, status=64):
    print(f"Test build provenance: {message}", file=sys.stderr)
    raise SystemExit(status)


def relative_bytes(repo_root, path):
    relative = os.path.relpath(path, repo_root)
    if relative == os.pardir or relative.startswith(os.pardir + os.sep):
        fail(f"input escapes repository root: {path}")
    return os.fsencode(relative)


def kind_for(path):
    if os.path.islink(path):
        return "symlink"
    if os.path.isdir(path):
        return "directory"
    if os.path.isfile(path):
        return "file"
    if os.path.lexists(path):
        return "other"
    return "missing"


def excluded_directory(name):
    return name in EXCLUDED_DIRECTORY_NAMES or name.endswith(".xcresult")


def excluded_file(name):
    return (
        name in EXCLUDED_FILE_NAMES
        or name.endswith(".xcuserstate")
        or name.endswith(".pyc")
        or name.endswith(".pyo")
    )


def stable_file_sha256(path):
    try:
        before = os.stat(path, follow_symlinks=False)
        content_digest = hashlib.sha256()
        with open(path, "rb") as handle:
            while True:
                chunk = handle.read(1024 * 1024)
                if not chunk:
                    break
                content_digest.update(chunk)
        after = os.stat(path, follow_symlinks=False)
    except (FileNotFoundError, IsADirectoryError) as error:
        raise InputChanged(f"input changed while hashing: {path}") from error

    before_identity = (
        before.st_dev,
        before.st_ino,
        before.st_mode,
        before.st_size,
        before.st_mtime_ns,
    )
    after_identity = (
        after.st_dev,
        after.st_ino,
        after.st_mode,
        after.st_size,
        after.st_mtime_ns,
    )
    if before_identity != after_identity:
        raise InputChanged(f"input changed while hashing: {path}")
    return content_digest.digest(), stat.S_IMODE(after.st_mode)


def add_record(digest, record_type, relative_path, mode, payload):
    digest.update(record_type.encode("ascii"))
    digest.update(b"\0")
    digest.update(len(relative_path).to_bytes(8, "big"))
    digest.update(relative_path)
    digest.update(b"\0")
    digest.update(f"{mode:o}".encode("ascii"))
    digest.update(b"\0")
    digest.update(len(payload).to_bytes(8, "big"))
    digest.update(payload)
    digest.update(b"\0")


repo_root = os.path.abspath(sys.argv[1])
if not os.path.isdir(repo_root):
    fail(f"repository root is not a directory: {repo_root}")

roots = []
seen_roots = set()
for supplied in sys.argv[2:]:
    candidate = supplied if os.path.isabs(supplied) else os.path.join(repo_root, supplied)
    candidate = os.path.abspath(candidate)
    relative = os.path.relpath(candidate, repo_root)
    if relative == os.pardir or relative.startswith(os.pardir + os.sep):
        fail(f"input escapes repository root: {supplied}")
    key = os.fsencode(relative)
    if key not in seen_roots:
        seen_roots.add(key)
        roots.append((key, candidate))
roots.sort(key=lambda item: item[0])

digest = hashlib.sha256()
digest.update(b"ohana-test-build-input-tree-v1\0")
seen_entries = set()

try:
    for root_relative, root_path in roots:
        root_kind = kind_for(root_path)
        root_mode = 0
        if root_kind != "missing":
            root_mode = stat.S_IMODE(os.lstat(root_path).st_mode)
        add_record(digest, "root", root_relative, root_mode, root_kind.encode("ascii"))

        if root_kind == "missing":
            continue
        if root_kind == "symlink":
            key = (b"symlink", root_relative)
            if key not in seen_entries:
                seen_entries.add(key)
                target = os.fsencode(os.readlink(root_path))
                add_record(digest, "symlink", root_relative, root_mode, target)
            continue
        if root_kind == "file":
            key = (b"file", root_relative)
            if key not in seen_entries:
                seen_entries.add(key)
                payload, mode = stable_file_sha256(root_path)
                add_record(digest, "file", root_relative, mode, payload)
            continue
        if root_kind != "directory":
            fail(f"unsupported input type: {root_path}")

        for directory, directory_names, file_names in os.walk(root_path, followlinks=False):
            directory_names[:] = sorted(
                (name for name in directory_names if not excluded_directory(name)),
                key=os.fsencode,
            )
            file_names = sorted(
                (name for name in file_names if not excluded_file(name)),
                key=os.fsencode,
            )

            # os.walk lists symlinked directories in directory_names. Record
            # them as links and remove them from traversal explicitly.
            retained_directories = []
            for name in directory_names:
                path = os.path.join(directory, name)
                if os.path.islink(path):
                    relative = relative_bytes(repo_root, path)
                    key = (b"symlink", relative)
                    if key not in seen_entries:
                        seen_entries.add(key)
                        mode = stat.S_IMODE(os.lstat(path).st_mode)
                        add_record(
                            digest,
                            "symlink",
                            relative,
                            mode,
                            os.fsencode(os.readlink(path)),
                        )
                else:
                    retained_directories.append(name)
            directory_names[:] = retained_directories

            for name in file_names:
                path = os.path.join(directory, name)
                relative = relative_bytes(repo_root, path)
                if os.path.islink(path):
                    key = (b"symlink", relative)
                    if key in seen_entries:
                        continue
                    seen_entries.add(key)
                    mode = stat.S_IMODE(os.lstat(path).st_mode)
                    add_record(
                        digest,
                        "symlink",
                        relative,
                        mode,
                        os.fsencode(os.readlink(path)),
                    )
                    continue

                key = (b"file", relative)
                if key in seen_entries:
                    continue
                seen_entries.add(key)
                payload, mode = stable_file_sha256(path)
                add_record(digest, "file", relative, mode, payload)
except InputChanged as error:
    print(f"Test build provenance: {error}", file=sys.stderr)
    raise SystemExit(75)

print(digest.hexdigest())
PY
}

# Hashes a set of key=value contract fields independently of caller ordering.
# Values may contain '='; keys must be unique shell-friendly identifiers.
ohana_test_build_provenance_contract_sha256() {
  _ohana_test_build_provenance_require_python || return
  local python_bin
  python_bin="$(_ohana_test_build_provenance_python_bin)"
  "${python_bin}" - "${OHANA_TEST_BUILD_PROVENANCE_SCHEMA}" "$@" <<'PY'
import hashlib
import json
import re
import sys

schema = sys.argv[1]
fields = {}
for item in sys.argv[2:]:
    if "=" not in item:
        print(f"Test build provenance: expected key=value field, got: {item}", file=sys.stderr)
        raise SystemExit(64)
    key, value = item.split("=", 1)
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", key):
        print(f"Test build provenance: invalid field key: {key}", file=sys.stderr)
        raise SystemExit(64)
    if key in fields:
        print(f"Test build provenance: duplicate field key: {key}", file=sys.stderr)
        raise SystemExit(64)
    fields[key] = value

payload = json.dumps(
    {"schema": schema, "fields": fields},
    ensure_ascii=False,
    separators=(",", ":"),
    sort_keys=True,
).encode("utf-8")
print(hashlib.sha256(payload).hexdigest())
PY
}

# Writes a self-verifying JSON stamp by fsyncing a sibling temporary file and
# atomically replacing the active stamp. Required fields make accidental weak
# contracts fail closed.
#
# Usage:
#   ohana_test_build_provenance_write_stamp STAMP_PATH key=value [...]
ohana_test_build_provenance_write_stamp() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: ohana_test_build_provenance_write_stamp STAMP_PATH key=value [...]" >&2
    return 64
  fi
  _ohana_test_build_provenance_require_python || return
  local stamp_path="$1"
  shift
  local python_bin
  python_bin="$(_ohana_test_build_provenance_python_bin)"
  "${python_bin}" - "${stamp_path}" "${OHANA_TEST_BUILD_PROVENANCE_SCHEMA}" "$@" <<'PY'
import datetime
import hashlib
import json
import os
import re
import sys
import tempfile

stamp_path = os.path.abspath(sys.argv[1])
schema = sys.argv[2]
items = sys.argv[3:]
required = {
    "project",
    "scheme",
    "sdk_name",
    "sdk_version",
    "sdk_build_version",
    "developer_dir",
    "xcode_version_sha256",
    "destination_udid",
    "code_signing_allowed",
    "copyfile_disable",
    "build_args_sha256",
    "input_scope",
    "source_tree_sha256",
}


def parse_fields(raw_items):
    parsed = {}
    for item in raw_items:
        if "=" not in item:
            print(f"Test build provenance: expected key=value field, got: {item}", file=sys.stderr)
            raise SystemExit(64)
        key, value = item.split("=", 1)
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", key):
            print(f"Test build provenance: invalid field key: {key}", file=sys.stderr)
            raise SystemExit(64)
        if key in parsed:
            print(f"Test build provenance: duplicate field key: {key}", file=sys.stderr)
            raise SystemExit(64)
        parsed[key] = value
    missing = sorted(required - parsed.keys())
    if missing:
        print(
            "Test build provenance: missing required stamp field(s): " + ", ".join(missing),
            file=sys.stderr,
        )
        raise SystemExit(64)
    return parsed


fields = parse_fields(items)
contract_payload = json.dumps(
    {"schema": schema, "fields": fields},
    ensure_ascii=False,
    separators=(",", ":"),
    sort_keys=True,
).encode("utf-8")
contract_sha256 = hashlib.sha256(contract_payload).hexdigest()
document = {
    "schema": schema,
    "contract_sha256": contract_sha256,
    "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "fields": fields,
}

parent = os.path.dirname(stamp_path)
os.makedirs(parent, exist_ok=True)
descriptor, temporary_path = tempfile.mkstemp(
    prefix=f".{os.path.basename(stamp_path)}.tmp.",
    dir=parent,
)
try:
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.chmod(temporary_path, 0o644)
    os.replace(temporary_path, stamp_path)
    try:
        directory_descriptor = os.open(parent, os.O_RDONLY)
    except OSError:
        directory_descriptor = None
    if directory_descriptor is not None:
        try:
            os.fsync(directory_descriptor)
        except OSError:
            pass
        finally:
            os.close(directory_descriptor)
finally:
    if os.path.exists(temporary_path):
        os.unlink(temporary_path)

print(contract_sha256)
PY
}

# Validates stamp structure, its stored self-hash, and every expected field.
# Returns 66 for an absent, malformed, tampered, or stale cache and prints an
# actionable rebuild instruction. It emits nothing on success.
#
# Usage:
#   ohana_test_build_provenance_validate_stamp STAMP_PATH key=value [...]
ohana_test_build_provenance_validate_stamp() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: ohana_test_build_provenance_validate_stamp STAMP_PATH key=value [...]" >&2
    return 64
  fi
  _ohana_test_build_provenance_require_python || return
  local stamp_path="$1"
  shift
  local python_bin
  python_bin="$(_ohana_test_build_provenance_python_bin)"
  "${python_bin}" - "${stamp_path}" "${OHANA_TEST_BUILD_PROVENANCE_SCHEMA}" "$@" <<'PY'
import hashlib
import json
import os
import re
import sys

stamp_path = os.path.abspath(sys.argv[1])
expected_schema = sys.argv[2]
items = sys.argv[3:]
required = {
    "project",
    "scheme",
    "sdk_name",
    "sdk_version",
    "sdk_build_version",
    "developer_dir",
    "xcode_version_sha256",
    "destination_udid",
    "code_signing_allowed",
    "copyfile_disable",
    "build_args_sha256",
    "input_scope",
    "source_tree_sha256",
}


def rebuild_message():
    print("Run this request with OHANA_TEST_ACTION=build-then-test.", file=sys.stderr)


def reject(message):
    print(message, file=sys.stderr)
    rebuild_message()
    raise SystemExit(66)


def parse_expected(raw_items):
    parsed = {}
    for item in raw_items:
        if "=" not in item:
            print(f"Test build provenance: expected key=value field, got: {item}", file=sys.stderr)
            raise SystemExit(64)
        key, value = item.split("=", 1)
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", key):
            print(f"Test build provenance: invalid field key: {key}", file=sys.stderr)
            raise SystemExit(64)
        if key in parsed:
            print(f"Test build provenance: duplicate field key: {key}", file=sys.stderr)
            raise SystemExit(64)
        parsed[key] = value
    missing = sorted(required - parsed.keys())
    if missing:
        print(
            "Test build provenance: missing required expected field(s): " + ", ".join(missing),
            file=sys.stderr,
        )
        raise SystemExit(64)
    return parsed


expected_fields = parse_expected(items)
if not os.path.isfile(stamp_path):
    reject(
        "Fixed tests cache is unverified: no successful build-for-testing "
        "provenance stamp exists."
    )

try:
    with open(stamp_path, "r", encoding="utf-8") as handle:
        document = json.load(handle)
except (OSError, UnicodeError, json.JSONDecodeError) as error:
    reject(f"Fixed tests cache provenance stamp is malformed: {error}")

if not isinstance(document, dict):
    reject("Fixed tests cache provenance stamp is malformed: root is not an object.")
if document.get("schema") != expected_schema:
    reject(
        "Fixed tests cache provenance schema is unsupported: "
        f"{document.get('schema')!r}."
    )
stored_fields = document.get("fields")
if not isinstance(stored_fields, dict) or not all(
    isinstance(key, str) and isinstance(value, str)
    for key, value in stored_fields.items()
):
    reject("Fixed tests cache provenance stamp is malformed: invalid fields.")

stored_payload = json.dumps(
    {"schema": expected_schema, "fields": stored_fields},
    ensure_ascii=False,
    separators=(",", ":"),
    sort_keys=True,
).encode("utf-8")
stored_contract = hashlib.sha256(stored_payload).hexdigest()
if document.get("contract_sha256") != stored_contract:
    reject("Fixed tests cache provenance stamp failed its self-integrity check.")

changed = sorted(
    key
    for key in set(stored_fields) | set(expected_fields)
    if stored_fields.get(key) != expected_fields.get(key)
)
if changed:
    print("Fixed tests cache provenance does not match the current build contract.", file=sys.stderr)
    print("Changed fields: " + ", ".join(changed), file=sys.stderr)
    for key in changed:
        if key in {"scheme", "sdk_name", "sdk_version", "input_scope"}:
            print(
                f"  {key}: built={stored_fields.get(key)!r}, "
                f"requested={expected_fields.get(key)!r}",
                file=sys.stderr,
            )
        elif key.endswith("_sha256"):
            built = stored_fields.get(key, "")[:12]
            requested = expected_fields.get(key, "")[:12]
            print(f"  {key}: built={built}..., requested={requested}...", file=sys.stderr)
    rebuild_message()
    raise SystemExit(66)
PY
}

ohana_test_build_provenance_invalidate_stamp() {
  if [[ $# -ne 1 ]]; then
    echo "Usage: ohana_test_build_provenance_invalidate_stamp STAMP_PATH" >&2
    return 64
  fi
  rm -f -- "$1"
}

ohana_test_build_provenance_stamp_field() {
  if [[ $# -ne 2 ]]; then
    echo "Usage: ohana_test_build_provenance_stamp_field STAMP_PATH FIELD" >&2
    return 64
  fi
  _ohana_test_build_provenance_require_python || return
  local python_bin
  python_bin="$(_ohana_test_build_provenance_python_bin)"
  "${python_bin}" - "$1" "$2" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        document = json.load(handle)
    value = document["fields"][sys.argv[2]]
except (OSError, KeyError, TypeError, UnicodeError, json.JSONDecodeError):
    raise SystemExit(66)
if not isinstance(value, str):
    raise SystemExit(66)
print(value)
PY
}
