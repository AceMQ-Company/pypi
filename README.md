# AceMQ Python index

A static PEP 503 package index. No account, no credentials, no server: a
directory of wheels and sdists and the pages that link to them, served over
HTTPS by GitHub Pages at <https://acemq.org/pypi/>.

It exists because the AceMQ Python library is not on PyPI yet. A project name
there is permanent and a released version can never be re-uploaded — deleting a
release does not free its filename — so the library is published here until it
is ready for that decision to be irreversible.

## Installing from it

```bash
pip install acemq-amqp --index-url https://acemq.org/pypi/simple/
```

In a requirements file:

```
--extra-index-url https://acemq.org/pypi/simple/
acemq-amqp==0.2.0
```

`--extra-index-url` keeps PyPI for everything else, but know what it means: pip
merges the two indexes and takes the highest version it finds under a name,
whichever index it came from. Naming this index with `--index-url` and pinning
the version is the arrangement with no surprises in it.

## Publishing

```bash
./scripts/publish.sh dist/acemq_amqp-0.2.0-py3-none-any.whl dist/acemq_amqp-0.2.0.tar.gz
git add -A && git commit -m "Publish acemq-amqp 0.2.0" && git push
```

The AceMQ Python release workflow does this for you on a tag. Running it by hand
is for repairing the index, not for routine publishing.

The script refuses to replace an existing file with different bytes. A version
someone has already resolved and pinned must keep the contents it had, or two
machines end up running different code under one version number and neither of
them is wrong.

## The index

PEP 503, which is just HTML:

```
simple/index.html           every project
simple/<project>/index.html every file of that project, each link carrying
                            #sha256=... which pip verifies before installing
packages/                   the wheels and sdists themselves
scripts/publish.sh          adds a distribution and regenerates the above
```

The hash in the fragment is what makes a download from here trustworthy, so it
is part of the link rather than a checksum file beside it. `pip install
--require-hashes` works against this index.

Project names in URLs are normalised as PEP 503 requires — lowercased, with runs
of `-`, `_` and `.` collapsed to a single `-` — because that is the only
spelling pip will ask for.

## Licence

The distributions carry their own licences. This repository — the scripts and
the page — is Apache-2.0, like the libraries it serves.
