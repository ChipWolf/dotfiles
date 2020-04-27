" Disable Background Color Erase (BCE) so that color schemes work
" properly within 256-color terminals
if &term =~ '256color'
      set t_ut=
endif
let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"

" Base colourscheme
colorscheme Tomorrow-Night

"Airline Theme
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
let g:airline_theme= "tomorrow"
