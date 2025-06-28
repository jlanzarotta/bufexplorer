"============================================================================
"    Copyright: Copyright (c) 2001-2025, Jeff Lanzarotta
"               All rights reserved.
"
"               Redistribution and use in source and binary forms, with or
"               without modification, are permitted provided that the
"               following conditions are met:
"
"               * Redistributions of source code must retain the above
"                 copyright notice, this list of conditions and the following
"                 disclaimer.
"
"               * Redistributions in binary form must reproduce the above
"                 copyright notice, this list of conditions and the following
"                 disclaimer in the documentation and/or other materials
"                 provided with the distribution.
"
"               * Neither the name of the {organization} nor the names of its
"                 contributors may be used to endorse or promote products
"                 derived from this software without specific prior written
"                 permission.
"
"               THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
"               CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
"               INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
"               MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
"               DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
"               CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
"               SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
"               NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
"               LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
"               HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
"               CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
"               OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
"               EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
" Name Of File: bufexplorer.vim
"  Description: Buffer Explorer Vim Plugin
"   Maintainer: Jeff Lanzarotta (my name at gmail dot com)
" Last Changed: Friday, 11 April 2025
"      Version: See g:bufexplorer_version for version number.
"        Usage: This file should reside in the plugin directory and be
"               automatically sourced.
"
"               You may use the default keymappings of
"
"                 <Leader>be  - Opens BufExplorer
"                 <Leader>bt  - Toggles BufExplorer open or closed
"                 <Leader>bs  - Opens horizontally split window BufExplorer
"                 <Leader>bv  - Opens vertically split window BufExplorer
"
"               Or you can override the defaults and define your own mapping
"               in your vimrc file, for example:
"
"                   nnoremap <silent> <F11> :BufExplorer<CR>
"                   nnoremap <silent> <s-F11> :ToggleBufExplorer<CR>
"                   nnoremap <silent> <m-F11> :BufExplorerHorizontalSplit<CR>
"                   nnoremap <silent> <c-F11> :BufExplorerVerticalSplit<CR>
"
"               Or you can use
"
"                 ":BufExplorer"                - Opens BufExplorer
"                 ":ToggleBufExplorer"          - Opens/Closes BufExplorer
"                 ":BufExplorerHorizontalSplit" - Opens horizontally window BufExplorer
"                 ":BufExplorerVerticalSplit"   - Opens vertically split window BufExplorer
"
"               For more help see supplied documentation.
"      History: See supplied documentation.
"=============================================================================

" Exit quickly if already running or when 'compatible' is set. {{{1
if exists("g:bufexplorer_version") || &cp
    finish
endif
"1}}}

" Version number.
let g:bufexplorer_version = "7.12.0"

" Plugin Code {{{1
" Check for Vim version {{{2
if !exists("g:bufExplorerVersionWarn")
    let g:bufExplorerVersionWarn = 1
endif

" Make sure we are using the correct version of Vim. If not, do not load the
" plugin.
if v:version < 704
    if g:bufExplorerVersionWarn
        echohl WarningMsg
        echo "Sorry, bufexplorer ".g:bufexplorer_version." required Vim 7.4 or greater."
        echohl None
    endif
    finish
endif

" Command actions {{{2
let s:actions = [
        \ 'current',
        \ 'close',
        \ 'split',
        \ 'vsplit',
        \ 'above',
        \ 'below',
        \ 'left',
        \ 'right',
        \ ]

" Command-line completion function for `s:actions`.
function! s:ActionArgs(ArgLead, CmdLine, CursorPos)
    return join(s:actions, "\n")
endfunction

" Create commands {{{2
command! -nargs=? -complete=custom,<SID>ActionArgs
        \ BufExplorer :call BufExplorer(<f-args>)
command! -nargs=? -complete=custom,<SID>ActionArgs
        \ ToggleBufExplorer :call ToggleBufExplorer(<f-args>)
command! BufExplorerHorizontalSplit :call BufExplorerHorizontalSplit()
command! BufExplorerVerticalSplit :call BufExplorerVerticalSplit()

" Set {{{2
function! s:Set(var, default)
    if !exists(a:var)
        if type(a:default)
            execute "let" a:var "=" string(a:default)
        else
            execute "let" a:var "=" a:default
        endif

        return 1
    endif

    return 0
endfunction

" Naming conventions for file paths.
" Conventionally a `path` is the string of characters used to identify a file
" (ref. https://en.wikipedia.org/wiki/Path_(computing)).
" An absolute or `full` path starts from the root directory and consists of
" parent directories (if any) and a final `name` component.
" A file's `dir` (directory) is the path to the parent directory of the file.
" In general:
"
"   fullpath = dir / name
"
" Paths below the user's home directory may be abbreviated, replacing the home
" directory with `~`, e.g.:
"
"   /home/user/some/file
"   ->
"   ~/some/file
"
" `homerel` refers to paths with home-directory-relative abbreviation.
"
" `relative` refers to paths computed relative to the current working directory;
" these also include the home-directory-relative abbreviation.
"
" `rawpath` is the path as returned from `:buffers`; as such, buffers lacking
" any name are represented as `[No Name]`.
"
" Thus, for a buffer:
" - `rawpath` is the path as returned from `:buffers`.
" - `fullpath` is the absolute path to the buffer.
" - `homerelpath` is `fullpath` with the `~/` abbreviation.
" - `relativepath` is `homerelpath` with relative abbreviation.
" - `fulldir` is the absolute path to the buffer's parent directory.
" - `homereldir` is `fulldir` with the `~/` abbreviation.
" - `relativedir` is `homereldir` with relative abbreviation.

" Script variables {{{2
let s:MRU_Exclude_List = ["[BufExplorer]","__MRU_Files__","[Buf\ List]"]
let s:name = '[BufExplorer]'
" Buffer number of the BufExplorer window.
let s:bufExplorerBuffer = 0
let s:running = 0
let s:sort_by = ["number", "name", "fullpath", "mru", "extension"]
let s:didSplit = 0

" Setup the autocommands that handle stuff. {{{2
augroup BufExplorer
    autocmd!
    autocmd WinEnter        * call s:DoWinEnter()
    autocmd BufEnter        * call s:DoBufEnter()
    autocmd BufDelete       * call s:DoBufDelete()
    if exists('##TabClosed')
        autocmd TabClosed      * call s:DoTabClosed()
    endif
    autocmd BufWinEnter \[BufExplorer\] call s:Initialize()
    autocmd BufWinLeave \[BufExplorer\] call s:Cleanup()
augroup END

" AssignTabId {{{2
" Assign a `tabId` to the given tab.
function! s:AssignTabId(tabNbr)
    " Create a unique `tabId` based on the current time and an incrementing
    " counter value that helps ensure uniqueness.
    let tabId = reltimestr(reltime()) . ':' . s:tabIdCounter
    call settabvar(a:tabNbr, 'bufexp_tabId', tabId)
    let s:tabIdCounter = (s:tabIdCounter + 1) % 1000000000
    return tabId
endfunction

let s:tabIdCounter = 0

" GetTabId {{{2
" Retrieve the `tabId` for the given tab (or '' if the tab has no `tabId`).
function! s:GetTabId(tabNbr)
    return gettabvar(a:tabNbr, 'bufexp_tabId', '')
endfunction

" MRU data structure {{{2
" An MRU data structure is a dictionary that holds a circular doubly linked list
" of `item` values.  The dictionary contains three keys:
"   'head': a sentinel `item` representing the head of the list.
"   'next': a dictionary mapping an `item` to the next `item` in the list.
"   'prev': a dictionary mapping an `item` to the previous `item` in the list.
" E.g., an MRU holding buffer numbers will use `0` (an invalid buffer number) as
" `head`.  With the buffer numbers `1`, `2`, and `3`, an example MRU would be:
"
"           +--<---------<---------<---------<---------<+
"  `next`   |                                           |
"           +--> +---+ --> +---+ --> +---+ --> +---+ -->+
"  `head`        | 0 |     | 1 |     | 2 |     | 3 |
"           +<-- +---+ <-- +---+ <-- +---+ <-- +---+ <--+
"  `prev`   |                                           |
"           +->-------->--------->--------->--------->--+
"
" `head` allows the chosen sentinel item to differ in value and type; for
" example, `head` could be the string '.', allowing an MRU of strings (such as
" for `TabId` values).
"
" Note that dictionary keys are always strings.  Integers may be used, but they
" are converted to strings when used (and `keys(theDictionary)` will be a
" list of strings, not of integers).

" MRUNew {{{2
function! s:MRUNew(head)
    let [next, prev] = [{}, {}]
    let next[a:head] = a:head
    let prev[a:head] = a:head
    return { 'head': a:head, 'next': next, 'prev': prev }
endfunction

" MRULen {{{2
function! s:MRULen(mru)
    " Do not include the always-present `mru.head` item.
    return len(a:mru.next) - 1
endfunction

