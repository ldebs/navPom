# navPom
Navigate into your maven pom hierarchiy and make a pom tree

This is a bash script that generate a navigation file.

It contains all pom.xml found in your directory and all dependencies.

The script can also make a tree dependency of your poms

## Command line arguments

Only one optionnal argument to define the navigation file

## Commands

`search` search a string in the navigation file

`!cmd` execute a bash command

`-g grep options` filter navigation file with a grep

`-d` switch show dependencies flag

`:vi file` launch vim on file and search the last search into the file

`:t [-l limit] artifact` print the dependency tree of the artifact

`:m [pom list file] [search dir]` construct the navigation file

`:q` quit

