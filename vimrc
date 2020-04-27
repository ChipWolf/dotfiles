set splitbelow
set splitright " More natural splits

set wildmenu
set wildmode=longest:full,full
set wildignore+=*/tmp/*,*.swp,*/node_modules/*,*/.git/*

set mouse=a
set incsearch
set hlsearch

set completeopt=menuone,preview,noinsert
set term=xterm-256color

" Swap files in one directory
set directory^=$HOME/.vim/swap//

" Persistent undo
set undofile
set undodir=~/.vim/undo

set backspace=indent,eol,start

inoremap § <ESC>