" MRURemoveMustExist {{{2
"   `item` must exist in `mru`.
function! s:MRURemoveMustExist(mru, item)
    let [next, prev] = [a:mru.next, a:mru.prev]
    let prevItem = prev[a:item]
    let nextItem = next[a:item]
    let next[prevItem] = nextItem
    let prev[nextItem] = prevItem
    unlet next[a:item]
    unlet prev[a:item]
endfunction

" MRURemove {{{2
"   `item` need not exist in `mru`.
function! s:MRURemove(mru, item)
    if has_key(a:mru.next, a:item)
        call s:MRURemoveMustExist(a:mru, a:item)
    endif
endfunction

" MRUAdd {{{2
function! s:MRUAdd(mru, item)
    let [next, prev] = [a:mru.next, a:mru.prev]
    let prevItem = a:mru.head
    let nextItem = next[prevItem]
    if a:item != nextItem
        call s:MRURemove(a:mru, a:item)
        let next[a:item] = nextItem
        let prev[a:item] = prevItem
        let next[prevItem] = a:item
        let prev[nextItem] = a:item
    endif
endfunction

" MRUGetItems {{{2
"   Return list of up to `maxItems` items in MRU order.
"   `maxItems == 0` => unlimited.
function! s:MRUGetItems(mru, maxItems)
    let [head, next] = [a:mru.head, a:mru.next]
    let items = []
    let item = next[head]
    while item != head
        if a:maxItems > 0 && len(items) >= a:maxItems
            break
        endif
        call add(items, item)
        let item = next[item]
    endwhile
    return items
endfunction

" MRUGetOrdering {{{2
"   Return dictionary mapping up to `maxItems` from `item` to MRU order.
"   `maxItems == 0` => unlimited.
function! s:MRUGetOrdering(mru, maxItems)
    let [head, next] = [a:mru.head, a:mru.next]
    let items = {}
    let order = 0
    let item = next[head]
    while item != head
        if a:maxItems > 0 && order >= a:maxItems
            break
        endif
        let items[item] = order
        let order = order + 1
        let item = next[item]
    endwhile
    return items
endfunction

" MRU trackers {{{2
" `.head` value for tab MRU:
let s:tabIdHead = '.'

" Track MRU buffers globally (independent of tabs).
let s:bufMru = s:MRUNew(0)

" Track MRU buffers for each tab, indexed by `tabId`.
"   `s:bufMruByTab[tabId] -> MRU structure`.
let s:bufMruByTab = {}

" Track MRU tabs for each buffer, indexed by `bufNbr`.
"   `s:tabMruByBuf[burNbr] -> MRU structure`.
let s:tabMruByBuf = {}

" MRURemoveBuf {{{2
function! s:MRURemoveBuf(bufNbr)
    call s:MRURemove(s:bufMru, a:bufNbr)
    if has_key(s:tabMruByBuf, a:bufNbr)
        let mru = s:tabMruByBuf[a:bufNbr]
        let [head, next] = [mru.head, mru.next]
        let tabId = next[head]
        while tabId != head
            call s:MRURemoveMustExist(s:bufMruByTab[tabId], a:bufNbr)
            let tabId = next[tabId]
        endwhile
        unlet s:tabMruByBuf[a:bufNbr]
    endif
endfunction

" MRURemoveTab {{{2
function! s:MRURemoveTab(tabId)
    if has_key(s:bufMruByTab, a:tabId)
        let mru = s:bufMruByTab[a:tabId]
        let [head, next] = [mru.head, mru.next]
        let bufNbr = next[head]
        while bufNbr != head
            call s:MRURemoveMustExist(s:tabMruByBuf[bufNbr], a:tabId)
            let bufNbr = next[bufNbr]
        endwhile
        unlet s:bufMruByTab[a:tabId]
    endif
endfunction

" MRUAddBufTab {{{2
function! s:MRUAddBufTab(bufNbr, tabId)
    if s:ShouldIgnore(a:bufNbr)
        return
    endif
    call s:MRUAdd(s:bufMru, a:bufNbr)
    if !has_key(s:bufMruByTab, a:tabId)
        let s:bufMruByTab[a:tabId] = s:MRUNew(0)
    endif
    let bufMru = s:bufMruByTab[a:tabId]
    call s:MRUAdd(bufMru, a:bufNbr)
    if !has_key(s:tabMruByBuf, a:bufNbr)
        let s:tabMruByBuf[a:bufNbr] = s:MRUNew(s:tabIdHead)
    endif
    let tabMru = s:tabMruByBuf[a:bufNbr]
    call s:MRUAdd(tabMru, a:tabId)
endfunction

" MRUTabForBuf {{{2
"   Return `tabId` most recently used by `bufNbr`.
"   If no `tabId` is found for `bufNbr`, return `s:tabIdHead`.
function! s:MRUTabForBuf(bufNbr)
    let tabMru = get(s:tabMruByBuf, a:bufNbr, s:alwaysEmptyTabMru)
    return tabMru.next[tabMru.head]
endfunction

" An always-empty MRU for tabs as a default when looking up
" `s:tabMruByBuf[bufNbr]` for an unknown `bufNbr`.
let s:alwaysEmptyTabMru = s:MRUNew(s:tabIdHead)

" MRUTabHasSeenBuf {{{2
"   Return true if `tabId` has ever seen `bufNbr`.
function! s:MRUTabHasSeenBuf(tabId, bufNbr)
    let mru = get(s:bufMruByTab, a:tabId, s:alwaysEmptyBufMru)
    return has_key(mru.next, a:bufNbr)
endfunction

" MRUTabShouldShowBuf {{{2
"   Return true if `tabId` should show `bufNbr`.
"   This is a function of current display modes.
function! s:MRUTabShouldShowBuf(tabId, bufNbr)
    if !g:bufExplorerShowTabBuffer
        " We are showing buffers from all tabs.
        return 1
    elseif g:bufExplorerOnlyOneTab
        " We are showing buffers that were most recently seen in this tab.
        return s:MRUTabForBuf(a:bufNbr) == a:tabId
    else
        " We are showing buffers that have ever been seen in this tab.
        return s:MRUTabHasSeenBuf(a:tabId, a:bufNbr)
    endif
endfunction

" MRUListedBuffersForTab {{{2
"   Return list of up to `maxBuffers` listed buffers in MRU order for the tab.
"   `maxBuffers == 0` => unlimited.
function! s:MRUListedBuffersForTab(tabId, maxBuffers)
    let bufNbrs = []
    let mru = get(s:bufMruByTab, a:tabId, s:alwaysEmptyBufMru)
    let [head, next] = [mru.head, mru.next]
    let bufNbr = next[head]
    while bufNbr != head
        if a:maxBuffers > 0 && len(bufNbrs) >= a:maxBuffers
            break
        endif
        if buflisted(bufNbr) && s:MRUTabShouldShowBuf(a:tabId, bufNbr)
            call add(bufNbrs, bufNbr)
        endif
        let bufNbr = next[bufNbr]
    endwhile
    return bufNbrs
endfunction

" An always-empty MRU for buffers as a default when looking up
" `s:bufMruByTab[tabId]` for an unknown `tabId`.
let s:alwaysEmptyBufMru = s:MRUNew(0)

" MRUOrderForBuf {{{2
" Return the position of `bufNbr` in the current MRU ordering.
" This is a function of the current display mode.  When showing buffers from all
" tabs, it's the global MRU order; otherwise, it the MRU order for the tab at
" BufExplorer launch.  The latter includes all buffers seen in this tab, which
" is sufficient whether `g:bufExplorerOnlyOneTab` is true or false.
function! s:MRUOrderForBuf(bufNbr)
    if !exists('s:mruOrder')
        if g:bufExplorerShowTabBuffer
            let mru = get(s:bufMruByTab, s:tabIdAtLaunch, s:alwaysEmptyBufMru)
        else
            let mru = s:bufMru
        endif
        let s:mruOrder = s:MRUGetOrdering(mru, 0)
    endif
    return get(s:mruOrder, a:bufNbr, len(s:mruOrder))
endfunction

" MRUEnsureTabId {{{2
function! s:MRUEnsureTabId(tabNbr)
    let tabId = s:GetTabId(a:tabNbr)
    if tabId == ''
        let tabId = s:AssignTabId(a:tabNbr)
        for bufNbr in tabpagebuflist(a:tabNbr)
            call s:MRUAddBufTab(bufNbr, tabId)
        endfor
    endif
    return tabId
endfunction

" MRUGarbageCollectBufs {{{2
"   Requires `s:raw_buffer_listing`.
function! s:MRUGarbageCollectBufs()
    for bufNbr in values(s:bufMru.next)
        if bufNbr != 0 && !has_key(s:raw_buffer_listing, bufNbr)
            call s:MRURemoveBuf(bufNbr)
        endif
    endfor
endfunction

