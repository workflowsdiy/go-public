#!/usr/bin/env bash
# Leak scan for a repository about to go public. It works on a temporary mirror holding every local ref and every
# ref of the repository's GitHub remotes (refs/pull/* included), and inspects every blob ever committed (raw bytes,
# NUL-stripped for UTF-16, archives opened), commit and tag text, identities, ref and file names, symlink targets,
# submodules, LFS pointers, media metadata and how much history GitHub already holds. It never changes the repository.
# Usage: scan.sh [repo-dir] [--identity "Name <email>"]
# Personal strings: one extended regex per line in $GO_PUBLIC_PATTERNS (default ~/.config/go-public/patterns.txt).
# Exit 0: clean. 1: findings to resolve (lines marked "!"). 2: the scan could not finish (lines marked "ERROR").
set -uo pipefail
export LC_ALL=C GIT_NO_REPLACE_OBJECTS=1 GIT_TERMINAL_PROMPT=0
unset GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML

findings=0
note() { echo "  ! $*"; findings=1; }
die() { echo "  ERROR: $*"; exit 2; }

repo=. identity=
while [ $# -gt 0 ]; do
  case $1 in
    --identity) [ $# -ge 2 ] && [ -n "$2" ] || die "--identity needs \"Name <email>\""; identity=$2; shift 2;;
    -*) die "unknown option $1";;
    *) repo=$1; shift;;
  esac
done

for t in git gitleaks exiftool jq perl; do command -v $t >/dev/null || die "$t is not installed"; done
tmp=$(mktemp -d) || die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT
scan=$tmp/scan
mkdir -p "$scan/blobs" "$scan/decoded" "$tmp/noignore"

pfile=${GO_PUBLIC_PATTERNS:-$HOME/.config/go-public/patterns.txt}
[ -r "$pfile" ] || die "no pattern file at $pfile: copy patterns.example.txt there and fill it in"
tr -d '\r' < "$pfile" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v -e '^#' -e '^$' > "$tmp/patterns"
[ -s "$tmp/patterns" ] || die "$pfile has no patterns"
# Perl, not grep, matches the patterns: Git for Windows' grep 3.0 aborts on -i with -f.
perl -ne 'chomp; eval { qr/$_/ } or exit 2; exit 3 if "" =~ /$_/' "$tmp/patterns"
case $? in 0) ;; 3) die "a pattern in $pfile matches empty text";; *) die "invalid regex in $pfile";; esac

# Where a scanned file came from: a blob's path in history, or the kind of text it holds.
where() {
  local f=${1#"$scan"/}; f=${f%%!*}
  case $f in
    blobs/*|decoded/*) local s=${f#*/} p; s=${s%%.*}; p=$(grep -m1 "^$s " "$tmp/objnames" | cut -d' ' -f2-); echo "${p:-an unreachable object} (blob $s)";;
    meta.txt) echo "commit or tag text (messages, authors, committers, taggers)";;
    names.txt) echo "a file, directory or ref name";;
    exif.json) echo "media metadata";;
    *) echo "$f";;
  esac
}

echo "== Repository"
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || die "$repo is not a git repository"
[ "$(git -C "$repo" rev-parse --is-shallow-repository)" = false ] || die "shallow clone: run git fetch --unshallow first"
[ -s "$(git -C "$repo" rev-parse --git-path info/grafts)" ] && die "grafts are set: history is not what it seems"
[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ] && note "uncommitted changes are not scanned: commit or remove them"
echo "  $(cd "$repo" && pwd), HEAD $(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo 'none (no commits)')"
m=$tmp/mirror.git
git clone -q --mirror --no-local "$repo" "$m" 2>"$tmp/err" || die "could not copy the repository: $(head -1 "$tmp/err")"
# The repository's own object store too, read-only, so objects no ref reaches (deleted branches, dropped stashes)
# are scanned as well.
src=$(cd "$repo" && git rev-parse --path-format=absolute --git-path objects) || die "cannot find the object store"
echo "$src" >> "$m/objects/info/alternates"

