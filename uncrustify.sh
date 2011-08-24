PATH=${PATH}:/usr/local/bin
if $(which -s uncrustify); then
    for name in "*.h" "*.pch"
    do
        for file in `find . -name $name`
        do
            uncrustify -c uncrustify.cfg -l OC+ -f $file | diff --old-line-format="$file:%dn: warning: uncrustify wants to change this: %L" --unchanged-line-format="" $file -
        done
    done
    for name in "*.m" "*.mm"
    do
        for file in `find . -name $name`
        do
            # Same as above, but without -l OC+
            uncrustify -c uncrustify.cfg -f $file | diff --old-line-format="$file:%dn: warning: uncrustify wants to change this: %L" --unchanged-line-format="" $file -
        done
    done
else
    echo "warning: uncrustify not found"
fi
