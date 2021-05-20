(local M {})

(fn escape [s] (s:gsub "[<>]" {:< "\\<" :> "\\>"}))
(fn un-escape [s] (string.gsub (string.gsub s "\\<" "<") "\\>" ">"))

(local state {:ki {} :cm {} :au {}})

(fn bind! [kind id f]
  "cache function and return the respective ex command"
  (let [id-esc (escape id)]
    (tset (. state kind) id-esc f)
    (.. "v:lua.zestExec('" kind "', '" id-esc "')")))

(fn _G.zestExec [kind id-esc ...]
  "execute function cached by zest"
  (let [f (. (. state kind) id-esc)
        id (un-escape id-esc)
        (ok? result) (pcall f ...)]
    (if (not ok?)
      (error (.. "\nzest." kind "- error while executing '" id "':\n" result))
      result)))

(fn check [kind fs ts]
  "handle nil errors during binding"
  (match [fs ts]
    [nil nil] (print (.. "zest." kind "- both sides of a binding evaluated to nil!"))
    [ x  nil] (print (.. "zest." kind "- attempt to bind nil to '" (tostring fs) "'!"))
    [nil  y ] (print (.. "zest." kind "- attempt to bind '" (tostring ts) "' to nil!"))
    _ true))

(fn M.cm [opts id ts args]
  "bind ex commands"
  (if (check :cm id ts)
    (match (type ts)
      :function
      (let [cmd (.. "com " opts " " id " :call v:lua.zestExec('cm', '" id "', " args ")")]
        (bind! :cm id ts)
        (vim.api.nvim_command cmd))
      :string
      (let [cmd (.. "com " opts " " id " " ts)]
        (vim.api.nvim_command cmd)))))

(var au-id 0)

(fn au-uid []
  (set au-id (+ 1 au-id))
  (.. "au_" au-id))

(fn M.au [events path ts]
  (if (check :au "<new-au>" ts)
    (match (type ts)
      :function
      (let [id (au-uid)
            ex (.. ":call " (bind! :au id ts))
            body (.. "au " events " " path " " ex)]
        (vim.api.nvim_command (.. "augroup " id))
        (vim.api.nvim_command "autocmd!")
        (vim.api.nvim_command body)
        (vim.api.nvim_command "augroup end"))
      :string
      (let [id (au-uid)
            body (.. "au " events " " path " " ts)]
        (vim.api.nvim_command (.. "augroup " id))
        (vim.api.nvim_command "autocmd!")
        (vim.api.nvim_command body)
        (vim.api.nvim_command "augroup end")))))

(fn M.ki [modes fs ts opts]
  "bind keymaps"
  (if (check :ki fs ts)
    (match (type ts)
      :function
      (let [ex (if (. opts :expr) (bind! :ki fs ts) (.. ":call " (bind! :ki fs ts) "<cr>"))]
        (each [m (string.gmatch modes ".")]
          (vim.api.nvim_set_keymap m fs ex opts)))
      :string
      (each [m (string.gmatch modes ".")]
        (vim.api.nvim_set_keymap m fs ts opts)))))

M