echo "== What GitHub already holds"
git -C "$repo" config --get-regexp '^remote\..*\.(push)?url$' > "$tmp/remotes"
: > "$tmp/ghrepos"; n=0
while read -r key url; do
  case $url in *github.com[:/]*) ;; *) echo "  $key is not GitHub: not checked"; continue;; esac
  r=$(printf '%s' "$url" | sed -E 's#^.*github\.com[:/]+##; s#/+$##; s#\.git$##')
  case $r in */*) ;; *) die "cannot read owner/repo from $key ($url)";; esac
  grep -qxF "$r" "$tmp/ghrepos" && continue
  echo "$r" >> "$tmp/ghrepos"
  command -v gh >/dev/null || die "gh is not installed: cannot check $r"
  info=$(gh api "repos/$r" --jq '"\(.id) \(.visibility) \(.fork) \(.forks_count)"' 2>"$tmp/err") ||
    die "gh api repos/$r failed: $(head -1 "$tmp/err")"
  read -r id vis fork forks <<< "$info"
  n=$((n + 1))
  git -C "$m" fetch -q "$url" "+refs/*:refs/github$n/*" 2>"$tmp/err" || die "could not fetch every ref of $r: $(head -1 "$tmp/err")"
  refs=$(git -C "$m" for-each-ref --format=x "refs/github$n/" | wc -l | tr -d ' ')
  pulls=$(git -C "$m" for-each-ref --format=x "refs/github$n/pull/" | wc -l | tr -d ' ')
  commits=$(git -C "$m" rev-list --count --glob="refs/github$n/*")
  echo "  $r (id $id): $vis, $refs refs, $commits commits, $forks forks"
  [ "$fork" = true ] && note "$r is a fork: its network shares objects with the parent"
  [ "$forks" -gt 0 ] && note "$r has $forks forks: they keep every commit they saw"
  [ "$pulls" -gt 0 ] && note "$r has $pulls pull-request refs: GitHub keeps them through any rewrite"
  [ "$commits" -gt 1 ] && note "GitHub holds $commits commits of $r: all stay readable by SHA once it is public, so publish to a fresh repository"
  # Refs only show what is reachable now. Ask GitHub for every other local commit: a squash or force push leaves
  # the old ones readable by SHA.
  git -C "$m" rev-list --glob="refs/github$n/*" | sort > "$tmp/on-refs"
  git -C "$m" cat-file --batch-all-objects --batch-check='%(objecttype) %(objectname)' | awk '$1=="commit" {print $2}' |
    sort -u | comm -23 - "$tmp/on-refs" > "$tmp/probe"
  probed=0; readable=0
  while read -r sha; do
    [ "$probed" -ge 500 ] && { note "only the first 500 of $(wc -l < "$tmp/probe" | tr -d ' ') off-ref commits were probed"; break; }
    probed=$((probed + 1))
    if gh api "repos/$r/git/commits/$sha" --silent 2>"$tmp/err"; then
      readable=$((readable + 1)); echo "$sha" >> "$tmp/readable"
    else
      grep -qE 'HTTP (404|409|422)' "$tmp/err" || die "gh api repos/$r/git/commits/$sha failed: $(head -1 "$tmp/err")"
    fi
  done < "$tmp/probe"
  echo "  probed $probed local commits that no GitHub ref reaches: $readable still readable on GitHub"
  [ "$readable" -gt 0 ] && note "$readable commits of $r that no ref shows are still readable by SHA$([ "$vis" = public ] && echo ', publicly'): $(head -3 "$tmp/readable" | cut -c1-12 | tr '\n' ' ')..."
done < "$tmp/remotes"
[ "$n" = 0 ] && echo "  no GitHub remote"

cd "$m" || die "cannot enter the mirror"
git for-each-ref --format='%(refname)' > "$tmp/refs"
git cat-file --batch-all-objects --batch-check='%(objecttype) %(objectname) %(objectsize)' | sort -u > "$tmp/objects" ||
  die "cannot list objects"
# Names for every object any commit reaches, including commits no ref keeps (deleted branches, reflogs).
awk '$1=="commit" {print $2}' "$tmp/objects" | git rev-list --objects --stdin > "$tmp/objnames" || die "cannot list object names"
grep -v '^refs/github' "$tmp/refs" | xargs git rev-list 2>/dev/null | sort > "$tmp/reachable"
awk '$1=="blob" {print $2}' "$tmp/objects" > "$tmp/blobs"
awk '$1=="commit" || $1=="tag" {print $2}' "$tmp/objects" | git cat-file --batch > "$scan/meta.txt" || die "cannot read commits"
# Every path in every committed tree, NUL-delimited so no name is cut short.
: > "$tmp/names.z"
grep -aE '^tree [0-9a-f]{40,64}$' "$scan/meta.txt" | cut -d' ' -f2 | sort -u > "$tmp/trees"
while read -r t; do git ls-tree -r -t -z --name-only "$t" >> "$tmp/names.z" || die "cannot list tree $t"; done < "$tmp/trees"
perl -0ne 'chomp; print "$_\n"' "$tmp/names.z" > "$scan/names.txt" || die "cannot read names"
perl -0ne 'chomp; exit 3 if /\n/' "$tmp/names.z"; [ $? = 3 ] && note "a committed file name contains a newline"
cat "$tmp/refs" >> "$scan/names.txt"
# Each blob is saved as <sha>.<extension of its first path>, since gitleaks and exiftool need extensions for archives
# and some media; UTF-16 text also gets a decoded UTF-8 copy and a NUL-stripped one; archives are listed.
git cat-file --batch < "$tmp/blobs" | perl -MEncode -e '
  my ($d, $names, $arch, $dec) = @ARGV; my %ext; binmode STDIN;
  open my $m, "<", $names or die; open my $a, ">", $arch or die;
  while (<$m>) { chomp; my ($s, $p) = split / /, $_, 2; next if !defined $p || exists $ext{$s};
    my $e = ($p =~ m{(\.tar)?\.([A-Za-z0-9]{1,8})$}) ? lc(($1 // "") . ".$2") : "";
    $e = {".tgz" => ".tar.gz", ".tbz" => ".tar.bz2", ".tbz2" => ".tar.bz2", ".txz" => ".tar.xz"}->{$e} // $e;
    $ext{$s} = $e }
  sub put { my ($o, $data) = @_; open my $f, ">", $o or die; binmode $f; print $f $data; close $f or die }
  while (my $h = <STDIN>) {
    my ($s, $t, $n) = split " ", $h; my $b = "";
    read(STDIN, $b, $n) == $n or die "short read"; getc STDIN;
    put("$d/$s" . ($ext{$s} // ""), $b);
    print $a "$s\n" if $b =~ /\A(?:PK\x03\x04|\x1f\x8b|BZh|\xFD7zXZ\x00|7z\xBC\xAF\x27\x1C|Rar!|\x28\xB5\x2F\xFD)/ or substr($b, 257, 5) eq "ustar";
    my $bom = substr($b, 0, 2); my $has_nul = index($b, "\0") >= 0;
    next if !$has_nul && $bom ne "\xFF\xFE" && $bom ne "\xFE\xFF";
    my $k = length($b) < 4096 ? length($b) : 4096; my ($ev, $od) = (0, 0);
    for my $i (0 .. $k - 1) { next if substr($b, $i, 1) ne "\0"; $i % 2 ? $od++ : $ev++ }
    my $enc = $bom eq "\xFF\xFE" ? "UTF-16LE" : $bom eq "\xFE\xFF" ? "UTF-16BE" : $od > $k / 4 ? "UTF-16LE" : $ev > $k / 4 ? "UTF-16BE" : "";
    put("$dec/$s.utf16.txt", Encode::encode("UTF-8", Encode::decode($enc, $b))) if $enc;
    if ($has_nul) { (my $c = $b) =~ tr/\0//d; put("$dec/$s.nul-stripped", $c) }
  }' "$scan/blobs" "$tmp/objnames" "$tmp/archives" "$scan/decoded" || die "cannot extract blobs"

echo "== History"
commits=$(grep -c '^commit ' "$tmp/objects")
roots=$(git rev-list --max-parents=0 --all | wc -l | tr -d ' ')
unreach=$(awk '$1=="commit" {print $2}' "$tmp/objects" | comm -23 - "$tmp/reachable" | wc -l | tr -d ' ')
echo "  $commits commits ($unreach that no local ref reaches: deleted branches, reflogs, old squashes), $roots root commits, $(wc -l < "$tmp/refs" | tr -d ' ') refs"
[ "$commits" -gt 1 ] && note "$commits commits: publish one clean commit from a fresh repository (SKILL.md step 6)"
[ "$roots" -gt 1 ] && note "$roots root commits: unrelated histories are joined"
# Remote-tracking refs are scanned but never pushed; every other ref could be.
grep -vE '^refs/(github[0-9]+|remotes)/' "$tmp/refs" | grep -vx 'refs/heads/main' > "$tmp/extra"
[ -s "$tmp/extra" ] && note "refs besides refs/heads/main: $(tr '\n' ' ' < "$tmp/extra")"

echo "== Authors, committers and taggers"
grep -aE '^(author|committer|tagger) ' "$scan/meta.txt" | sed -E 's/^[a-z]+ (.*) [0-9]+ [-+][0-9]{4}$/\1/' | sort | uniq -c
if [ -n "$identity" ]; then
  others=$(grep -aE '^(author|committer|tagger) ' "$scan/meta.txt" | sed -E 's/^[a-z]+ (.*) [0-9]+ [-+][0-9]{4}$/\1/' | sort -u | grep -vxF "$identity")
  [ -n "$others" ] && note "identities other than $identity: $(echo "$others" | tr '\n' ';')"
else
  echo "  (pass --identity \"Name <email>\" to require one public identity)"
fi

echo "== Symlinks, submodules and LFS"
git rev-list --all | git diff-tree --stdin -r -m --root --no-commit-id --no-renames > "$tmp/changes" || die "cannot list tree changes"
while IFS=$'\t' read -r head path; do
  set -- $head
  case $2 in
    120000) target=$(git cat-file blob "$4") || die "cannot read symlink $path"; case $target in /*|*..*) note "symlink $path points outside the repository: $target";; esac;;
    160000) note "submodule $path (commit $4): its content is not scanned; scan and review that repository too";;
  esac
done < "$tmp/changes"
lfs=$(grep -rlE '^version https://git-lfs\.github\.com/spec/' "$scan/blobs" | wc -l | tr -d ' ')
[ "$lfs" -gt 0 ] && note "$lfs LFS pointers: the payloads are not scanned; fetch and inspect them, and remember GitHub keeps LFS objects after a rewrite"
while read -r s; do
  note "archive $(where "blobs/$s"): gitleaks looks inside, but names, metadata and encodings in it are not fully checked; unpack and review it, or leave it out"
done < "$tmp/archives"
echo "  checked"

echo "== Media metadata"
exiftool -r -ext '*' -j -G1 -a -q -q "$scan/blobs" > "$scan/exif.json" 2>"$tmp/err"
[ $? -le 1 ] || die "exiftool failed: $(head -1 "$tmp/err")"
[ -s "$scan/exif.json" ] || echo '[]' > "$scan/exif.json"   # no file it could read
jq -e 'type == "array"' "$scan/exif.json" >/dev/null 2>&1 || die "exiftool output is not readable: $(head -1 "$tmp/err")"
# JSON keys are plain text that the other checks already read; every other group is metadata.
jq -r '.[] | (.SourceFile | sub("^.*/scan/"; "")) as $f | to_entries[]
  | if (.key == "ExifTool:Error" and (.value | tostring | test("Unknown file type|File is empty") | not)) or
       (.key == "ExifTool:Warning" and (.value | tostring | startswith("[minor]") | not)) then "\($f)\tcould not be read fully: \(.value)"
    elif (.key | test("^(ExifTool|System|File|Composite|JSON):|^SourceFile$")) then empty
    elif (.key | sub("^[^:]*:"; "") | test("^(GPS|Make$|Model$|.*Serial|Artist$|Author$|Creator$|By-line|OwnerName|CameraOwnerName|LastModifiedBy|Company$|Manager$|HostComputer$|UserComment$|XPAuthor$|XPComment$|Location|City$|Country|Sub-location|Province|Email|Contact)")) then "\($f)\t\(.key)"
    else empty end' "$scan/exif.json" > "$tmp/meta-raw" || die "cannot read exiftool output"
