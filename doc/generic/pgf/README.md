# Extract and compile code exmples

```bash
# Set up the directories for example code extraction and compilatiom
mkdir -p ~/tmp/mwe/plots
mkdir -p ~/tmp/mwe/generic/pgf/plots

cd ~/tmp/mwe
ln -s ~/github.com/pgf/doc/generic/pgf/images

cd ~/tmp/mwe/generic/pgf
ln -s ~/github.com/pgf/doc/generic/pgf/images

# Clean up
find ~/tmp/mwe -name '*.tex' -o -name '*.aux' -o -name '*.log' -o -name '*.gz' -o -name '*.pdf' | xargs rm

# Extract code examples to ~/tmp/mwe
cd ~/tmp
texlua ~/github.com/pgf/doc/generic/pgf/extract.lua ~/github.com/pgf/tex ~/github.com/pgf/doc ~/tmp/mwe

# Delete the irrelevant files
find mwe -name '*finder*.tex' | xargs rm
find mwe -name '*.tex' | xargs grep -l 'very simple example layout' | xargs rm
find mwe -name '*.tex' | xargs grep -l 'print_lines_on_output' | xargs rm
find mwe -name '*.tex' | xargs grep -l 'social degree layout' | xargs rm
find mwe -name '*.tex' | xargs grep -l 'animated binary tree layout' | xargs rm
find mwe -name '*.tex' | xargs grep -l 'SugiyamaLayout' | xargs rm
find mwe -name '*.tex' | xargs grep -l 'BalloonLayout' | xargs rm
find mwe -name '*.tex' | xargs grep -l 'CircularLayout' | xargs rm
find mwe -name '*.tex' | xargs grep -l 'FMMMLayout' | xargs rm
find mwe -name '*.tex' | xargs grep -l 'PlanarizationLayout' | xargs rm
find mwe -name '*.tex' | xargs grep -l '<g id="pgf3"  prefix=" automata: http://www.tcs.uni-luebeck.de/ontologies/automata/ ">' | xargs rm

# Compile all the code examples
cd mwe
n=1
N=$(find . -name '*.tex' | wc -l)

time for i in $(find . -name '*.tex'); do
    echo -n "Processing $n/$N $i"
    if [ -f "${i%%.tex}.pdf" ]; then
        echo -n " Skipped." # skip existing
    else
        lualatex -interaction=batchmode -shell-escape -halt-on-error "$i" > /dev/null
        if [ "x$?" == "x1" ]; then
            echo -n " Failed!"
        fi
    fi
    echo ""
    n=$((n+1))
done 2>&1 | tee ./compilation.log
```
