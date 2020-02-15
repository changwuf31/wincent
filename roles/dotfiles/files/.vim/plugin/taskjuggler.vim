augroup filetypedetect
au BufNewFile,BufRead *.tjp,*.tji               setf tjp
augroup END

au! Syntax tjp          source ~/.vim/syntax/tjp.vim
