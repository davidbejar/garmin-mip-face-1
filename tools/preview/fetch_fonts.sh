#!/usr/bin/env bash
# Download the candidate fonts compared in the 2026-11-20 time-font round into
# tools/preview/cache/ (git-ignored). All SIL OFL, except Permanent Marker
# (Apache 2.0). The fonts actually shipped live in tools/fonts/ with licences.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p cache && cd cache
G=https://raw.githubusercontent.com/google/fonts/main
get() { [[ -f "$2" ]] || curl -sfL "$G/$1" -o "$2"; }
get ofl/barlowcondensed/BarlowCondensed-ExtraBold.ttf BarlowCondensed-ExtraBold.ttf
get ofl/barlowcondensed/BarlowCondensed-Black.ttf BarlowCondensed-Black.ttf
get "ofl/oswald/Oswald%5Bwght%5D.ttf" Oswald.ttf
get ofl/sairacondensed/SairaCondensed-ExtraBold.ttf SairaCondensed-ExtraBold.ttf
get "ofl/antonio/Antonio%5Bwght%5D.ttf" Antonio.ttf
get ofl/bebasneue/BebasNeue-Regular.ttf BebasNeue-Regular.ttf
get "ofl/doto/Doto%5BROND,wght%5D.ttf" Doto.ttf
get ofl/dotgothic16/DotGothic16-Regular.ttf DotGothic16-Regular.ttf
get "ofl/caveat/Caveat%5Bwght%5D.ttf" Caveat.ttf
get ofl/kalam/Kalam-Bold.ttf Kalam-Bold.ttf
get apache/permanentmarker/PermanentMarker-Regular.ttf PermanentMarker-Regular.ttf
get ofl/patrickhand/PatrickHand-Regular.ttf PatrickHand-Regular.ttf
get ofl/gochihand/GochiHand-Regular.ttf GochiHand-Regular.ttf
get ofl/nanumpenscript/NanumPenScript-Regular.ttf NanumPenScript-Regular.ttf
get ofl/coveredbyyourgrace/CoveredByYourGrace.ttf CoveredByYourGrace.ttf
if [[ ! -d dseg ]]; then
    curl -sfL https://github.com/keshikan/DSEG/releases/download/v0.46/fonts-DSEG_v046.zip -o dseg.zip
    mkdir -p dseg && unzip -q -o dseg.zip -d dseg && rm dseg.zip
fi
echo "fonts in $(pwd)"
