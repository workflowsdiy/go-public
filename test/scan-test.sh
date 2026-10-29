#!/usr/bin/env bash
# Builds throwaway repositories, each hiding one kind of leak, and checks that scan.sh finds it (or exits 2).
# Usage: test/scan-test.sh. Prints PASS or FAIL per case and exits 1 if any case fails.
set -u
SCAN=$(cd "$(dirname "$0")/.." && pwd)/skills/go-public/scan.sh
B=$(mktemp -d)
trap 'rm -rf "$B"' EXIT
cd "$B" || exit 2
failed=0
c() { git -c user.name=Pub -c user.email=pub@example.com "$@"; }
mk() { rm -rf "$B/$1"; git init -q -b main "$B/$1"; cd "$B/$1" || exit 2; }
one() { echo base > base.txt; c add -A; c commit -qm init; }
# Stages an entry straight into the index (mode, content, path), so symlinks and names Windows can't create on disk work.
stage() { git -c core.protectNTFS=false update-index --add --cacheinfo "$1,$(printf '%s' "$2" | git hash-object -w --stdin),$3"; }
tok() { echo "ghp_$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 36)"; }
jpeg() { # $1: output file; a small JPEG with camera and GPS metadata
  base64 -d > "$1" <<< "$TINY" && exiftool -q -overwrite_original -Make=Phone -Model=X1 \
    -GPSLatitude=49.2 -GPSLatitudeRef=N -GPSLongitude=123.1 -GPSLongitudeRef=W "$1"
}
expect() { # name, expected exit, regex the output must match
  local out st
  out=$(GO_PUBLIC_PATTERNS=$B/p.txt bash "$SCAN" . --identity "Pub <pub@example.com>" 2>&1); st=$?
  if [ "$st" = "$2" ] && { [ -z "$3" ] || grep -qiE -- "$3" <<< "$out"; }; then echo "PASS $1"
  else echo "FAIL $1 (exit $st)"; grep -E '!|ERROR' <<< "$out" | head -5; failed=1; fi
  cd "$B" || exit 2
}
TINY=/9j/wAARCAAIAAgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9sAQwACAgICAgIDAgIDBQMDAwUGBQUFBQYIBgYGBgYICggICAgICAoKCgoKCgoKDAwMDAwMDg4ODg4PDw8PDw8PDw8P/9sAQwECAgIEBAQHBAQHEAsJCxAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ/90ABAAB/9oADAMBAAIRAxEAPwDmfi/HB8QbW2+IvhnT4tSuLOe21HWDb3L3NtazSNKCJHY/MSFSPceQoXI25ryH/hMbj/oDaf8A99pXrXwO/wCTfvi5/wBc7T/0J6+Ya8eOChir1J6PbTQTvBJJn//Z

