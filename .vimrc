" This is my vimrc based off of parrotos and https://chrisyeh96.github.io/2017/12/18/vimrc.html and rwxrob

" functions keys
map <F1> :set number!<CR>
set pastetoggle=<F2>
map <F3> :set list!<CR>
map <F4> :set cursorline!<CR>
map <F8> :set number!<CR>
map <F9> :set relativenumber!<CR>
map <F7> :set spell!<CR>
map <F12> :set fdm=indent<CR>

"Basic behavior
set number                  " turn on line numbers
set encoding=UTF8       
set mouse=                  " disable mouse support
set showmatch               " highlight matching parens and brackets
set laststatus=2            " always show statusline
set ruler                   " show line and column number of the cursor on right side of statusline


"""""Tab/indent settings
set autoindent          " copy indent from current line when starting a new line
set smartindent         " auto indents after '{'
set softtabstop=4       " backsapcing after hitting tab will delete this many spaces
set shiftwidth=4        " number of spaces to use for each step of (auto)indent
set tabstop=4           " width that a <TAB> displays as
set expandtab           " convert <TAB> to spaces

""""""Search settings

" turn off search highlight with carrage return
nnoremap <CR> :nohlsearch<CR><CR> 
set incsearch           " search as characters are entered
set hlsearch            " highlight search matches

" use filtetype based syntax highlighting
syntax on
filetype plugin indent on

colorscheme ron

" Plugins
call plug#begin('~/.vim/plugged')
    Plug 'tomlion/vim-solidity'
    Plug 'fatih/vim-go'
    Plug 'vim-pandoc/vim-pandoc'
    Plug 'rwxrob/vim-pandoc-syntax-simple'
    Plug 'tmsvg/pear-tree'
    Plug 'cespare/vim-toml'
call plug#end()

" netrw Configs
" https://www.youtube.com/watch?v=nDGhjk4Eqbc
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_winsize = 10

function! OpenToRight()
    :normal v
    let g:path=expand('%:p')
    :q!
    execute 'belowright vnew' g:path
    :normal <C-l>
endfunction

function! OpenBelow()
    :normal v
    let g:path=expand('%p')
    :q!
    execute 'belowright new' g:path
    :normal <C-l>
endfunction

function! NetrwMappings()
    " Hack to fix to make ctrl-l work properly
    noremap <buffer> <C-l> <C-w>l
    noremap <silent> <C-f> :call ToggleNetrw()<CR>
    noremap <buffer> V :call OpenToRight()<cr>
    noremap <buffer> H :call OpenBelow()<cr>
endfunction


augroup netrw_mappings
    autocmd!
    autocmd filetype netrw call NetrwMappings()
augroup END

" Allow Netrw to be toggled
function! ToggleNetrw()
    if g:NetrwIsOpen
        let i = bufnr("$")
        while (i >= 1)
            if (getbufvar(i, "&filetype") == "netrw")
                silent exe "bwipeout " . i
            endif
            let i-=1
        endwhile
        let g:NetrwIsOpen=0
    else
        let g:NetrwIsOpen=1
        silent Lexplore
    endif
endfunction

" Close Netrw if it's the only buffer open
autocmd WinEnter * if winnr('$') == 1 && getbufvar(winbufnr(winnr()), "&filetype") == "netrw" || &buftype == 'quickfix' |q|endif

" Open Netrw when you open vim
augroup ProjectDrawer
    autocmd!
    autocmd VimEnter * :call ToggleNetrw()
augroup END

let g:NetrwIsOpen=0

" Version 800 Settings
if v:version >= 800
    set listchars=space:*,trail:*,nbsp:*,extends:>,precedes:<,tab:\|>
endif

