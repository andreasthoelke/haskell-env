if exists("g:loaded_haskellenv")
  finish
endif

let g:loaded_haskellenv = 1

augroup haskellenv_commands
  au BufNewFile,BufRead *.hs call haskellenv#start()
augroup end

if filereadable('stack.yaml')
  call haskellenv#start()
endif

" test changes