" MRUGarbageCollectTabs {{{2
function! s:MRUGarbageCollectTabs()
    let numTabs = tabpagenr('$')
    let liveTabIds = {}
    for tabNbr in range(1, numTabs)
        let tabId = s:GetTabId(tabNbr)
        if tabId != ''
            let liveTabIds[tabId] = 1
        endif
    endfor
    for tabId in keys(s:bufMruByTab)
        if tabId != s:tabIdHead && !has_key(liveTabIds, tabId)
            call s:MRURemoveTab(tabId)
        endif
    endfor
endfunction

" DoWinEnter {{{2
function! s:DoWinEnter()
    let bufNbr = str2nr(expand("<abuf>"))
    let tabNbr = tabpagenr()
    let tabId = s:GetTabId(tabNbr)
    " Ignore `WinEnter` for a newly created tab; this event comes when creating
    " a new tab, and the buffer at that moment is one that is about to be
    " replaced by the buffer to which we are switching; this latter buffer will
    " be handled by the forthcoming `BufEnter` event.
    if tabId != ''
        call s:MRUAddBufTab(bufNbr, tabId)
    endif
endfunction

" DoBufEnter {{{2
function! s:DoBufEnter()
    let bufNbr = str2nr(expand("<abuf>"))
    let tabNbr = tabpagenr()
    let tabId = s:MRUEnsureTabId(tabNbr)
    call s:MRUAddBufTab(bufNbr, tabId)
endfunction

" DoBufDelete {{{2
function! s:DoBufDelete()
    let bufNbr = str2nr(expand("<abuf>"))
    call s:MRURemoveBuf(bufNbr)
endfunction

" DoTabClosed {{{2
function! s:DoTabClosed()
    call s:MRUGarbageCollectTabs()
endfunction

" ShouldIgnore {{{2
function! s:ShouldIgnore(buf)
    " Ignore temporary buffers with buftype set.
    if empty(getbufvar(a:buf, "&buftype")) == 0
        return 1
    endif

    " Ignore buffers with no name.
    if empty(bufname(a:buf)) == 1
        return 1
    endif

    " Ignore the BufExplorer buffer.
    if fnamemodify(bufname(a:buf), ":t") == s:name
        return 1
    endif

    " Ignore any buffers in the exclude list.
    if index(s:MRU_Exclude_List, bufname(a:buf)) >= 0
        return 1
    endif

    " Else return 0 to indicate that the buffer was not ignored.
    return 0
endfunction

" Initialize {{{2
function! s:Initialize()
    call s:SetLocalSettings()
    let s:running = 1
endfunction

" Cleanup {{{2
function! s:Cleanup()
    if exists("s:_insertmode")
        let &insertmode = s:_insertmode
    endif

    if exists("s:_showcmd")
        let &showcmd = s:_showcmd
    endif

    if exists("s:_cpo")
        let &cpo = s:_cpo
    endif

    if exists("s:_report")
        let &report = s:_report
    endif

    let s:running = 0
    let s:didSplit = 0

    delmarks!
endfunction

" SetLocalSettings {{{2
function! s:SetLocalSettings()
    let s:_insertmode = &insertmode
    set noinsertmode

    let s:_showcmd = &showcmd
    set noshowcmd

    let s:_cpo = &cpo
    set cpo&vim

    let s:_report = &report
    let &report = 10000

    setlocal nonumber
    setlocal foldcolumn=0
    setlocal nofoldenable
    setlocal cursorline
    setlocal nospell
    setlocal nobuflisted
    setlocal filetype=bufexplorer
endfunction

" BufExplorerHorizontalSplit {{{2
function! BufExplorerHorizontalSplit()
    call BufExplorer('split')
endfunction

" BufExplorerVerticalSplit {{{2
function! BufExplorerVerticalSplit()
    call BufExplorer('vsplit')
endfunction

" ToggleBufExplorer {{{2
" Args: `([action])`
" Optional `action` argument must be taken from `s:actions`.  If not present,
" `action` defaults to `g:bufExplorerDefaultAction`.
function! ToggleBufExplorer(...)
    if a:0 >= 1
        let action = a:1
    else
        let action = g:bufExplorerDefaultAction
    endif
    if a:0 >= 2
        echoerr 'Too many arguments'
        return
    endif

    if index(s:actions, action) < 0
        echoerr 'Invalid action ' . action
        return
    endif

    if s:running && bufnr('%') == s:bufExplorerBuffer
        let action = 'close'
    endif

    call BufExplorer(action)
endfunction

" BufExplorer {{{2
" Args: `([action])`
" Optional `action` argument must be taken from `s:actions`.  If not present,
" `action` defaults to `g:bufExplorerDefaultAction`.
function! BufExplorer(...)
    if a:0 >= 1
        let action = a:1
    else
        let action = g:bufExplorerDefaultAction
    endif
    if a:0 >= 2
        echoerr 'Too many arguments'
        return
    endif

    if index(s:actions, action) < 0
        echoerr 'Invalid action ' . action
        return
    endif

    if action == 'close'
        call s:Close()
        return
    endif

    let [tabNbr, winNbr] = s:FindBufExplorer()
    if tabNbr > 0
        execute 'keepjumps ' . tabNbr . 'tabnext'
        execute 'keepjumps ' . winNbr . 'wincmd w'
        return
    endif

    let name = s:name

    if !has("win32")
        " On non-Windows boxes, escape the name so that is shows up correctly.
        let name = escape(name, "[]")
    endif

    let s:bufNbrAtLaunch = bufnr('%')
    let s:tabIdAtLaunch = s:MRUEnsureTabId(tabpagenr())
    let s:windowAtLaunch = winnr()

    " Forget any cached MRU ordering from previous invocations.
    unlet! s:mruOrder

    let s:raw_buffer_listing = s:GetBufferInfo(0)

    call s:MRUGarbageCollectBufs()
    call s:MRUGarbageCollectTabs()

    let [splitbelow, splitright] = [g:bufExplorerSplitBelow, g:bufExplorerSplitRight]
    " `{ action: [splitMode, botRight] }`.
    let actionMap = {
            \ 'split'   : ['split', splitbelow, splitright],
            \ 'vsplit'  : ['vsplit', splitbelow, splitright],
            \ 'above'   : ['split', 0, splitright],
            \ 'below'   : ['split', 1, splitright],
            \ 'left'    : ['vsplit', splitbelow, 0],
            \ 'right'   : ['vsplit', splitbelow, 1],
            \ 'current' : ['', splitbelow, splitright],
            \}
    let [splitMode, splitbelow, splitright] = actionMap[action]

    " We may have to split the current window.
    if splitMode != ''
        " Save off the original settings.
        let [_splitbelow, _splitright] = [&splitbelow, &splitright]

        " Set the setting to ours.
        let [&splitbelow, &splitright] = [splitbelow, splitright]
        let size = splitMode == 'split' ? g:bufExplorerSplitHorzSize : g:bufExplorerSplitVertSize
        let cmd = 'keepalt '
        if size > 0
            let cmd .= size
        endif
        let cmd .= splitMode
        execute cmd

        " Restore the original settings.
        let [&splitbelow, &splitright] = [_splitbelow, _splitright]

        " Remember that a split was triggered
        let s:didSplit = 1
    endif

    if !exists("b:displayMode") || b:displayMode != "winmanager"
        " Do not use keepalt when opening bufexplorer to allow the buffer that
        " we are leaving to become the new alternate buffer
        execute "silent keepjumps hide edit".name
    endif

    " Record BufExplorer's buffer number.
    let s:bufExplorerBuffer = bufnr('%')

    call s:DisplayBufferList()

    " Position the cursor in the newly displayed list on the line representing
    " the active buffer at BufExplorer launch (assuming it is displayed).
    let activeBufIndex = index(s:displayedBufNbrs, s:bufNbrAtLaunch)
    if activeBufIndex >= 0
        let activeBufLineNbr = s:firstBufferLine + activeBufIndex
        keepjumps execute 'normal! ' . string(activeBufLineNbr) . 'G'
    endif

    if exists('#User#BufExplorer_Started')
        " Notify that BufExplorer has started.  This is an opportunity to make
        " custom buffer-local mappings and the like.
        doautocmd User BufExplorer_Started
    endif
endfunction

" Tracks buffer number at BufExplorer launch.
let s:bufNbrAtLaunch = 0

" Tracks `tabId` at BufExplorer launch.
let s:tabIdAtLaunch = ''

" Tracks window number at BufExplorer launch.
let s:windowAtLaunch = 0

" DisplayBufferList {{{2
function! s:DisplayBufferList()
    setlocal buftype=nofile
    setlocal modifiable
    setlocal noreadonly
    setlocal noswapfile
    setlocal nowrap
    setlocal bufhidden=wipe

    call s:MapKeys()

    " Wipe out any existing lines in case BufExplorer buffer exists and the
    " user had changed any global settings that might reduce the number of
    " lines needed in the buffer.
    silent keepjumps 1,$d _

    call setline(1, s:CreateHelp())
    call s:BuildBufferList()
    call cursor(s:firstBufferLine, 1)

    if !g:bufExplorerResize
        normal! zz
    endif

    setlocal nomodifiable
