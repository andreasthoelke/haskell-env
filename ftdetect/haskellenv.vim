augroup haskellenv_commands
  au BufNewFile,BufRead *.hs call haskellenv#start()
augroup end

if filereadable('stack.yaml')
  call haskellenv#start()
endif