printf '%s\n' 'jdoe' '/Users/jdoe' 'PRIVÉ_NEEDLE' '王小明' > "$B/p.txt"
mk clean; one; expect clean 0 ""
mk fname; mkdir jdoe-notes; echo x > jdoe-notes/a; git add -A; c commit -qm i; expect file-name 1 "name"
mk dupname; echo same > safe.txt; mkdir private-jdoe; echo same > private-jdoe/x.txt; git add -A; c commit -qm i; expect same-content-private-name 1 "name"
mk nlname; stage 100644 x "$(printf 'ok\njdoe.txt')"; c commit -qm i; expect newline-in-name 1 "newline"
mk author; echo x > a; git add a; git -c user.name=Jdoe -c user.email=jdoe@x.com commit -qm i; expect author 1 "identities"
mk tagmsg; one; c tag -a v1 -m "built on the jdoe laptop"; expect tag-message 1 "commit or tag text"
mk branch; one; c branch jdoe-wip; expect branch-name 1 "refs besides"
mk tgz; mkdir d; echo "/Users/jdoe/x" > d/f; tar czf a.tgz d; tar cf b.tar d; rm -r d; git add -A; c commit -qm i; expect archive 1 "personal-"
mk zipped; echo hi | gzip -c > a.gz; git add -A; c commit -qm i; expect any-archive 1 "archive"
mk utf16; printf 'p\0a\0t\0h\0 \0/\0U\0s\0e\0r\0s\0/\0j\0d\0o\0e\0' > u.txt; git add u.txt; c commit -qm i; expect utf16 1 "u.txt"
mk utf16accent; printf 'PRIVÉ_NEEDLE here' | iconv -f UTF-8 -t UTF-16LE > u.txt; git add -A; c commit -qm i; expect utf16-non-ascii 1 "u.txt"
mk utf16bom; printf '\377\376\213\163\017\134\016\146' > u.txt; git add -A; c commit -qm i; expect utf16-bom-no-nul 1 "u.txt"
mk nulhead; { printf '\0\0\0'; head -c 9000 /dev/zero; echo /Users/jdoe; } > b.bin; git add b.bin; c commit -qm i; expect nul-before-text 1 "b.bin"
mk b64; echo "v = $(printf '/Users/jdoe/secret/path' | base64)" > c.cfg; git add -A; c commit -qm i; expect base64-personal 1 "decoded|personal"
mk symlink; stage 120000 /Users/jdoe/secret link; c commit -qm i; expect symlink 1 "symlink"
mk symext; stage 120000 /etc/passwd link.txt; c commit -qm i; expect symlink-with-extension 1 "symlink"
mk msgsecret; one; echo y > y; git add y; c commit -qm "token $(tok)"; expect secret-in-commit-message 1 "github-pat"
mk allowlist; mkdir vendor; echo "t = \"$(tok)\"" > vendor/k; printf '[allowlist]\npaths = ["vendor"]\n' > .gitleaks.toml; git add -A; c commit -qm i; expect repo-gitleaks-allowlist-ignored 1 "github-pat"
mk merge; one; git checkout -qb side; echo s > s; git add s; c commit -qm s; git checkout -q main; echo m > m; git add m; c commit -qm m
  c merge -q --no-commit side 2>/dev/null; echo "k = \"$(tok)\"" > resolved.cfg; git add resolved.cfg; c commit -qm merge; git branch -qD side; expect secret-only-in-merge 1 "github-pat"
mk deleted; one; git checkout -qb tmp; echo /Users/jdoe/x > p; git add p; c commit -qm p; git checkout -q main; git branch -qD tmp; expect deleted-branch-object 1 "^  ! p \(blob"
mk upper; jpeg IMG.JPG; git add -A; c commit -qm i; expect uppercase-jpeg 1 "GPS|Make"
mk noext; jpeg picture; git add -A; c commit -qm i; expect jpeg-without-extension 1 "GPS|Make"
mk oldmedia; jpeg p.jpg; git add -A; c commit -qm i; echo x > p.jpg; git add -A; c commit -qm j; expect overwritten-jpeg 1 "GPS|Make"
mk truncjpg; jpeg full.jpg; head -c 300 full.jpg > e.jpg; rm full.jpg; git add -A; c commit -qm i; expect truncated-jpeg 1 "could not be read|GPS|Make"
mk htmlauthor; printf '<html><head><meta name="author" content="Someone"></head></html>' > a.html; git add -A; c commit -qm i; expect html-author 1 "Author|could not be read"
mk rename; one; git mv base.txt b2.txt; c commit -qm mv; expect history-to-squash 1 "2 commits"
mk shallowsrc; one; echo 2 > b; git add b; c commit -qm 2; cd "$B" || exit 2; git clone -q --depth 1 "file://$B/shallowsrc" shallow; cd shallow || exit 2; expect shallow-clone 2 "shallow"
mk empty; expect empty-repo 0 ""
mk noident; one; GO_PUBLIC_PATTERNS=$B/p.txt bash "$SCAN" . --identity > /dev/null 2>&1
  if [ $? = 2 ]; then echo "PASS missing-identity-value"; else echo "FAIL missing-identity-value"; failed=1; fi; cd "$B" || exit 2
printf '' > "$B/p.txt"; mk nopat; one; expect empty-pattern-file 2 "no patterns"
printf '[\n' > "$B/p.txt"; mk badpat; one; expect invalid-pattern 2 "invalid regex"
exit $failed