endfunction

" BufExplorer_redisplay {{{2
function! BufExplorer_redisplay()
    if s:running && bufnr('%') == s:bufExplorerBuffer
        call s:RedisplayBufferList()
    endif
endfunction

" RedisplayBufferList {{{2
function! s:RedisplayBufferList()
    call s:RebuildBufferList()
    call s:UpdateHelpStatus()
endfunction

" MapKeys {{{2
function! s:MapKeys()
    nnoremap <silent> <buffer> <Plug>(BufExplorer_BufferDelete)             :call <SID>RemoveBuffer("delete")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_BufferDeleteForced)       :call <SID>RemoveBuffer("force_delete")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_BufferWipe)               :call <SID>RemoveBuffer("wipe")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_BufferWipeForced)         :call <SID>RemoveBuffer("force_wipe")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_Close)                    :call <SID>Close()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_OpenBuffer)               :call <SID>SelectBuffer()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_OpenBufferAsk)            :call <SID>SelectBuffer("ask")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_OpenBufferOriginalWindow) :call <SID>SelectBuffer("original_window")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_OpenBufferSplitAbove)     :call <SID>SelectBuffer("split", "st")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_OpenBufferSplitBelow)     :call <SID>SelectBuffer("split", "sb")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_OpenBufferSplitLeft)      :call <SID>SelectBuffer("split", "vl")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_OpenBufferSplitRight)     :call <SID>SelectBuffer("split", "vr")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_OpenBufferTab)            :call <SID>SelectBuffer("tab")<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_SortByNext)               :call <SID>SortSelect()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_SortByPrev)               :call <SID>ReverseSortSelect()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_ToggleFindActive)         :call <SID>ToggleFindActive()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_ToggleHelp)               :call <SID>ToggleHelp()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_ToggleOnlyOneTab)         :call <SID>ToggleOnlyOneTab()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_ToggleReverseSort)        :call <SID>SortReverse()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_ToggleShowRelativePath)   :call <SID>ToggleShowRelativePath()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_ToggleShowTabBuffer)      :call <SID>ToggleShowTabBuffer()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_ToggleShowTerminal)       :call <SID>ToggleShowTerminal()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_ToggleShowUnlisted)       :call <SID>ToggleShowUnlisted()<CR>
    nnoremap <silent> <buffer> <Plug>(BufExplorer_ToggleSplitOutPathName)   :call <SID>ToggleSplitOutPathName()<CR>

    if exists("b:displayMode") && b:displayMode == "winmanager"
        nnoremap <buffer> <silent> <tab> :call <SID>SelectBuffer()<CR>
    endif

    nmap <nowait> <buffer> <2-leftmouse>    <Plug>(BufExplorer_OpenBuffer)
    nmap <nowait> <buffer> <CR>             <Plug>(BufExplorer_OpenBuffer)
    nmap <nowait> <buffer> <F1>             <Plug>(BufExplorer_ToggleHelp)
    nmap <nowait> <buffer> <s-cr>           <Plug>(BufExplorer_OpenBufferTab)
    nmap <nowait> <buffer> a                <Plug>(BufExplorer_ToggleFindActive)
    nmap <nowait> <buffer> b                <Plug>(BufExplorer_OpenBufferAsk)
    nmap <nowait> <buffer> B                <Plug>(BufExplorer_ToggleOnlyOneTab)
    nmap <nowait> <buffer> d                <Plug>(BufExplorer_BufferDelete)
    nmap <nowait> <buffer> D                <Plug>(BufExplorer_BufferWipe)
    nmap <nowait> <buffer> f                <Plug>(BufExplorer_OpenBufferSplitBelow)
    nmap <nowait> <buffer> F                <Plug>(BufExplorer_OpenBufferSplitAbove)
    nmap <nowait> <buffer> o                <Plug>(BufExplorer_OpenBuffer)
    nmap <nowait> <buffer> O                <Plug>(BufExplorer_OpenBufferOriginalWindow)
    nmap <nowait> <buffer> p                <Plug>(BufExplorer_ToggleSplitOutPathName)
    nmap <nowait> <buffer> q                <Plug>(BufExplorer_Close)
    nmap <nowait> <buffer> r                <Plug>(BufExplorer_ToggleReverseSort)
    nmap <nowait> <buffer> R                <Plug>(BufExplorer_ToggleShowRelativePath)
    nmap <nowait> <buffer> s                <Plug>(BufExplorer_SortByNext)
    nmap <nowait> <buffer> S                <Plug>(BufExplorer_SortByPrev)
    nmap <nowait> <buffer> t                <Plug>(BufExplorer_OpenBufferTab)
    nmap <nowait> <buffer> T                <Plug>(BufExplorer_ToggleShowTabBuffer)
    nmap <nowait> <buffer> u                <Plug>(BufExplorer_ToggleShowUnlisted)
    nmap <nowait> <buffer> v                <Plug>(BufExplorer_OpenBufferSplitRight)
    nmap <nowait> <buffer> V                <Plug>(BufExplorer_OpenBufferSplitLeft)
    nmap <nowait> <buffer> X                <Plug>(BufExplorer_ToggleShowTerminal)

    for k in ["G", "n", "N", "L", "M", "H"]
        execute "nnoremap <buffer> <silent>" k ":keepjumps normal!" k."<CR>"
    endfor
endfunction

