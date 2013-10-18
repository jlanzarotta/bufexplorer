bufexplorer
===========

BufExplorer Plugin for Vim

With bufexplorer, you can quickly and easily switch between buffers by using the one of the default public interfaces:

  '\be' (normal open)  or
  '\bs' (force horizontal split open)  or
  '\bv' (force vertical split open)

Once the bufexplorer window is open you can use the normal movement keys (hjkl) to move around and then use <Enter> or <Left-Mouse-Click> to select the buffer you would like to open. If you would like to have the selected buffer opened in a new tab, simply press either <Shift-Enter> or 't'. Please note that when opening a buffer in a tab, that if the buffer is already in another tab, bufexplorer can switch to that tab automatically for you if you would like. More about that in the supplied VIM help.

Bufexplorer also offers various options including:
- Display the list of buffers in various sort orders including:
    - Most Recently Used (MRU) which is the default
    - Buffer number
    - File name
    - File extension
    - Full file path name
- Delete buffer from list

For more about options, sort orders, configuration options, etc. please see the supplied VIM help.

## vim.org
This plugin can also be found at http://www.vim.org/scripts/script.php?script_id=42.

## Installation

If you do not have a preferred installation method, I would recommend installing [vundle.vim](https://github.com/gmarik/vundle), and
then simply putting the following in your _vimrc or .vimrc file:

    Bundle 'jlanzarotta/bufexplorer'

If you do now want to use [vundle.vim](https://github.com/gmarik/vundle), you can take the zip file from vim.org and unzip it and copy the plugin to your vimfiles\plugin directory and the txt file to your vimfiles\doc directory.  If you do that, make sure you generate the help by executing

`:helptag <your runtime directory>/doc`

Once help tags have been generated, you can view the manual with
`:help bufexplorer`.

## License
Copyright (c) 2001-2013, Jeff Lanzarotta

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or
  other materials provided with the distribution.

* Neither the name of the {organization} nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
