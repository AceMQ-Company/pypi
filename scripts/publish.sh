#!/usr/bin/env bash
#
# Adds distributions to the index and regenerates it.
#
#   ./scripts/publish.sh dist/acemq_amqp-0.2.0-py3-none-any.whl dist/acemq_amqp-0.2.0.tar.gz
#   ./scripts/publish.sh                 # regenerate the index only
#
# There is no server and no credentials: the index is a directory pip walks by
# convention (PEP 503), exactly as the Maven repository, the NuGet feed and the
# gem feed beside it are. To publish, run this and commit the result.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - "$@" <<'PY'
import hashlib, html, os, re, shutil, sys

PACKAGES = "packages"
SIMPLE = "simple"


def normalise(name):
    """PEP 503 normalisation: the only spelling pip will ask for."""
    return re.sub(r"[-_.]+", "-", name).lower()


def project_of(filename):
    """The project a distribution belongs to, from its filename alone.

    A wheel is name-version-python-abi-platform.whl and an sdist is
    name-version.tar.gz, with the name's separators already normalised to
    underscores by the build backend. Reading it from the filename rather than
    from the metadata inside keeps this script free of a zip and tar reader.
    """
    if filename.endswith(".whl"):
        return normalise(filename.split("-")[0])
    for suffix in (".tar.gz", ".zip"):
        if filename.endswith(suffix):
            stem = filename[: -len(suffix)]
            return normalise(stem.rsplit("-", 1)[0])
    raise SystemExit(f"not a wheel or an sdist: {filename}")


os.makedirs(PACKAGES, exist_ok=True)

for path in sys.argv[1:]:
    if not os.path.isfile(path):
        raise SystemExit(f"no such file: {path}")
    name = os.path.basename(path)
    project_of(name)  # refuses here rather than after copying
    target = os.path.join(PACKAGES, name)
    # A published version keeps the bytes it was published with. People have
    # already resolved and pinned it, and replacing it in place means two
    # machines hold different code under one version and neither is wrong.
    #
    # Kept rather than refused, because a release job has to be re-runnable and
    # a wheel is not byte-reproducible unless it is built to be: the archive
    # carries timestamps, so a rebuild of the very same commit differs from what
    # is on the index. Failing here would mean no release could ever be re-run,
    # and the failure would look like tampering when it is only a second build.
    # Publishing genuinely changed code needs a new version number, which is the
    # rule PyPI itself enforces.
    if os.path.exists(target):
        with open(target, "rb") as a, open(path, "rb") as b:
            same = a.read() == b.read()
        if same:
            print(f"  {name} is already published, byte for byte")
        else:
            print(f"  {name} is already published; keeping the published bytes")
            print("  (a rebuild differs by its timestamps; publish a new "
                  "version to change the code)")
        continue
    shutil.copyfile(path, target)
    print(f"  added {name}")

# The index is rebuilt from what is on disk rather than appended to, so a file
# removed by hand disappears from it too.
projects = {}
for name in sorted(os.listdir(PACKAGES)):
    if name.startswith("."):
        continue
    projects.setdefault(project_of(name), []).append(name)

if os.path.isdir(SIMPLE):
    shutil.rmtree(SIMPLE)
os.makedirs(SIMPLE)

rows = "\n".join(
    f'    <a href="{p}/">{html.escape(p)}</a><br>' for p in sorted(projects))
with open(os.path.join(SIMPLE, "index.html"), "w", encoding="utf-8") as f:
    f.write("<!doctype html>\n<html><head>"
            '<meta name="pypi:repository-version" content="1.0">'
            "<title>AceMQ package index</title></head>\n<body>\n"
            f"{rows}\n</body></html>\n")

for project, files in projects.items():
    d = os.path.join(SIMPLE, project)
    os.makedirs(d)
    links = []
    for name in sorted(files):
        with open(os.path.join(PACKAGES, name), "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        # The hash is what makes this trustworthy over plain HTTP and what pip
        # checks before it installs, so it is part of the link rather than a
        # file beside it.
        links.append(
            f'    <a href="../../{PACKAGES}/{name}#sha256={digest}">'
            f"{html.escape(name)}</a><br>")
    with open(os.path.join(d, "index.html"), "w", encoding="utf-8") as f:
        f.write("<!doctype html>\n<html><head>"
                '<meta name="pypi:repository-version" content="1.0">'
                f"<title>Links for {html.escape(project)}</title></head>\n"
                f"<body>\n<h1>Links for {html.escape(project)}</h1>\n"
                + "\n".join(links) + "\n</body></html>\n")

print(f"  index regenerated over {len(projects)} project(s), "
      f"{sum(len(v) for v in projects.values())} file(s)")

# The landing page's table, rebuilt from disk for the same reason.
def version_of(filename):
    if filename.endswith(".whl"):
        return filename.split("-")[1]
    for suffix in (".tar.gz", ".zip"):
        if filename.endswith(suffix):
            return filename[: -len(suffix)].rsplit("-", 1)[1]
    return "?"


if projects:
    body = "\n".join(
        "    <tr><td><code>%s</code></td><td>%s</td></tr>"
        % (html.escape(p), ", ".join(sorted({version_of(f) for f in projects[p]})))
        for p in sorted(projects))
else:
    body = '    <tr><td colspan="2" class="no">Nothing published yet.</td></tr>'

table = ("  <table>\n"
         "    <tr><th>Project</th><th>Versions</th></tr>\n"
         f"{body}\n"
         "  </table>")

page = open("index.html", encoding="utf-8").read()
start = "<!-- projects:start -- written by scripts/publish.sh; do not edit by hand -->"
end = "<!-- projects:end -->"
before, _, rest = page.partition(start)
_, _, after = rest.partition(end)
open("index.html", "w", encoding="utf-8").write(
    f"{before}{start}\n{table}\n  {end}{after}")
PY

# Jekyll would otherwise refuse to serve anything under a directory whose name
# begins with an underscore, and skip the dot-prefixed files entirely.
touch .nojekyll