" ToggleHelp {{{2
function! s:ToggleHelp()
    let g:bufExplorerDetailedHelp = !g:bufExplorerDetailedHelp

    setlocal modifiable

    " Save position.
    normal! ma

    " Remove old header.
    if s:firstBufferLine > 1
        execute "keepjumps 1,".(s:firstBufferLine - 1) "d _"
    endif

    call append(0, s:CreateHelp())

    silent! normal! g`a
    delmarks a

    setlocal nomodifiable

    if exists("b:displayMode") && b:displayMode == "winmanager"
        call WinManagerForceReSize("BufExplorer")
    endif
endfunction

" GetHelpStatus {{{2
function! s:GetHelpStatus()
    let ret = '" Sorted by '.((g:bufExplorerReverseSort == 1) ? "reverse " : "").g:bufExplorerSortBy
    let ret .= ' | '.((g:bufExplorerFindActive == 0) ? "Don't " : "")."Locate buffer"
    let ret .= ((g:bufExplorerShowUnlisted == 0) ? "" : " | Show unlisted")
    let ret .= ((g:bufExplorerShowTabBuffer == 0) ? "" : " | Show buffers/tab")
    let ret .= ((g:bufExplorerOnlyOneTab == 0) ? "" : " | One tab/buffer")
    let ret .= ' | '
    if g:bufExplorerShowRelativePath
        let ret .= "Relative "
    endif
    let ret .= ((g:bufExplorerSplitOutPathName == 0) ? "Whole" : "Split")." path"
    let ret .= ((g:bufExplorerShowTerminal == 0) ? "" : " | Show terminal")

    return ret
endfunction

" CreateHelp {{{2
function! s:CreateHelp()
    if g:bufExplorerDefaultHelp == 0 && g:bufExplorerDetailedHelp == 0
        let s:firstBufferLine = 1
        return []
    endif

    let header = []

    if g:bufExplorerDetailedHelp == 1
        call add(header, '" Buffer Explorer ('.g:bufexplorer_version.')')
        call add(header, '" --------------------------')
        call add(header, '" <F1> : toggle this help')
        call add(header, '" <enter> or o or Mouse-Double-Click : open buffer under cursor')
        call add(header, '" <shift-enter> or t : open buffer in another tab')
        call add(header, '" a : toggle find active buffer')
        call add(header, '" b : Fast buffer switching with b<any bufnum>')
        call add(header, '" B : toggle showing buffers only on their MRU tabs')
        call add(header, '" d : delete buffer')
        call add(header, '" D : wipe buffer')
        call add(header, '" F : open buffer in another window above the current')
        call add(header, '" f : open buffer in another window below the current')
        call add(header, '" O : open buffer in original window')
        call add(header, '" p : toggle splitting of path into name + dir')
        call add(header, '" q : quit')
        call add(header, '" r : reverse sort')
        call add(header, '" R : toggle showing relative paths')
        call add(header, '" s : cycle thru "sort by" fields '.string(s:sort_by).'')
        call add(header, '" S : reverse cycle thru "sort by" fields')
        call add(header, '" T : toggle showing all buffers/only buffers used on this tab')
        call add(header, '" u : toggle showing unlisted buffers')
        call add(header, '" V : open buffer in another window on the left of the current')
        call add(header, '" v : open buffer in another window on the right of the current')
        call add(header, '" X : toggle showing terminal buffers')
    else
        call add(header, '" Press <F1> for Help')
    endif

    if (!exists("b:displayMode") || b:displayMode != "winmanager") || (b:displayMode == "winmanager" && g:bufExplorerDetailedHelp == 1)
        call add(header, s:GetHelpStatus())
        call add(header, '"=')
    endif

    let s:firstBufferLine = len(header) + 1

    return header
endfunction

" CalculateBufferDetails {{{2
" Calculate `buf`-related details.
" Only these fields of `buf` must be defined on entry:
" - `.bufNbr`
" - `.numberindicators`
" - `.line`
function! s:CalculateBufferDetails(buf)
    let buf = a:buf
    let buf.number = string(buf.bufNbr)
    let buf.indicators = substitute(buf.numberindicators, '^\s*\d*', '', '')
    let rawpath = bufname(buf.bufNbr)
    let buf["hasNoName"] = empty(rawpath)
    if buf.hasNoName
        let rawpath = "[No Name]"
        let buf.isdir = 0
    else
        let buf.isdir = getftype(rawpath) == 'dir'
    endif
    let buf.rawpath = rawpath
    let buf.isterminal = getbufvar(buf.bufNbr, '&buftype') == 'terminal'
    if buf.isterminal
        " Neovim uses paths with `term://` prefix, where the provided dir path
        " is the current working directory when the terminal was launched, e.g.:
        " - Unix:
        "   term://~/tmp/sort//1464953:/bin/bash
        " - Windows:
        "   term://C:\apps\nvim-win64\bin//6408:C:\Windows\system32\cmd.exe
        " Vim uses paths starting with `!`, with no provided dir path, e.g.:
        " - Unix:
        "   !/bin/bash
        " - Windows:
        "   !C:\Windows\system32\cmd.exe

        " Use the terminal's current working directory as `fulldir`.
        " For `name`, use `!PID:shellName`, prefixed with `!` as Vim does,
        " and without the shell's dir path for brevity, e.g.:
        "   `/bin/bash` -> `!bash`
        "   `1464953:/bin/bash` -> `!1464953:bash`
        "   `C:\Windows\system32\cmd.exe` -> `!cmd.exe`
        "   `6408:C:\Windows\system32\cmd.exe` -> `!6408:cmd.exe`

        " Neovim-style path format:
        "   term://(cwd)//(pid):(shellPath)
        " e.g.:
        "   term://~/tmp/sort//1464953:/bin/bash
        " `cwd` is the directory at terminal launch.
        let termNameParts = matchlist(rawpath, '\v\c^term://(.*)//(\d+):(.*)$')
        if len(termNameParts) > 0
            let [cwd, pidStr, shellPath] = termNameParts[1:3]
            let pid = str2nr(pidStr)
            let shellName = fnamemodify(shellPath, ':t')
        else
            " Default to Vim's current working directory.
            let cwd = '.'
            let shellName = fnamemodify(rawpath, ':t')
            let pid = -1
            if exists('*term_getjob') && exists('*job_info')
                let job = term_getjob(buf.bufNbr)
                if job != v:null
                    let pid = job_info(job).process
                endif
            endif
        endif

        if pid < 0
            let name = '!' . shellName
        else
            let name = '!' . pid . ':' . shellName
            " On some systems having a `/proc` filesystem (e.g., Linux, *BSD,
            " Solaris), each process has a `cwd` symlink for the current working
            " directory.  `resolve()` will return the actual current working
            " directory if possible; otherwise, it will return the symlink path
            " unchanged.
            let cwd_symlink = '/proc/' . pid . '/cwd'
            let resolved_cwd = resolve(cwd_symlink)
            if resolved_cwd != cwd_symlink
                let cwd = resolved_cwd
            endif
        endif

        let slashed_cwd = fnamemodify(cwd, ':p')
        let buf.fullpath = slashed_cwd . name
        let buf.fulldir = fnamemodify(slashed_cwd, ':h')
        let buf.name = name
        let buf.homereldir = fnamemodify(slashed_cwd, ':~:h')
        let buf.homerelpath = fnamemodify(buf.fullpath, ':~')
        let buf.relativedir = fnamemodify(slashed_cwd, ':~:.:h')
        let buf.relativepath = fnamemodify(buf.fullpath, ':~:.')
        return
    endif

    let fullpath = simplify(fnamemodify(rawpath, ':p'))
    if buf.isdir
        " `fullpath` ends with a path separator; this will be
        " removed via the first `:h` applied to `fullpath` (except
        " for the root directory, where the path separator will remain).

        " Must perform shortening (`:~`, `:.`) before `:h`.
        let buf.homerelpath = fnamemodify(fullpath, ':~:h')
        let buf.relativepath = fnamemodify(fullpath, ':~:.:h')
        " Remove trailing slash.
        let fullpath = fnamemodify(fullpath, ':h')
        let parent = fnamemodify(fullpath, ':h')
        let buf.name = fnamemodify(fullpath, ':t')
        " Special case for root directory: fnamemodify('/', ':h:t') == ''
        if buf.name == ''
            let buf.name = '.'
        endif
    else
        let parent = fnamemodify(fullpath, ':h')
        let buf.name = fnamemodify(fullpath, ':t')
        let buf.homerelpath = fnamemodify(fullpath, ':~')
        let buf.relativepath = fnamemodify(fullpath, ':~:.')
    endif
    let buf.fullpath = fullpath
    let buf.fulldir = parent
    " `:p` on `parent` adds back the path separator which permits more
    " effective shortening (`:~`, `:.`), but `:h` is required afterward
    " to trim this separator.
    let buf.homereldir = fnamemodify(parent, ':p:~:h')
    let buf.relativedir = fnamemodify(parent, ':p:~:.:h')
endfunction

" GetBufferInfo {{{2
" Return dictionary `{ bufNbr : buf }`.
" - If `onlyBufNbr > 0`, dictionary will contain at most that buffer.
" On return, only these fields are set for each `buf`:
" - `.bufNbr`
" - `.numberindicators`
" - `.line`
" Other fields will be populated by `s:CalculateBufferDetails()`.
function! s:GetBufferInfo(onlyBufNbr)
    redir => bufoutput

    " Below, `:silent buffers` allows capturing the output via `:redir` but
    " prevents display to the user.

    if a:onlyBufNbr > 0 && buflisted(a:onlyBufNbr)
        " We care only about the listed buffer `a:onlyBufNbr`, so no need to
        " enumerate unlisted buffers.
        silent buffers
    else
        " Use `!` to show all buffers including the unlisted ones.
        silent buffers!
    endif
    redir END

    if a:onlyBufNbr > 0
        " Since we are only interested in this specified buffer remove the
        " other buffers listed.
        " Use a very-magic pattern starting with a newline and a run of zero or
        " more spaces/tabs:
        let onlyLinePattern = '\v\n\s*'
        " Continue with the buffer number followed by a non-digit character
        " (which will be a buffer indicator character such as `u` or ` `).
        let onlyLinePattern .= a:onlyBufNbr . '\D'
        " Finish with a run of zero or more non-newline characters plus newline:
        let onlyLinePattern .= '[^\n]*\n'
        let bufoutput = matchstr("\n" . bufoutput . "\n", onlyLinePattern)
    endif

    let all = {}

    " Loop over each line in the buffer.
    for line in split(bufoutput, '\n')
        let bits = split(line, '"')

        " Use first and last components after the split on '"', in case a
        " filename with an embedded '"' is present.
        let buf = {
                \ "numberindicators": bits[0],
                \ "line": substitute(bits[-1],
                \ '\s*', '', '')
                \}
        let buf.bufNbr = str2nr(buf.numberindicators)
        let all[buf.bufNbr] = buf
    endfor

    return all
endfunction

" BuildBufferList {{{2
function! s:BuildBufferList()
    if exists('#User#BufExplorer_PreDisplay')
        " Notify that BufExplorer is about to display the buffer list.  This is
        " an opportunity to make last-minute changes to `g:bufExplorerColumns`.
        doautocmd User BufExplorer_PreDisplay
    endif

    let columns = s:GetColumns()
    let table = []
    let s:displayedBufNbrs = []

    " Loop through every buffer.
    for buf in values(s:raw_buffer_listing)
        " `buf.numberindicators` must exist, but we defer the expensive work of
        " calculating other buffer details (e.g., `buf.fullpath`) until we know
        " the user wants to view this buffer.

        " Skip BufExplorer's buffer.
        if buf.bufNbr == s:bufExplorerBuffer
            continue
        endif

        " Skip unlisted buffers if we are not to show them.
        if !g:bufExplorerShowUnlisted && buf.numberindicators =~ "u"
            " Skip unlisted buffers if we are not to show them.
            continue
        endif

        " Ensure buffer details are computed for this buffer.
        if !has_key(buf, 'fullpath')
            call s:CalculateBufferDetails(buf)
        endif

        " Skip 'No Name' buffers if we are not to show them.
        if g:bufExplorerShowNoName == 0 && buf.hasNoName
            continue
        endif

        " Should we show this buffer in this tab?
        if !s:MRUTabShouldShowBuf(s:tabIdAtLaunch, buf.bufNbr)
            continue
        endif

        " Skip terminal buffers if we are not to show them.
        if !g:bufExplorerShowTerminal && buf.isterminal
            continue
        endif

        " Skip directory buffers if we are not to show them.
        if !g:bufExplorerShowDirectories && buf.isdir
            continue
        endif

        let row = []
        for column in columns
            if has_key(buf, column)
                let row += [buf[column]]
            elseif column == 'icon'
                " Support must exist or 'icon' would have been removed.
                let row += [WebDevIconsGetFileTypeSymbol(buf.fullpath, buf.isdir)]
            else
                " Must be of the form `=literal`.
                let row += [column[1:]]
            endif
        endfor

        call add(table, row)
        call add(s:displayedBufNbrs, buf.bufNbr)
    endfor

    let lines = s:MakeLines(table)
    call setline(s:firstBufferLine, lines)
    let firstMissingLine = s:firstBufferLine + len(lines)
    if line('$') >= firstMissingLine
        " Clear excess lines starting with `firstMissingLine`.
        execute "silent keepjumps ".firstMissingLine.',$d _'
    endif
    call s:SortListing()