sort -u "$tmp/meta-raw" > "$tmp/meta-hits"
while IFS=$'\t' read -r f tag; do note "$(where "$f"): $tag"; done < "$tmp/meta-hits"
[ -s "$tmp/meta-hits" ] || echo "  none"

echo "== Personal strings (raw bytes of every blob, names, commit text, metadata)"
perl -MFile::Find -e '
  my ($pf, $root) = @ARGV; open my $p, "<", $pf or die; my @re = map { chomp; qr/$_/i } <$p>;
  find({ no_chdir => 1, wanted => sub {
    return unless -f $_; open my $f, "<:raw", $_ or die "$_: $!"; local $/; my $b = <$f> // "";
    for my $r (@re) { if ($b =~ $r) { print "$_\n"; last } } } }, $root);
' "$tmp/patterns" "$scan" | sort > "$tmp/personal" || die "the personal-string check failed"
while IFS= read -r f; do note "$(where "$f")"; done < "$tmp/personal"
# Say exactly which names and which commits or tags matched, never which pattern.
perl -e '
  my ($pf, $scan) = @ARGV; open my $p, "<", $pf or die; my @re = map { chomp; qr/$_/i } <$p>;
  sub hit { my $t = shift; for (@re) { return 1 if $t =~ $_ } 0 }
  if (open my $n, "<:raw", "$scan/names.txt") { my $k = 0;
    while (<$n>) { chomp; next unless hit($_); print "    name: $_\n" if $k++ < 20 } print "    ... $k names in all\n" if $k > 20 }
  if (open my $m, "<:raw", "$scan/meta.txt") { local $/; my $all = <$m>; my %seen;
    while ($all =~ /^([0-9a-f]{40,64}) (commit|tag) (\d+)\n/mg) {
      my ($s, $t, $len) = ($1, $2, $3); my $body = substr($all, pos($all), $len);
      print "    $t $s\n" if hit($body) && !$seen{$s}++ } }
