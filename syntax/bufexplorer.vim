" Vim syntax file
" Language: bufexplorer

if exists("b:current_syntax")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match bufExplorerHelp     "^\".*" contains=bufExplorerSortBy,bufExplorerMapping,bufExplorerTitle,bufExplorerSortType,bufExplorerToggleSplit,bufExplorerToggleOpen
syn match bufExplorerOpenIn   "Open in \w\+ window" contained
syn match bufExplorerSplit    "\w\+ split" contained
syn match bufExplorerSortBy   "Sorted by .*" contained contains=bufExplorerOpenIn,bufExplorerSplit
syn match bufExplorerMapping  "\" \zs.\+\ze :" contained
syn match bufExplorerTitle    "Buffer Explorer.*" contained
syn match bufExplorerSortType "'\w\{-}'" contained
syn match bufExplorerBufNbr   /^\s*\d\+/
syn match bufExplorerToggleSplit  "toggle split type" contained
syn match bufExplorerToggleOpen   "toggle open mode" contained

syn match bufExplorerModBuf    /^\s*\d\+.\{4}+.*/
syn match bufExplorerLockedBuf /^\s*\d\+.\{3}[\-=].*/
syn match bufExplorerHidBuf    /^\s*\d\+.\{2}h.*/
syn match bufExplorerActBuf    /^\s*\d\+.\{2}a.*/
syn match bufExplorerCurBuf    /^\s*\d\+.%.*/
syn match bufExplorerAltBuf    /^\s*\d\+.#.*/
syn match bufExplorerUnlBuf    /^\s*\d\+u.*/
syn match bufExplorerInactBuf  /^\s*\d\+ \{7}.*/

hi def link bufExplorerBufNbr Number
hi def link bufExplorerMapping NonText
hi def link bufExplorerHelp Special
hi def link bufExplorerOpenIn Identifier
hi def link bufExplorerSortBy String
hi def link bufExplorerSplit NonText
hi def link bufExplorerTitle NonText
hi def link bufExplorerSortType bufExplorerSortBy
hi def link bufExplorerToggleSplit bufExplorerSplit
hi def link bufExplorerToggleOpen bufExplorerOpenIn

hi def link bufExplorerActBuf Identifier
hi def link bufExplorerAltBuf String
hi def link bufExplorerCurBuf Type
hi def link bufExplorerHidBuf Constant
hi def link bufExplorerLockedBuf Special
hi def link bufExplorerModBuf Exception
hi def link bufExplorerUnlBuf Comment
hi def link bufExplorerInactBuf Comment

let b:current_syntax = "bufexplorer"

let &cpo = s:cpo_save
unlet! s:cpo_save