endfunction

" Buffer numbers for buffers displayed in the BufExplorer window.
let s:displayedBufNbrs = []

" GetColumns {{{2
function! s:GetColumns()
    let validColumns = [
            \ 'dir',
            \ 'fulldir',
            \ 'fullpath',
            \ 'homereldir',
            \ 'homerelpath',
            \ 'icon',
            \ 'indicators',
            \ 'line',
            \ 'name',
            \ 'number',
            \ 'numberindicators',
            \ 'path',
            \ 'rawpath',
            \ 'relativedir',
            \ 'relativepath',
            \ 'splittablepath',
            \ ]
    let columns = []
    for column in g:bufExplorerColumns
        if column == 'splittablepath'
            if g:bufExplorerSplitOutPathName
                let columns += ['name']
                let column = 'dir'
            else
                let column = 'path'
            endif
        endif
        if column == 'dir' || column == 'path'
            if g:bufExplorerShowRelativePath
                let column = 'relative' . column
            else
                let column = 'homerel' . column
            endif
        endif
        if column == 'icon'
            " 'icon' is always valid, but omitted unless support is loaded.
            if exists("g:loaded_webdevicons")
                let columns += [column]
            endif
        elseif index(validColumns, column) >= 0 || column =~# '^='
            let columns += [column]
        else
            let columns += ['=[bad column name "' . column . '"]']
        endif
    endfor
    if len(columns) == 0
        let columns = ['=[`g:bufExplorerColumns` is empty]']
    endif
    return columns
endfunction

" BufExplorer_defaultColumns {{{2
" User-accessible default value for `g:bufExplorerColumns`.
" Implemented as a function so that users may modify the returned list.
function! BufExplorer_defaultColumns()
    let defaultColumns = [
            \   'numberindicators',
            \   'icon',
            \   'splittablepath',
            \   'line',
            \ ]
    return defaultColumns
endfunction

" MakeLines {{{2
function! s:MakeLines(table)
    if len(a:table) == 0
        return []
    endif
    let lines = []
    " To avoid trailing whitespace, do not pad the final column.
    let numColumnsToPad = len(a:table[0]) - 1
    " Ensure correctness even if `table` has no columns.
    if numColumnsToPad < 0
        let numColumnsToPad = 0
    endif
    let maxWidths = repeat([0], numColumnsToPad)
    for row in a:table
        let i = 0
        while i < numColumnsToPad
            let maxWidths[i] = max([maxWidths[i], s:StringWidth(row[i])])
            let i = i + 1
        endwhile
    endfor

    let pads = []
    for w in maxWidths
        call add(pads, repeat(' ', w))
    endfor

    for row in a:table
        let i = 0
        while i < numColumnsToPad
            let row[i] .= strpart(pads[i], s:StringWidth(row[i]))
            let i = i + 1
        endwhile
        call add(lines, join(row, ' '))
    endfor
    return lines
endfunction

" SelectBuffer {{{2
" Valid arguments:
"   `()`                    Open in current window.
"   `("ask")`               Prompt for buffer, then open in current window.
"   `("original_window")`   Open in original window.
"   `("split", "st")`       Open in horizontal split above current window.
"   `("split", "sb")`       Open in horizontal split below current window.
"   `("split", "vl")`       Open in vertical split left of current window.
"   `("split", "vr")`       Open in vertical split right of current window.
"   `("tab")`               Open in a new tab.
function! s:SelectBuffer(...)
    " Sometimes messages are not cleared when we get here so it looks like an
    " error has occurred when it really has not.
    "echo ""

    let bufNbr = -1

    if (a:0 == 1) && (a:1 == "ask")
        " Ask the user for input.
        call inputsave()
        let cmd = input("Enter buffer number to switch to: ")
        call inputrestore()

        " Clear the message area from the previous prompt.
        redraw | echo

        if strlen(cmd) > 0
            let bufNbr = str2nr(cmd)
        else
            call s:Error("Invalid buffer number, try again.")
            return
        endif
    else
        let bufNbr = s:GetBufNbrAtCursor()
        if bufNbr == 0
            return
        endif

        " Check and see if we are running BufferExplorer via WinManager.
        if exists("b:displayMode") && b:displayMode == "winmanager"
            let _bufName = expand("#".bufNbr.":p")

            if (a:0 == 1) && (a:1 == "tab")
                call WinManagerFileEdit(_bufName, 1)
            else
                call WinManagerFileEdit(_bufName, 0)
            endif

            return
        endif
    endif

    if bufexists(bufNbr)
        " Get the tab number where this buffer is located in.
        let tabNbr = s:GetTabNbr(bufNbr)
        if exists("g:bufExplorerChgWin") && g:bufExplorerChgWin <=winnr("$")
            execute g:bufExplorerChgWin."wincmd w"
            execute "keepjumps keepalt silent b!" bufNbr

        " Are we supposed to open the selected buffer in a tab?
        elseif (a:0 == 1) && (a:1 == "tab")
            call s:Close()

            " Open a new tab with the selected buffer in it.
            if v:version > 704 || ( v:version == 704 && has('patch2237') )
                " new syntax for last tab as of 7.4.2237
                execute "$tab split +buffer" . bufNbr
            else
                execute "999tab split +buffer" . bufNbr
            endif
        " Are we supposed to open the selected buffer in a split?
        elseif (a:0 == 2) && (a:1 == "split")
            call s:Close()
            if (a:2 == "vl")
                execute "vert topleft sb ".bufNbr
            elseif (a:2 == "vr")
                execute "vert belowright sb ".bufNbr
            elseif (a:2 == "st")
                execute "topleft sb ".bufNbr
            else " = sb
                execute "belowright sb ".bufNbr
            endif
        " Are we supposed to open the selected buffer in the original window?
        elseif (a:0 == 1) && (a:1 == "original_window")
            call s:Close()
            execute s:windowAtLaunch . "wincmd w"
            execute "keepjumps keepalt silent b!" bufNbr
        else
            " Request to open in current (BufExplorer) window.
            if g:bufExplorerFindActive && tabNbr > 0
                " Close BufExplorer window and switch to existing tab/window.
                call s:Close()
                execute tabNbr . "tabnext"
                execute bufwinnr(bufNbr) . "wincmd w"
            else
                " Use BufExplorer window for the buffer.
                execute "keepjumps keepalt silent b!" bufNbr
            endif
        endif

        " Make the buffer 'listed' again.
        call setbufvar(bufNbr, "&buflisted", "1")

        " Call any associated function references. g:bufExplorerFuncRef may be
        " an individual function reference or it may be a list containing
        " function references. It will ignore anything that's not a function
        " reference.
        "
        " See  :help FuncRef  for more on function references.
        if exists("g:BufExplorerFuncRef")
            if type(g:BufExplorerFuncRef) == 2
                keepj call g:BufExplorerFuncRef()
            elseif type(g:BufExplorerFuncRef) == 3
                for FncRef in g:BufExplorerFuncRef
                    if type(FncRef) == 2
                        keepj call FncRef()
                    endif
                endfor
            endif
        endif
    else
        call s:Error("Sorry, that buffer no longer exists, please select another")
        call s:DeleteBuffer(bufNbr, "wipe")
    endif
endfunction

