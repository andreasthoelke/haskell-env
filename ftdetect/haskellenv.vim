augroup haskellenv_commands
  au BufNewFile,BufRead *.hs runtime haskellenv/haskellenv.vim
augroup end

if filereadable('stack.yaml')
  runtime haskellenv/haskellenv.vim
endif