' "$tmp/patterns" "$scan" || die "cannot list the matching names and commits"
[ -s "$tmp/personal" ] || echo "  none"

echo "== Secrets and personal strings in archives (gitleaks, trusted config)"
{
  printf '[extend]\nuseDefault = true\n'
  i=0
  while IFS= read -r p; do i=$((i + 1)); printf "\n[[rules]]\nid = \"personal-%d\"\nregex = '''(?i)%s'''\n" $i "$p"; done < "$tmp/patterns"
} > "$tmp/gitleaks.toml"
gitleaks dir "$scan" --config "$tmp/gitleaks.toml" --gitleaks-ignore-path "$tmp/noignore" --ignore-gitleaks-allow \
  --max-archive-depth 8 --redact --no-banner --log-level error --exit-code 3 \
  --report-format json --report-path "$tmp/leaks.json" >/dev/null 2>"$tmp/err"
case $? in
  0) echo "  none";;
  3) # Personal matches in plain files were reported above; keep the ones found inside archives or decoded text.
     jq -r --arg p "$scan/" '.[] | select((.RuleID | startswith("personal-") | not) or (.File | contains("!"))
       or ((.Tags // []) | any(startswith("decoded")))) | "\(.RuleID)\t\(.File | ltrimstr($p))"' "$tmp/leaks.json" > "$tmp/leaks-raw" ||
       die "cannot read the gitleaks report"
     sort -u "$tmp/leaks-raw" > "$tmp/leaks"
     while IFS=$'\t' read -r rule f; do note "$rule in $(where "$scan/$f")"; done < "$tmp/leaks"
     [ -s "$tmp/leaks" ] || echo "  none beyond the personal strings above";;
  *) die "gitleaks failed: $(head -1 "$tmp/err")";;
esac

echo "== Large blobs (review, not blocking)"
awk '$1=="blob" && $3>1000000 {print $2, $3}' "$tmp/objects" | while read -r s size; do
  echo "  ? $(awk -v s="$size" 'BEGIN {printf "%.1f MB", s/1e6}') $(where "blobs/$s")"
done

echo "== Not inspected: review by hand"
echo "  text drawn inside images, video or audio; encrypted archives; base64 media inside notebooks; LFS payloads;"
echo "  submodule contents; anything outside the git repository (see settings.sh inventory)"

[ "$findings" = 0 ] && echo "== Clean"
exit $findings