" RemoveBuffer {{{2
" Valid `mode` values:
" - "delete"
" - "force_delete"
" - "wipe"
" - "force_wipe"
function! s:RemoveBuffer(mode)
    " Are we on a line with a file name?
    if line('.') < s:firstBufferLine
        return
    endif

    let mode = a:mode
    let forced = mode =~# '^force_'

    " These commands are to temporarily suspend the activity of winmanager.
    if exists("b:displayMode") && b:displayMode == "winmanager"
        call WinManagerSuspendAUs()
    end

    let bufNbr = s:GetBufNbrAtCursor()
    if bufNbr == 0
        return
    endif
    let buf = s:raw_buffer_listing[bufNbr]

    if !forced && (buf.isterminal || getbufvar(bufNbr, '&modified'))
        if buf.isterminal
            let msg = "Buffer " . bufNbr . " is a terminal"
        else
            let msg = "No write since last change for buffer " . bufNbr
        endif
        " Calling confirm() requires Vim built with dialog option.
        if !has("dialog_con") && !has("dialog_gui")
            call s:Error(msg . "; cannot remove without 'force'")
            return
        endif

        let answer = confirm(msg . "; Remove anyway?", "&Yes\n&No", 2)

        if answer == 1
            let mode = 'force_' . mode
        else
            return
        endif

    endif

    " Okay, everything is good, delete or wipe the buffer.
    call s:DeleteBuffer(bufNbr, mode)

    " Reactivate winmanager autocommand activity.
    if exists("b:displayMode") && b:displayMode == "winmanager"
        call WinManagerForceReSize("BufExplorer")
        call WinManagerResumeAUs()
    end
endfunction

" DeleteBuffer {{{2
" Valid `mode` values:
" - "delete"
" - "force_delete"
" - "wipe"
" - "force_wipe"
function! s:DeleteBuffer(bufNbr, mode)
    " This routine assumes that the buffer to be removed is on the current line.
    if a:mode =~# 'delete$' && bufexists(a:bufNbr) && !buflisted(a:bufNbr)
        call s:Error('Buffer ' . a:bufNbr
                \ . ' is unlisted; must `wipe` to remove')
        return
    endif
    try
        " Wipe/Delete buffer from Vim.
        if a:mode == "wipe"
            execute "silent bwipe" a:bufNbr
        elseif a:mode == "force_wipe"
            execute "silent bwipe!" a:bufNbr
        elseif a:mode == "force_delete"
            execute "silent bdelete!" a:bufNbr
        else
            execute "silent bdelete" a:bufNbr
        endif
    catch
        call s:Error(v:exception)
    endtry

    if bufexists(a:bufNbr)
        " Buffer is still present.  We may have failed to wipe it, or it may
        " have changed indicators (as `:bd` only makes a buffer unlisted).
        " Regather information on this buffer, update the buffer list, and
        " redisplay.
        let info = s:GetBufferInfo(a:bufNbr)
        let s:raw_buffer_listing[a:bufNbr] = info[a:bufNbr]
        call s:RedisplayBufferList()
    else
        " Delete the buffer from the list on screen.
        setlocal modifiable
        normal! "_dd
        setlocal nomodifiable

        " Delete the buffer from the raw buffer list.
        unlet s:raw_buffer_listing[a:bufNbr]
        " Remove buffer number from list of displayed buffer numbers.
        call remove(s:displayedBufNbrs, index(s:displayedBufNbrs, a:bufNbr))
    endif
endfunction

" Close {{{2
function! s:Close()
    let [tabNbr, winNbr] = s:FindBufExplorer()
    if tabNbr == 0
        return
    endif
    let [curTabNbr, curWinNbr] = [tabpagenr(), winnr()]
    if [tabNbr, winNbr] != [curTabNbr, curWinNbr]
        " User has switched away from the original BufExplorer window.
        " It's unclear how to do better than simply wiping out the
        " BufExplorer buffer.
        execute 'bwipeout ' . s:bufExplorerBuffer
        return
    endif
    " Get only the listed buffers associated with the current tab (up to 2).
    let listed = s:MRUListedBuffersForTab(s:tabIdAtLaunch, 2)

    " If we needed to split the main window, close the split one.
    if s:didSplit
        execute "wincmd c"
    endif

    " Check to see if there are anymore buffers listed.
    if len(listed) == 0
        " Since there are no buffers left to switch to, open a new empty
        " buffers.
        execute "enew"
    else
        " Since there are buffers left to switch to, switch to the previous and
        " then the current.
        for b in reverse(listed[0:1])
            execute "keepjumps silent b ".b
        endfor
    endif

    " Clear any messages.
    echo
endfunction

" FindBufExplorer {{{2
" Return `[tabNbr, winNbr]`; both numbers will be zero if not found.
function! s:FindBufExplorer()
    let result = [0, 0]
    if s:running
        let numTabs = tabpagenr('$')
        for tabNbr in range(1, numTabs)
            let winNbr = index(tabpagebuflist(tabNbr), s:bufExplorerBuffer) + 1
            if winNbr > 0
                let result = [tabNbr, winNbr]
                break
            endif
        endfor
    endif
    return result
endfunction

" ToggleShowTerminal {{{2
function! s:ToggleShowTerminal()
    let g:bufExplorerShowTerminal = !g:bufExplorerShowTerminal
    call s:RedisplayBufferList()
endfunction

" ToggleSplitOutPathName {{{2
function! s:ToggleSplitOutPathName()
    let g:bufExplorerSplitOutPathName = !g:bufExplorerSplitOutPathName
    call s:RedisplayBufferList()
endfunction

" ToggleShowRelativePath {{{2
function! s:ToggleShowRelativePath()
    let g:bufExplorerShowRelativePath = !g:bufExplorerShowRelativePath
    call s:RedisplayBufferList()
endfunction

" ToggleShowTabBuffer {{{2
function! s:ToggleShowTabBuffer()
    " Forget any cached MRU ordering, as it depends on
    " `g:bufExplorerShowTabBuffer`.
    unlet! s:mruOrder
    let g:bufExplorerShowTabBuffer = !g:bufExplorerShowTabBuffer
    call s:RedisplayBufferList()
endfunction

" ToggleOnlyOneTab {{{2
function! s:ToggleOnlyOneTab()
    let g:bufExplorerOnlyOneTab = !g:bufExplorerOnlyOneTab
    call s:RedisplayBufferList()
endfunction

" ToggleShowUnlisted {{{2
function! s:ToggleShowUnlisted()
    let g:bufExplorerShowUnlisted = !g:bufExplorerShowUnlisted
    call s:RedisplayBufferList()
endfunction

" ToggleFindActive {{{2
function! s:ToggleFindActive()
    let g:bufExplorerFindActive = !g:bufExplorerFindActive
    call s:UpdateHelpStatus()
endfunction

" RebuildBufferList {{{2
function! s:RebuildBufferList()
    setlocal modifiable

    let curPos = getpos('.')

    let num_bufs = s:BuildBufferList()

    call setpos('.', curPos)

    setlocal nomodifiable

    return num_bufs
endfunction

" UpdateHelpStatus {{{2
function! s:UpdateHelpStatus()
    setlocal modifiable

    let text = s:GetHelpStatus()
    call setline(s:firstBufferLine - 2, text)

    setlocal nomodifiable
endfunction

" Key_number {{{2
function! s:Key_number(buf)
    let key = [printf('%020d', a:buf.bufNbr)]
    return key
endfunction

" Key_name {{{2
function! s:Key_name(buf)
    let key = [a:buf.name, a:buf.fullpath]
    return key
endfunction

" Key_fullpath {{{2
function! s:Key_fullpath(buf)
    let key = [a:buf.fullpath]
    return key
endfunction

" Key_extension {{{2
function! s:Key_extension(buf)
    let extension = fnamemodify(a:buf.name, ':e')
    let key = [extension, a:buf.name, a:buf.fullpath]
    return key
endfunction

" Key_mru {{{2
function! s:Key_mru(buf)
    let pos = s:MRUOrderForBuf(a:buf.bufNbr)
    return [printf('%9d', pos), a:buf.fullpath]
endfunction

" SortByKeyFunc {{{2
function! s:SortByKeyFunc(keyFunc)
    let lastLineNbr = s:firstBufferLine + len(s:displayedBufNbrs) - 1
    " `s:firstBufferLine >= 1`, `lastLineNbr >= 0`; `getline(1, 0) -> []`.
    let displayedLines = getline(s:firstBufferLine, lastLineNbr)
    let bufLineIndex = 0
    let keyedLines = []
    for bufNbr in s:displayedBufNbrs
        let buf = s:raw_buffer_listing[bufNbr]
        let key = eval(a:keyFunc . '(buf)')
        let parts = key + [string(bufNbr), string(bufLineIndex)]
        call add(keyedLines, join(parts, "\1"))
        let bufLineIndex += 1
    endfor

    " Ignore case when sorting by passing `1`:
    call sort(keyedLines, 1)

    if g:bufExplorerReverseSort
        call reverse(keyedLines)
    endif

    let s:displayedBufNbrs = []
    let lines = []
    for keyedLine in keyedLines
        let parts = split(keyedLine, "\1")
        let [bufNbrStr, bufLineIndexStr] = parts[-2:-1]
        call add(s:displayedBufNbrs, str2nr(bufNbrStr))
        call add(lines, displayedLines[str2nr(bufLineIndexStr)])
    endfor

    call setline(s:firstBufferLine, lines)
endfunction

" SortReverse {{{2
function! s:SortReverse()
    let g:bufExplorerReverseSort = !g:bufExplorerReverseSort
    call s:ReSortListing()
endfunction

