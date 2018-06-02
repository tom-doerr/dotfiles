set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
Plugin 'easymotion/vim-easymotion.git'
Plugin 'ivanov/vim-ipython'
Plugin 'scrooloose/nerdtree'
Plugin 'christoomey/vim-tmux-navigator'
Plugin 'djoshea/vim-autoread'
Plugin 'lumiliet/vim-twig'
Plugin 'vim-scripts/Txtfmt-The-Vim-Highlighter'
Plugin 'vimwiki/vimwiki'
Plugin '907th/vim-auto-save'
Plugin 'scrooloose/nerdcommenter'
Plugin 'vim-syntastic/syntastic'
Plugin 'rking/ag.vim'
Plugin 'tpope/vim-fugitive'
Plugin 'junegunn/vim-easy-align'
Plugin 'Shougo/vimproc.vim'
Plugin 'Shougo/unite.vim'
Plugin 'godlygeek/tabular'
Plugin 'plasticboy/vim-markdown'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

set clipboard=unnamedplus

set tabstop=8
set expandtab
set shiftwidth=4
set softtabstop=4

filetype indent on

" post by cdated https://stackoverflow.com/questions/2561418/how-to-comment-out-a-block-of-python-code-in-vim
vnoremap <silent> # :s/^/#/<cr>:noh<cr>
vnoremap <silent> -# :s/^#//<cr>:noh<cr>


let g:EasyMotion_do_mapping = 1 " Disable/Enable default mappings

map <Space> H<Plug>(easymotion-w)

" autosave (post by Sameer https://stackoverflow.com/questions/6991638/how-to-auto-save-a-file-every-1-second-in-vim)
" autocmd TextChanged,TextChangedI <buffer> silent write

colorscheme ron

" post by ying17zi https://stackoverflow.com/questions/6778961/alt-key-shortcuts-not-working-on-gnome-terminal-with-vim
" Alt-j/k to add a blank line
if has('gui_running')
    " the following two lines do not work in vim, but work in Gvim
    nnoremap <silent><A-j> :set paste<CR>m`o<Esc>``:set nopaste<CR>
    nnoremap <silent><A-k> :set paste<CR>m`O<Esc>``:set nopaste<CR>
else
    " these two work in vim
    " shrtcut with alt key: press Ctrl-v then Alt-k
    " ATTENTION: the following two lines should not be 
    " edited under other editors like gedit. ^[k and ^[j will be broken!
    nnoremap k :set paste<CR>m`O<Esc>``:set nopaste<CR>
    nnoremap j :set paste<CR>m`o<Esc>``:set nopaste<CR>
endif

" Alt-j/k for eight bit terminal like xterm
nnoremap <m-k> :set paste<CR>m`O<Esc>``:set nopaste<CR>
nnoremap <m-j> :set paste<CR>m`o<Esc>``:set nopaste<CR>


map <C-n> :NERDTreeToggle<CR>

set noswapfile

" Highlight search matches
set hls

" Spell checking
map <F7>  :setlocal spell spelllang=en <return>
map <F8>  :setlocal spell spelllang=de <return>

" Insert date with F3
" https://stackoverflow.com/questions/56052/best-way-to-insert-timestamp-in-vim
nmap <F3> i<C-R>=strftime("%Y-%m-%d %a %I:%M %p ")<CR><Esc>
imap <F3> <C-R>=strftime("%Y-%m-%d %a %I:%M %p ")<CR>

" Increase history size
set history=10000

"" Scroll with space
"map <Space> 
"map <S-Space> 

let g:auto_save = 1  " enable AutoSave on Vim startup
let g:auto_save_silent = 1  " do not display the auto-save notification


" Use Alt + l/h to move between tabs

nnoremap <m-l> gt
nnoremap l gt

nnoremap <m-h> gT
nnoremap h gT

inoremap <m-l> <C-O>gt
inoremap <è> <C-O>gt

inoremap <m-h> <C-O>gT
inoremap <ì> <C-O>gT

" Add shortcut to open file and close NERDTree
" https://vi.stackexchange.com/questions/3489/nerdtree-how-to-open-a-file-and-automatically-close-the-explorer-buffer
" autocmd BufEnter NERD_tree_* nmap  d<CR> <CR> :NERDTreeToggle <CR>
" autocmd BufLeave NERD_tree_* unmap d<CR>

" Tab-bar design
hi TabLine ctermfg=Black ctermbg=White
hi TabLineSel ctermfg=White ctermbg=Black

"nnoremap == mtgg=G't


" Automatically relaod vimrc
augroup myvimrc
    au!
    au BufWritePost .vimrc,_vimrc,vimrc,.gvimrc,_gvimrc,gvimrc so $MYVIMRC | if has('gui_running') | so $MYGVIMRC | endif
augroup END

" Syntastic settings
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 0
let g:syntastic_check_on_wq = 0

let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [],'passive_filetypes': [] }
nnoremap <Leader>e :SyntasticCheck<CR>
nnoremap <m-e> :SyntasticCheck<CR>
nnoremap å :SyntasticCheck<CR>

" Searching
nnoremap <Leader>s :Ag 
nnoremap <m-s> :Ag 
nnoremap s :Ag 

nmap <Leader>8 :Ag <c-r>=expand("<cword>")<cr><cr>
nmap <m-8> :Ag <c-r>=expand("<cword>")<cr><cr>
nmap ¸ :Ag <c-r>=expand("<cword>")<cr><cr>

" Searching for files
let g:unite_source_history_yank_enable = 1
try
 "let g:unite_source_rec_async_command='ag --nocolor --nogroup -g ""'
 "call unite#filters#matcher_default#use(['matcher_fuzzy'])
catch
endtry
" search a file in the filetree
nnoremap <Leader>f :split<cr> :<C-u>Unite -start-insert file_rec/async<cr>
nnoremap <m-f> :split<cr> :<C-u>Unite -start-insert file_rec/async<cr>
nnoremap æ :split<cr> :<C-u>Unite -start-insert file_rec/async<cr>

" Aligning
vnoremap <silent> <Enter> :EasyAlign<cr>

" Save and close
nnoremap <m-c> ZZ
nnoremap ã ZZ

" Disable automatic folding in markdown files
let g:vim_markdown_folding_disabled = 1

" Stop autoindenting bullet points
" https://stackoverflow.com/questions/46876387/vim-with-markdown-how-to-remove-blankspace-after-bullet-point
let g:vim_markdown_new_list_item_indent = 0
setlocal formatoptions=tqlnrc
set comments=b:>
