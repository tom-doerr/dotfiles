set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
Plugin 'easymotion/vim-easymotion.git'
"Plugin 'ivanov/vim-ipython'
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
Plugin 'rhysd/vim-grammarous'
Plugin 'w0rp/ale'
Plugin 'dhruvasagar/vim-table-mode'
Plugin 'vim-scripts/DrawIt'
Plugin 'lervag/vimtex'
Plugin 'szw/vim-tags'
Plugin 'junegunn/fzf'
Plugin 'junegunn/fzf.vim'
"Plugin 'ludovicchabant/vim-gutentags'
Plugin 'davidhalter/jedi-vim'
"Plugin 'deoplete-plugins/deoplete-jedi'
Plugin 'Shougo/deoplete.nvim'
Plugin 'morhetz/gruvbox'
"Plugin 'tbabej/taskwiki'
"Plugin 'farseer90718/vim-taskwarrior'
Plugin 'powerman/vim-plugin-AnsiEsc'
Plugin 'dpelle/vim-LanguageTool'
Plugin 'SirVer/ultisnips'
Plugin 'meain/vim-printer'
Plugin 'tpope/vim-surround'

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

"let g:gruvbox_italic=1
colorscheme gruvbox

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
set history=1000

"" Scroll with space
"map <Space> 
"map <S-Space> 

let g:auto_save = 1  " enable AutoSave on Vim startup
let g:auto_save_silent = 1  " do not display the auto-save notification


" Use Alt + l/h to move between tabs

nnoremap <m-l> gt
nnoremap <m-h> gT

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
"set statusline+=%{SyntasticStatuslineFlag()}
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
nnoremap <m-a> :Ag 

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
nnoremap <m-f> :split<cr> :<C-u>Unite -start-insert file_rec/async<cr>
nnoremap æ :split<cr> :<C-u>Unite -start-insert file_rec/async<cr>

" Aligning
vnoremap <silent> <Enter> :EasyAlign<cr>

" Save and close
nnoremap <m-c> ZZ
nnoremap <m-d> ZZ
nnoremap ã ZZ

" Disable automatic folding in markdown files
let g:vim_markdown_folding_disabled = 1

" Stop autoindenting bullet points
" https://stackoverflow.com/questions/46876387/vim-with-markdown-how-to-remove-blankspace-after-bullet-point
let g:vim_markdown_new_list_item_indent = 0

setlocal formatoptions=tqlnrc
set comments=b:>


let g:grammarous#use_location_list = 1

set ignorecase
set smartcase

" ALE linting 
let g:ale_enabled = 0
nmap <silent> [W <Plug>(ale_first)
nmap <silent> [w <Plug>(ale_previous)
nmap <silent> ]w <Plug>(ale_next)
nmap <silent> ]W <Plug>(ale_last)

set virtualedit=all


" Indent Python in the Google way.

setlocal indentexpr=GetGooglePythonIndent(v:lnum)

let s:maxoff = 50 " maximum number of lines to look backwards.

function GetGooglePythonIndent(lnum)

  " Indent inside parens.
  " Align with the open paren unless it is at the end of the line.
  " E.g.
  "   open_paren_not_at_EOL(100,
  "                         (200,
  "                          300),
  "                         400)
  "   open_paren_at_EOL(
  "       100, 200, 300, 400)
  call cursor(a:lnum, 1)
  let [par_line, par_col] = searchpairpos('(\|{\|\[', '', ')\|}\|\]', 'bW',
        \ "line('.') < " . (a:lnum - s:maxoff) . " ? dummy :"
        \ . " synIDattr(synID(line('.'), col('.'), 1), 'name')"
        \ . " =~ '\\(Comment\\|String\\)$'")
  if par_line > 0
    call cursor(par_line, 1)
    if par_col != col("$") - 1
      return par_col
    endif
  endif

  " Delegate the rest to the original function.
  return GetPythonIndent(a:lnum)

endfunction

let pyindent_nested_paren="&sw*2"
let pyindent_open_paren="&sw*2"

nnoremap <Leader>gc :Gcommit -v -q %:p<CR>i
nnoremap <Leader>gp :Gpush<CR>
nnoremap <Leader>gl :Gpull<CR>
set conceallevel=2

"nnoremap <Leader>b bi*<Esc>ea*<Esc>
nmap <Leader>b ysiw*

set modelines=0
set nomodeline

" FZF mappings
imap <c-x><c-p> <plug>(fzf-complete-path)
map <Leader>f :Rg<CR>
map <M-;> :Lines<CR>
map <M-s> :History<CR>

" Jedi
let g:jedi#completions_enabled = 0
autocmd FileType python setlocal completeopt-=preview

autocmd FileType markdown TableModeEnable

" Statusline
set statusline+=%f

" Latex insert todo
"map <M-t><C-o> o%todo: 
map <Leader>t <C-o> o%todo: 
map <M-r><C-o> o%todo: add reference<CR>
map <Leader>r <C-o> o%todo: add reference<CR>
map <Leader>to o. -- Tom}<C-o>I\todo[inline]{TODO: 
map <Leader>ts o. -- Tom}<C-o>I\todo[inline]{@Tom: TODO:  

" Taskwiki
map <Leader>s :TaskWikiMod +next_twt<CR>:!task rc.context=none +ACTIVE done; task rc.context=none +next_twt +PENDING start &>> /var/log/taskwiki_custom<CR><CR>:e<CR>
map <Leader>c :TaskWikiDone<CR>
map <Leader>d :!source ~/.zshrc && td<CR><CR>:e<CR>
map <Leader>D :TaskWikiDelete<CR>
map <Leader>S :TaskWikiStop<CR>:TaskWikiMod -next_twt<CR>
map <M-t> <M-j>jVs* [ ] 

autocmd BufRead * let g:auto_save = 1
"autocmd BufRead *.wiki let g:auto_save = 0

let g:languagetool_jar='/opt/languagetool/LanguageTool-4.9.1/languagetool-commandline.jar'

map <M-w> :w<CR>
map <M-e> :e<CR>

" vim-taskwarrior
let g:task_rc_override = 'rc._forcecolor=off'

imap <M-k> <C-k>

let g:vim_markdown_math = 1

" Ultisnips
let g:UltiSnipsExpandTrigger="<tab>"

" vimwiki
map <Leader>1 I =<C-o>0= 
map <Leader>2 I ==<C-o>0== 
map <Leader>3 I ===<C-o>0=== 
map <Leader>4 I ====<C-o>0==== 
let g:vimwiki_list = [{'path': '~/vimwiki/',
                      \ 'syntax': 'markdown', 'ext': '.md'}]
let g:vim_printer_print_below_keybinding = '<M-p>'
let g:vim_printer_print_above_keybinding = '<M-P>'

set viminfo='1000

let g:vimwiki_global_ext = 0

let g:tex_flavor='latex'

nnoremap <Leader>sd :setlocal spell spelllang=de<CR>
nnoremap <Leader>se :setlocal spell spelllang=en<CR>

set autochdir