" SortSelect {{{2
function! s:SortSelect()
    let g:bufExplorerSortBy = get(s:sort_by, index(s:sort_by, g:bufExplorerSortBy) + 1, s:sort_by[0])
    call s:ReSortListing()
endfunction

" ReverseSortSelect {{{2
function! s:ReverseSortSelect()
    let g:bufExplorerSortBy = get(s:sort_by, index(s:sort_by, g:bufExplorerSortBy) - 1, s:sort_by[-1])
    call s:ReSortListing()
endfunction

" ReSortListing {{{2
function! s:ReSortListing()
    setlocal modifiable

    let curPos = getpos('.')

    call s:SortListing()
    call s:UpdateHelpStatus()

    call setpos('.', curPos)

    setlocal nomodifiable
endfunction

" SortListing {{{2
function! s:SortListing()
    call s:SortByKeyFunc("<SID>Key_" . g:bufExplorerSortBy)
endfunction

" GetBufNbrAtCursor {{{2
" Return `bufNbr` at cursor; return 0 if no buffer on that line.
function! s:GetBufNbrAtCursor()
    return s:GetBufNbrAtLine(line('.'))
endfunction

" GetBufNbrAtLine {{{2
" Return `bufNbr` at `lineNbr`; return 0 if no buffer on that line.
function! s:GetBufNbrAtLine(lineNbr)
    let bufIndex = a:lineNbr - s:firstBufferLine
    if bufIndex < 0 || bufIndex >= len(s:displayedBufNbrs)
        return 0
    endif
    return s:displayedBufNbrs[bufIndex]
endfunction

" BufferNumLines {{{2
" Return number of lines in the BufExplorer buffer.
function! s:BufferNumLines()
    " `line('$')` returns the line number of the last line in a buffer.
    " Normally, this is the same as the number of lines in the buffer.  When
    " there are no lines in the buffer, logically `line('$')` should return
    " zero, but Vim unfortunately returns 1 for this case.  This is because
    " there must always be a valid line number for the cursor.
    "
    " When `line('$') == 1`, we detect an empty buffer by seeing if the first
    " line itself is empty.  Technically, this cannot distinguish a completely
    " empty buffer from a one-line buffer with no characters on the first line,
    " but BufExplorer doesn't create empty lines in the buffer.
    let numLines = line('$')
    if numLines == 1 && getline(1) == ''
        let numLines = 0
    endif
    return numLines
endfunction

" Error {{{2
" Display a message using ErrorMsg highlight group.
function! s:Error(msg)
    echohl ErrorMsg
    echomsg a:msg
    echohl None
endfunction

" Warning {{{2
" Display a message using WarningMsg highlight group.
function! s:Warning(msg)
    echohl WarningMsg
    echomsg a:msg
    echohl None
endfunction

" GetTabNbr {{{2
function! s:GetTabNbr(bufNbr)
    " Prefer current tab.
    if bufwinnr(a:bufNbr) > 0
        return tabpagenr()
    endif
    " Searching buffer bufno, in tabs.
    for i in range(tabpagenr("$"))
        if index(tabpagebuflist(i + 1), a:bufNbr) != -1
            return i + 1
        endif
    endfor

    return 0
endfunction

" GetWinNbr" {{{2
function! s:GetWinNbr(tabNbr, bufNbr)
    " window number in tabpage.
    let tablist = tabpagebuflist(a:tabNbr)
    " Number:     0
    " String:     1
    " Funcref:    2
    " List:       3
    " Dictionary: 4
    " Float:      5
    if type(tablist) == 3
        return index(tabpagebuflist(a:tabNbr), a:bufNbr) + 1
    else
        return 1
    endif
endfunction

" StringWidth" {{{2
if exists('*strwidth')
    function s:StringWidth(s)
        return strwidth(a:s)
    endfunction
else
    function s:StringWidth(s)
        return len(a:s)
    endfunction
endif

" Winmanager Integration {{{2
let g:BufExplorer_title = "\[Buf\ List\]"
call s:Set("g:bufExplorerResize", 1)
call s:Set("g:bufExplorerMaxHeight", 25) " Handles dynamic resizing of the window.

" Evaluate a Vimscript expression in the context of this file.
" This enables debugging of script-local variables and functions from outside
" the plugin, e.g.:
"   :echo BufExplorer_eval('s:bufMru')
function! BufExplorer_eval(expr)
    return eval(a:expr)
endfunction

" Execute a Vimscript statement in the context of this file.
" This enables setting script-local variables from outside the plugin, e.g.:
"   :call BufExplorer_execute('let s:bufMru = s:MRUNew(0)')
function! BufExplorer_execute(statement)
    execute a:statement
endfunction

" function! to start display. Set the mode to 'winmanager' for this buffer.
" This is to figure out how this plugin was called. In a standalone fashion
" or by winmanager.
function! BufExplorer_Start()
    let b:displayMode = "winmanager"
    call s:SetLocalSettings()
    call BufExplorer()
endfunction

" Returns whether the display is okay or not.
function! BufExplorer_IsValid()
    return 0
endfunction

" Handles dynamic refreshing of the window.
function! BufExplorer_Refresh()
    let b:displayMode = "winmanager"
    call s:SetLocalSettings()
    call BufExplorer()
endfunction

function! BufExplorer_ReSize()
    if !g:bufExplorerResize
        return
    end

    let nlines = min([line("$"), g:bufExplorerMaxHeight])

    execute nlines." wincmd _"

    " The following lines restore the layout so that the last file line is also
    " the last window line. Sometimes, when a line is deleted, although the
    " window size is exactly equal to the number of lines in the file, some of
    " the lines are pushed up and we see some lagging '~'s.
    let pres = getpos(".")

    normal! $

    let _scr = &scrolloff
    let &scrolloff = 0

    normal! z-

    let &scrolloff = _scr

    call setpos(".", pres)
endfunction

" Default values {{{2
call s:Set("g:bufExplorerColumns", BufExplorer_defaultColumns()) " Configurable list of column names for the buffer list.
call s:Set("g:bufExplorerDisableDefaultKeyMapping", 0)  " Do not disable default key mappings.
call s:Set("g:bufExplorerDefaultAction", 'current')     " Default action for `:BufExplorer` with no args.
call s:Set("g:bufExplorerDefaultHelp", 1)               " Show default help?
call s:Set("g:bufExplorerDetailedHelp", 0)              " Show detailed help?
call s:Set("g:bufExplorerFindActive", 1)                " When selecting an active buffer, take you to the window where it is active?
call s:Set("g:bufExplorerOnlyOneTab", 1)                " Show buffer only on MRU tab? (Applies when `g:bufExplorerShowTabBuffer` is true.)
call s:Set("g:bufExplorerReverseSort", 0)               " Sort in reverse order by default?
call s:Set("g:bufExplorerShowDirectories", 1)           " (Dir's are added by commands like ':e .')
call s:Set("g:bufExplorerShowRelativePath", 0)          " Show listings with relative or absolute paths?
call s:Set("g:bufExplorerShowTabBuffer", 0)             " Show only buffer(s) for this tab?
call s:Set("g:bufExplorerShowUnlisted", 0)              " Show unlisted buffers?
call s:Set("g:bufExplorerShowNoName", 0)                " Show 'No Name' buffers?
call s:Set("g:bufExplorerSortBy", "mru")                " Sorting methods are in s:sort_by:
call s:Set("g:bufExplorerSplitBelow", &splitbelow)      " Should horizontal splits be below or above current window?
call s:Set("g:bufExplorerSplitOutPathName", 1)          " Split out path and file name?
call s:Set("g:bufExplorerSplitRight", &splitright)      " Should vertical splits be on the right or left of current window?
call s:Set("g:bufExplorerSplitVertSize", 0)             " Height for a vertical split. If <=0, default Vim size is used.
call s:Set("g:bufExplorerSplitHorzSize", 0)             " Height for a horizontal split. If <=0, default Vim size is used.
call s:Set("g:bufExplorerShowTerminal", 1)              " Show terminal buffers?

" Default key mapping {{{2
if !hasmapto('BufExplorer') && g:bufExplorerDisableDefaultKeyMapping == 0
    nnoremap <script> <silent> <unique> <Leader>be :BufExplorer<CR>
endif

if !hasmapto('ToggleBufExplorer') && g:bufExplorerDisableDefaultKeyMapping == 0
    nnoremap <script> <silent> <unique> <Leader>bt :ToggleBufExplorer<CR>
endif

if !hasmapto('BufExplorerHorizontalSplit') && g:bufExplorerDisableDefaultKeyMapping == 0
    nnoremap <script> <silent> <unique> <Leader>bs :BufExplorerHorizontalSplit<CR>
endif

if !hasmapto('BufExplorerVerticalSplit') && g:bufExplorerDisableDefaultKeyMapping == 0
    nnoremap <script> <silent> <unique> <Leader>bv :BufExplorerVerticalSplit<CR>
endif

" vim:ft=vim foldmethod=marker sw=4
