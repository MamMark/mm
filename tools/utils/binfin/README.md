BINFIN
=======

Ricky Li Fo Sjoe <flyrlfs@gmail.com>
copyright (c) 2018 Ricky Li Fo Sjoe

*License*: [GPL3](https://opensource.org/licenses/GPL-3.0)

binfin - Update the generated main.exe file to update the Meta Tag information
    binfin will look for the associated BIN file and apply the same update
    to the image Meta Tag in that file.

Usage: binfin [ -h ] [ -i ]
    [ -I <Img Desc.> ] [ -R <Repo0 Desc.> ] [ -r <Repo1 Desc.> ]
    [ -t <timestamp> ] <filename>

    <filename> the name of an EXE, with ELF, which needs to have it's
    image_info META updated.  Binfin will look for the BIN file and update that
    if it exists.

-h
    Help show this usage information

-I
    Image Description string

-R
    Repo0 Description string

-r
    Repo1 Description string

-t
    Timestamp string (30 chars max)

-i
    Execute BinInfo on the file to read and display META info
    in the file.





