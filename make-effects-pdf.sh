pandoc -o effects.html -f gfm \
  modular_effects.md \
  effect_interfaces.md \
  object_capabilities.md
pandoc --wrap=none -V documentclass=book --toc --template=effects.latex.template --listings -o effects.tex effects.html
if [ `uname -s` = Darwin ]; then
  SED_IN_PLACE=(-i '')
else
  SED_IN_PLACE=(-i)
fi
sed "${SED_IN_PLACE[@]}" \
  -e 's/\\chapter{Effects}/\\part{Part V: Effects}\\chapter{Effects}/' \
  effects.tex
pdflatex effects.tex
pdflatex effects.tex
