;;; chinese-pyim-core.el --- The core of Chinese pinyin input method

;; * Header
;; Copyright 2006 Ye Wenbin
;;           2014-2016 Feng Shu

;; Author: Ye Wenbin <wenbinye@163.com>, Feng Shu <tumashu@163.com>
;; URL: https://github.com/tumashu/chinese-pyim
;; Version: 1.0
;; Package-Requires: ((cl-lib "0.5") (pos-tip "0.4") (popup "0.1") (async "1.6"))
;; Keywords: convenience, Chinese, pinyin, input-method

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary:

;; * 说明文档                                                           :doc:
;; Chinese pyim 输入法的核心文件，包含了输入法的基本功能函数，比如：
;; 1. 加载和搜索词库
;; 2. 处理拼音字符串
;; 3. 处理备选词条
;; 4. 显示备选词条
;; 5. 其它

;;; Code:

;; * 核心代码                                                           :code:
;; ** require + defcustom + defvar
;; #+BEGIN_SRC emacs-lisp
(require 'cl-lib)
(require 'help-mode)
(require 'pos-tip)
(require 'popup)
(require 'async)
(require 'chinese-pyim-pymap)

(defgroup chinese-pyim nil
  "Chinese pinyin input method"
  :group 'leim)

(defcustom pyim-directory (locate-user-emacs-file "pyim/")
  "一个目录，用于保存与 Chinese-pyim 相关的文件。"
  :group 'chinese-pyim)

(defcustom pyim-dcache-directory (locate-user-emacs-file "pyim/cache")
  "一个目录，用于保存 Chinese-pyim 词库对应的 cache 文件。"
  :group 'chinese-pyim)

(defcustom pyim-personal-file
  (concat (file-name-as-directory pyim-directory)
          "pyim-personal.txt")
  "这个文件用来保存用户曾经输入过的中文词条，和这些词条输入的先后顺序。"
  :group 'chinese-pyim
  :type 'file)

(defcustom pyim-property-file
  (concat (file-name-as-directory pyim-directory)
          "pyim-words-property.txt")
  "这个文件用来保存已输入中文词条的其他有用属性。"
  :group 'chinese-pyim
  :type 'file)

(defcustom pyim-dicts nil
  "一个列表，用于保存 `Chinese-pyim' 的词库信息，每一个 element 都代表一条词库的信息。
用户可以使用词库管理命令 `pyim-dicts-manager' 来添加词库信息，每一条词库信息都使用一个
plist 来表示，比如：

    (:name \"100万大词库\" :file \"/path/to/pinyin-bigdict.txt\")

其中：
1. `:name'      代表词库名称，用户可以按照喜好来确定（可选项）。
2. `:file'      表示词库文件，

另外一个与这个变量功能类似的变量是： `pyim-extra-dicts', 专门
用于和 elpa 格式的词库包集成。"
  :group 'chinese-pyim
  :type 'list)

(defcustom pyim-punctuation-dict
  '(("'" "‘" "’")
    ("\"" "“" "”")
    ("_" "―")
    ("^" "…")
    ("]" "】")
    ("[" "【")
    ("@" "◎")
    ("?" "？")
    (">" "》")
    ("=" "＝")
    ("<" "《")
    (";" "；")
    (":" "：")
    ("/" "、")
    ("." "。")
    ("-" "－")
    ("," "，")
    ("+" "＋")
    ("*" "×")
    (")" "）")
    ("(" "（")
    ("&" "※")
    ("%" "％")
    ("$" "￥")
    ("#" "＃")
    ("!" "！")
    ("`" "・")
    ("~" "～")
    ("}" "』")
    ("|" "÷")
    ("{" "『"))
  "标点符号表。"
  :group 'chinese-pyim
  :type 'list)

(defcustom pyim-default-scheme 'quanpin
  "设置 Chinese-pyim 使用哪一种拼音方案，默认使用全拼输入。"
  :group 'chinese-pyim)

(defcustom pyim-schemes
  '((quanpin
     :document "全拼输入法方案（不可删除）。"
     :class quanpin
     :first-chars "abcdefghjklmnopqrstwxyz"
     :rest-chars "vmpfwckzyjqdltxuognbhsrei'-a"
     :prefer-trigger-chars "v")
    (pyim-shuangpin
     :document "与 Chinese-pyim 配合良好的双拼输入法方案，源自小鹤双拼方案。"
     :class shuangpin
     :first-chars "abcdefghijklmnpqrstuvwxyz"
     :rest-chars "abcdefghijklmnopqrstuvwxyz"
     :prefer-trigger-chars "o"
     :keymaps
     (("a" "a" "a")
      ("b" "b" "in")
      ("c" "c" "ao")
      ("d" "d" "ai")
      ("e" "e" "e")
      ("f" "f" "en")
      ("g" "g" "eng")
      ("h" "h" "ang")
      ("i" "ch" "i")
      ("j" "j" "an")
      ("k" "k" "ing" "uai")
      ("l" "l" "iang" "uang")
      ("m" "m" "ian")
      ("n" "n" "iao")
      ("o" "o" "uo" "o")
      ("p" "p" "ie")
      ("q" "q" "iu")
      ("r" "r" "uan")
      ("s" "s" "iong" "ong")
      ("t" "t" "ue" "ve")
      ("u" "sh" "u")
      ("v" "zh" "v" "ui")
      ("w" "w" "ei")
      ("x" "x" "ia" "ua")
      ("y" "y" "un")
      ("z" "z" "ou")
      ("aa" "a")
      ("aj" "an")
      ("ad" "ai")
      ("ac" "ao")
      ("ah" "ang")
      ("ee" "e")
      ("ew" "ei")
      ("ef" "en")
      ("er" "er")
      ("eg" "eng")
      ("ag" "ng")
      ("ao" "o")
      ("au" "ou")))
    (xiaohe-shuangpin
     :document "小鹤双拼输入法方案。"
     :class shuangpin
     :first-chars "abcdefghijklmnopqrstuvwxyz"
     :rest-chars "abcdefghijklmnopqrstuvwxyz"
     :prefer-trigger-chars nil
     :keymaps
     (("a" "a" "a")
      ("b" "b" "in")
      ("c" "c" "ao")
      ("d" "d" "ai")
      ("e" "e" "e")
      ("f" "f" "en")
      ("g" "g" "eng")
      ("h" "h" "ang")
      ("i" "ch" "i")
      ("j" "j" "an")
      ("k" "k" "ing" "uai")
      ("l" "l" "iang" "uang")
      ("m" "m" "ian")
      ("n" "n" "iao")
      ("o" "o" "uo" "o")
      ("p" "p" "ie")
      ("q" "q" "iu")
      ("r" "r" "uan")
      ("s" "s" "iong" "ong")
      ("t" "t" "ue" "ve")
      ("u" "sh" "u")
      ("v" "zh" "v" "ui")
      ("w" "w" "ei")
      ("x" "x" "ia" "ua")
      ("y" "y" "un")
      ("z" "z" "ou")
      ("aa" "a")
      ("aj" "an")
      ("ad" "ai")
      ("ac" "ao")
      ("ah" "ang")
      ("ee" "e")
      ("ew" "ei")
      ("ef" "en")
      ("er" "er")
      ("eg" "eng")
      ("og" "ng")
      ("oo" "o")
      ("ou" "ou"))))
  "Chinese-pyim 支持的所有拼音方案。")

(defcustom pyim-translate-trigger-char "v"
  "用于触发特殊操作的字符，相当与单字快捷键。

Chinese-pyim 内建的功能有：
1. 光标前面的字符为标点符号时，按这个字符可以切换前面的标
   点符号的样式（半角/全角）
2. 当光标前面为中文字符串时，输入 <num>v 可以用于保存自定义词条。
3. 其它。

注意：单字快捷键受到拼音方案的限制，比如：全拼输入法可以将其设置为v,
但双拼输入法下设置 v 可能就不行，所以，Chinese-pyim 首先会检查
当前拼音方案下，这个快捷键设置是否合理有效，如果不是一个合理的设置，
则使用拼音方案默认的 :prefer-trigger-chars 。

具体请参考 `pyim-translate-get-trigger-char' 。"
  :group 'chinese-pyim
  :type 'character)

(defcustom pyim-fuzzy-pinyin-alist
  '(("en" "eng")
    ("in" "ing")
    ("un" "ong"))
  "设定糢糊音"
  :group 'chinese-pyim)

(defcustom pyim-backends
  '(personal dicts chars pinyin-shouzimu pinyin-znabc)
  "pyim 词语获取 backends ，当前支持：

1. `personal'           从 `pyim-personal-dict-cache' 中获取词条。
2. `dicts'              从 `pyim-dict-cache' 中获取词条。
3. `chars'              逐一获取一个拼音对应的多个汉字。
4. `pinyin-shouzimu'    获取 *拼音首字母* 对应的词条，
     如果输入 \"ni-hao\" ，那么同时搜索 code 为 \"n-h\" 的词条。
5. `pinyin-znabc'       类似智能ABC的词语获取方式(源于 emacs-eim)."
  :group 'chinese-pyim)

(defcustom pyim-isearch-enable-pinyin-search nil
  "设置是否开启 isearch 中文拼音搜索功能。"
  :group 'chinese-pyim
  :type 'boolean)

(defcustom pyim-page-length 5
  "每页显示的词条数目"
  :group 'chinese-pyim
  :type 'number)

(defface pyim-string-face '((t (:underline t)))
  "Face to show current string"
  :group 'chinese-pyim)

(defface pyim-minibuffer-string-face '((t (:background "gray40")))
  "Face to current string show in minibuffer"
  :group 'chinese-pyim)

(defcustom pyim-english-input-switch-functions nil
  "这个变量的取值为一个函数列表，这个函数列表中的任意一个函数的运行结果为 t 时，
Chinese-pyim 也开启英文输入功能。"
  :group 'chinese-pyim)

(defcustom pyim-punctuation-half-width-functions nil
  "取值为一个函数列表，这个函数列表中的任意一个函数的运行结果为 t 时，
Chinese-pyim 输入半角标点，函数列表中每个函数都有一个参数：char ，表示
最后输入的一个字符，具体见: `pyim-translate' 。"
  :group 'chinese-pyim)

(defcustom pyim-select-word-finish-hook nil
  "Chinese-pyim 选词完成时运行的hook，"
  :group 'chinese-pyim
  :type 'hook)

(defcustom pyim-wash-function 'pyim-wash-current-line-function
  "这个函数与『单字快捷键配合使用』，当光标前面的字符为汉字字符时，
按 `pyim-translate-trigger-char' 对应字符，可以调用这个函数来清洗
光标前面的文字内容。"
  :group 'chinese-pyim
  :type 'function)

(defcustom pyim-use-tooltip 'popup
  "如何绘制 Chinese-pyim 选词框。

1. 当这个变量取值为 t 或者 'popup 时，使用 popup-el 包来绘制选词框；
2. 当取值为 pos-tip 时，使用 pos-tip 包来绘制选词框；
3. 当取值为 nil 时，将 minibuffer 做为选词框；"
  :group 'chinese-pyim)

(defcustom pyim-guidance-format-function 'pyim-guidance-format-function-two-lines
  "这个变量保存的函数用于 format 选词框中的字符串。"
  :group 'chinese-pyim
  :type 'function)

(defcustom pyim-tooltip-width-adjustment 1.2
  "校正 tooltip 选词框宽度的数值，表示校正后的宽度是未校正前宽度的倍数。

由于字体设置等原因，pos-tip 选词框实际宽度会比 *预期宽度* 偏大或者偏小，
这时，有可能会出现选词框词条显示不全或者选词框弹出位置不合理等问题。用户可以通过
增大或者减小这个变量来改变 tooltip 选词框的宽度，取值大概在 0.5 ~ 2.0 范围之内。

注：这个选项只适用于 `pyim-use-tooltip' 取值为 'pos-tip 的时候。"
  :group 'chinese-pyim)

(defvar pyim-debug nil)
(defvar pyim-title "灵拼" "Chinese-pyim 在 mode-line 中显示的名称。")
(defvar pyim-extra-dicts nil "与 `pyim-dicts' 类似, 用于和 elpa 格式的词库包集成。")

(defvar pyim-pinyin-shen-mu
  '("b" "p" "m" "f" "d" "t" "n" "l" "g" "k" "h"
    "j" "q" "x" "z" "c" "s" "zh" "ch" "sh" "r" "y" "w"))

(defvar pyim-pinyin-yun-mu
  '("a" "o" "e" "i" "u" "v" "ai" "ei" "ui" "ao" "ou" "iu"
    "ie" "ia" "ua" "ve" "er" "an" "en" "in" "un" "vn" "ang" "iong"
    "eng" "ing" "ong" "uan" "uang" "ian" "iang" "iao" "ue"
    "uai" "uo"))

(defvar pyim-pinyin-valid-yun-mu
  '("a" "o" "e" "ai" "ei" "ui" "ao" "ou" "er" "an" "en"
    "ang" "eng"))

(defvar pyim-current-key "" "已经输入的代码")
(defvar pyim-current-str "" "当前选择的词条")
(defvar pyim-input-ascii nil  "是否开启 Chinese-pyim 英文输入模式。")
(defvar pyim-force-input-chinese nil "是否强制开启中文输入模式。")

(defvar pyim-current-choices nil
  "所有可选的词条，是一个list。
1. CAR 部份是可选的词条，一般是一个字符串列表。
   也可以含有list。但是包含的list第一个元素必须是将要插入的字符串。
2. CDR 部分是一个 Association list。通常含有这样的内容：
   1. pos 上次选择的位置
   2. completion 下一个可能的字母（如果 pyim-do-completion 为 t）")

(defvar pyim-translating nil "记录是否在转换状态")

(defvar pyim-overlay nil "显示当前选择词条的 overlay")

(defvar pyim-pinyin-position nil)
(defvar pyim-spinyin-list nil
  "Chinese-pyim 会将一个拼音字符串分解为一个或者多个 spinyin （常见于双拼模式）,
这个变量用于保存分解得到的结果。")

(defvar pyim-guidance-list nil
  "这个 list 用于构建选词框中显示的字符串，其结构类似：

(:key \"ni hao\" :current-page 1 :total-page 9 :words \"1.你好 2.你好 ...\")")

(defvar pyim-current-pos nil "当前选择的词条在 pyim-current-choices 中的位置")

(defvar pyim-load-hook nil)
(defvar pyim-active-hook nil)

(defvar pyim-punctuation-translate-p '(auto yes no)
  "The car of its value will control the translation of punctuation.")

(defvar pyim-punctuation-pair-status
  '(("\"" nil) ("'" nil))
  "成对标点符号切换状态")

(defvar pyim-punctuation-escape-list (number-sequence ?0 ?9)
  "Punctuation will not insert after this characters.
If you don't like this funciton, set the variable to nil")

(defvar pyim-dict-cache nil)
(defvar pyim-dict-cache-md5 nil)
(defvar pyim-words-count-cache nil)
(defvar pyim-personal-dict-cache nil)
(defvar pyim-personal-words-count-cache nil)

(defvar pyim-mode-map
  (let ((map (make-sparse-keymap))
        (i ?\ ))
    (while (< i 127)
      (define-key map (char-to-string i) 'pyim-self-insert-command)
      (setq i (1+ i)))
    (setq i 128)
    (while (< i 256)
      (define-key map (vector i) 'pyim-self-insert-command)
      (setq i (1+ i)))
    (dolist (i (number-sequence ?1 ?9))
      (define-key map (char-to-string i) 'pyim-page-select-word-by-number))
    (define-key map " " 'pyim-page-select-word)
    (define-key map [backspace] 'pyim-delete-last-char)
    (define-key map [delete] 'pyim-delete-last-char)
    (define-key map [M-backspace] 'pyim-backward-kill-py)
    (define-key map [M-delete] 'pyim-backward-kill-py)
    (define-key map [C-backspace] 'pyim-backward-kill-py)
    (define-key map [C-delete] 'pyim-backward-kill-py)
    (define-key map "\177" 'pyim-delete-last-char)
    (define-key map "\C-n" 'pyim-page-next-page)
    (define-key map "\C-p" 'pyim-page-previous-page)
    (define-key map "\C-f" 'pyim-page-next-word)
    (define-key map "\C-b" 'pyim-page-previous-word)
    (define-key map "=" 'pyim-page-next-page)
    (define-key map "-" 'pyim-page-previous-page)
    (define-key map "\M-n" 'pyim-page-next-page)
    (define-key map "\M-p" 'pyim-page-previous-page)
    (define-key map "\C-m" 'pyim-quit-no-clear)
    (define-key map [return] 'pyim-quit-no-clear)
    (define-key map "\C-c" 'pyim-quit-clear)
    map)
  "Keymap")
;; #+END_SRC

;; ** 将变量转换为 local 变量
;; #+BEGIN_SRC emacs-lisp
(defvar pyim-local-variable-list
  '(pyim-current-key
    pyim-current-str
    pyim-current-choices
    pyim-current-pos
    pyim-input-ascii
    pyim-english-input-switch-functions
    pyim-punctuation-half-width-functions
    pyim-guidance-list
    pyim-translating
    pyim-overlay

    pyim-load-hook
    pyim-active-hook

    input-method-function
    inactivate-current-input-method-function
    describe-current-input-method-function

    pyim-punctuation-translate-p
    pyim-punctuation-pair-status
    pyim-punctuation-escape-list

    pyim-spinyin-list
    pyim-pinyin-position)
  "A list of buffer local variable")

(dolist (var pyim-local-variable-list)
  (make-variable-buffer-local var)
  (put var 'permanent-local t))
;; #+END_SRC
;; ** 输入法启动和重启
;; Chinese-pyim 使用 emacs 官方自带的输入法框架来启动输入法和重启输入法。
;; 所以我们首先需要使用 emacs 自带的命令 `register-input-method' 注册一个
;; 输入法。

;; #+BEGIN_SRC emacs-lisp
;;; 注册输入法
(register-input-method "chinese-pyim" "euc-cn" 'pyim-start pyim-title)
;; #+END_SRC

;; 真正启动 Chinese-pyim 的命令是 `pyim-start' ，这个命令做如下工作：
;; 1. 重置 `pyim-local-variable-list' 中所有的 local 变量。
;; 2. 使用 `pyim-cchar2pinyin-create-cache' 创建汉字到拼音的 hash table 。
;; 3. 运行hook： `pyim-load-hook'。
;; 4. 将 `pyim-dcache-save-caches' 命令添加到 `kill-emacs-hook' , emacs 关闭
;;    之前将 `pyim-personal-dict-cache' 和 `pyim-personal-words-count-cache'
;;    保存到文件，供以后使用。
;; 5. 设定变量：
;;    1. `input-method-function'
;;    2. `deactivate-current-input-method-function'
;; 6. 运行 `pyim-active-hook'

;; `pyim-start' 先后会运行两个 hook，所以我们需要事先定义：

;; `pyim-restart' 用于重启 Chinese-pyim，其过程和 `pyim-start' 类似，不同
;; 之处有：

;; 1. 输入法重启之前会询问用户，是否保存个人词频信息。
;; 2. 重启之前会使用函数 `pyim-kill-buffers' 删除所有的词库 buffer，具体
;;    请参考： [[pyim-kill-buffers]]

;; #+BEGIN_SRC emacs-lisp
(defun pyim-start (name &optional active-func restart save-files)
  (interactive)
  (mapc 'kill-local-variable pyim-local-variable-list)
  (mapc 'make-local-variable pyim-local-variable-list)
  (when (and restart save-files)
    (pyim-dcache-save-caches))
  (pyim-dcache-init)
  (pyim-cchar2pinyin-cache-create)
  (pyim-pinyin2cchar-cache-create)
  (run-hooks 'pyim-load-hook)
  ;; 如果 dicts 有变化，重新生成 dict cache。
  (pyim-dcache-create-dict-cache)
  (unless (member 'pyim-dcache-save-caches kill-emacs-hook)
    (add-to-list 'kill-emacs-hook 'pyim-dcache-save-caches))

  (setq input-method-function 'pyim-input-method)
  (setq deactivate-current-input-method-function 'pyim-inactivate)
  ;; (setq describe-current-input-method-function 'pyim-help)
  ;; If we are in minibuffer, turn off the current input method
  ;; before exiting.
  (when (eq (selected-window) (minibuffer-window))
    (add-hook 'minibuffer-exit-hook 'pyim-exit-from-minibuffer))
  (run-hooks 'pyim-active-hook)
  (when restart
    (message "Chinese-pyim 重启完成。")))

(defun pyim-exit-from-minibuffer ()
  (deactivate-input-method)
  (when (<= (minibuffer-depth) 1)
    (remove-hook 'minibuffer-exit-hook 'quail-exit-from-minibuffer)))

(defun pyim-restart ()
  "重启 Chinese-pyim，不建议用于编程环境。"
  (interactive)
  (let ((file-save-p
         (yes-or-no-p "正在重启 Chinese-pyim，需要保存 personal 文件的变动吗？ ")))
    (pyim-restart-1 file-save-p)))

(defun pyim-restart-1 (save-personal-file)
  "重启 Chinese-pyim，用于编程环境。"
  (pyim-start "Chinese-pyim" nil t save-personal-file))
;; #+END_SRC
;; ** 处理词库文件
;; *** 自定义词库
;; **** 词库文件格式
;; Chinese-pyim 使用词库文件来保存各个拼音对应的中文词条，每一个词库文件都
;; 是简单的文本文件，编码强制为 utf-8-unix, 结构类似：

;; #+BEGIN_EXAMPLE
;; ni-bu-hao 你不好
;; ni-hao  你好 妮好 你豪
;; #+END_EXAMPLE

;; 第一个空白字符之前的内容为拼音 code，空白字符之后为中文词条列表。
;; 拼音词库 *不处理* 中文标点符号。

;; 我们使用变量 `pyim-dicts' 和 `pyim-extra-dicts' 来设定普通词库文件的信息：
;; 1. `:name' 用户给词库设定的名称（可选项）。
;; 2. `:file' 词库文件的绝对路径。

;; #+BEGIN_SRC emacs-lisp
(defun pyim-dcache-create-dict-cache (&optional force)
  (interactive)
  (let* ((dict-files (mapcar #'(lambda (x)
                                 (unless (plist-get x :disable)
                                   (plist-get x :file)))
                             `(,@pyim-dicts ,@pyim-extra-dicts)))
         (dicts-md5 (md5 (prin1-to-string
                          (mapcar #'(lambda (file)
                                      (list file (nth 5 (file-attributes file 'string))))
                                  dict-files))))
         (dict-cache-file (concat (file-name-as-directory pyim-dcache-directory)
                                  "pyim-dict-cache"))
         (dict-md5-file (concat (file-name-as-directory pyim-dcache-directory)
                                "pyim-dict-cache-md5")))
    (when (or force (not (equal dicts-md5 (pyim-dcache-get-value-from-file dict-md5-file))))
      (async-start
       `(lambda ()
          ,(async-inject-variables "^load-path$")
          (require 'chinese-pyim-core)
          (pyim-dcache-generate-cache-file ',dict-files ,dict-cache-file)
          (pyim-dcache-save-value-to-file ',dicts-md5 ,dict-md5-file))
       `(lambda (result)
          (setq pyim-dict-cache
                (pyim-dcache-get-value-from-file ,dict-cache-file)))))))

(defun pyim-dcache-init ()
  (pyim-dcache-restore-variable 'pyim-dict-cache (make-hash-table :test #'equal))
  (pyim-dcache-restore-variable 'pyim-words-count-cache (make-hash-table :test #'equal))
  (pyim-dcache-restore-variable 'pyim-personal-dict-cache (make-hash-table :test #'equal))
  (pyim-dcache-restore-variable 'pyim-personal-words-count-cache (make-hash-table :test #'equal)))

(defun pyim-dcache-restore-variable (variable &optional fallback-value)
  (unless (symbol-value variable)
    (let ((file (concat (file-name-as-directory pyim-dcache-directory)
                        (symbol-name variable))))
      (set variable (or (pyim-dcache-get-value-from-file file)
                        fallback-value)))))

(defun pyim-dcache-get-value-from-file (file)
  (when (file-exists-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (eval (read (current-buffer))))))

(defun pyim-dcache-save-variable (variable)
  (let ((file (concat (file-name-as-directory pyim-dcache-directory)
                      (symbol-name variable)))
        (value (symbol-value variable)))
    (pyim-dcache-save-value-to-file value file)))

(defun pyim-dcache-save-value-to-file (value file)
  (when value
    (with-temp-buffer
      (insert ";; Auto generated by `pyim-dcache-save-variable-to-file', don't edit it by hand!\n\n")
      (insert (prin1-to-string value))
      (insert "\n
;; Local Variables:
;; coding: utf-8-unix
;; End:")
      (make-directory (file-name-directory file) t)
      (write-file file))))

(defun pyim-dcache-generate-cache-file (dict-files cache-file)
  (let ((hastable (make-hash-table :size 1000000 :test #'equal)))
    (dolist (file dict-files)
      (with-temp-buffer
        (let ((coding-system-for-read 'utf-8-unix))
          (insert-file-contents file))
        (goto-char (point-min))
        (forward-line 1)
        (while (not (eobp))
          (let ((code (pyim-code-at-point))
                (content (pyim-line-content)))
            (when (and code content)
              (puthash code (delete-dups `(,@content ,@(gethash code hastable)))
                       hastable)))
          (forward-line 1))))
    (pyim-dcache-save-value-to-file hastable cache-file)))

(defun pyim-code-at-point ()
  "Get code in the current line."
  (save-excursion
    (beginning-of-line)
    (if (re-search-forward "[ \t:]" (line-end-position) t)
        (buffer-substring-no-properties (line-beginning-position) (1- (point))))))

(defun pyim-line-content (&optional seperaters)
  "用 SEPERATERS 分解当前行，所有参数传递给 split-string 函数。"
  (let* ((begin (line-beginning-position))
         (end (line-end-position))
         (items (cdr (split-string
                      (buffer-substring-no-properties begin end)
                      seperaters))))
    items))

(defun pyim-dcache-save-caches ()
  "将下面几个文件更新后内容保存。
这个函数默认作为`kill-emacs-hook'使用。"
  (interactive)
  (pyim-dcache-save-variable 'pyim-personal-dict-cache)
  (pyim-dcache-save-variable 'pyim-personal-words-count-cache)
  t)
;; #+END_SRC

;; *** 从词库中搜索中文词条
;; 当个人词频文件以及普通词库文件加载完成后， Chinese-pyim 就可以搜索某个
;; 拼音字符串对应的中文词条了，这个工作由函数 `pyim-get' 完成

;; #+BEGIN_SRC emacs-lisp
(defun pyim-dcache-get (code &optional dcache-list)
  (let ((dcache-list (or (if (listp dcache-list)
                            dcache-list
                          (list dcache-list))
                        (list pyim-personal-dict-cache pyim-dict-cache)))
        result)
    (dolist (cache dcache-list)
      (let ((value (gethash code cache)))
        (when value
          (setq result (append result value)))))
    `(,@result ,@(pyim-pinyin2cchar-get code t t))))

(defun pyim-string-match-p (regexp string &optional start)
  (and (stringp regexp)
       (stringp string)
       (string-match-p regexp string start)))

(defun pyim-pinyin-build-regexp (pinyin &optional match-beginning first-equal all-equal)
  "从 `pinyin' 构建一个 regexp，用于搜索联想词，
比如：ni-hao-si-j --> ^ni-hao[a-z]*-si[a-z]*-j[a-z]* , when `first-equal' set to `t'
                  --> ^ni[a-z]*-hao[a-z]*-si[a-z]*-j[a-z]* , when `first-equal' set to `nil'"
  (when (and pinyin (stringp pinyin))
    (let ((pinyin-list (split-string pinyin "-"))
          (count 0))
      (concat (if match-beginning "^" "")
              (mapconcat
               #'(lambda (x)
                   (setq count (+ count 1))
                   (if (or (not first-equal) (> count 1))
                       (if all-equal
                           x
                         (concat x "[a-z]*"))
                     x))
               pinyin-list "-")))))

;; #+END_SRC

;; *** 保存词条，删除词条以及调整词条位置
;; #+BEGIN_SRC emacs-lisp
(defmacro pyim-dcache-put (cache code &rest body)
  (declare (indent 0))
  (let ((key (make-symbol "key"))
        (table (make-symbol "table"))
        (new-value (make-symbol "new-value")))
    `(let* ((,key ,code)
            (,table ,cache)
            (orig-value (gethash ,key ,table))
            ,new-value)
       (setq ,new-value (progn ,@body))
       (unless (equal orig-value ,new-value)
         (puthash ,key ,new-value ,table)))))

(defun pyim-create-or-rearrange-word (word &optional rearrange-word)
  "将中文词条 `word' 添加拼音后，保存到 `pyim-personal-dict-cache' 中，
当前词条追加到已有词条之后。`pyim-create-or-rearrange-word'
会调用 `pyim-hanzi2pinyin' 来获取中文词条的拼音code。

BUG：无法有效的处理多音字。"
  (when (> (length word) 0)
    (let* ((pinyins (pyim-hanzi2pinyin word nil "-" t nil t))) ;使用了多音字校正

      ;; 保存词频
      (when (> (length word) 1)
        (pyim-dcache-put
          pyim-personal-words-count-cache word
          (+ (or orig-value 0) 1)))
      (dolist (py pinyins)
        (unless (pyim-string-match-p "[^ a-z-]" py)
          ;; 添加词库： ”拼音“ - ”中文词条“
          (pyim-dcache-put
            pyim-personal-dict-cache py
            (if rearrange-word
                (pyim-list-merge word orig-value)
              (pyim-list-merge orig-value word)))
          ;; 添加词库： ”拼音首字母“ - ”中文词条“
          (pyim-dcache-put
            pyim-personal-dict-cache
            (mapconcat #'(lambda (x)
                           (substring x 0 1))
                       (split-string py "-") "-")
            (if rearrange-word
                (pyim-list-merge word orig-value)
              (pyim-list-merge orig-value word))))))))

(defun pyim-list-merge (a b)
  "Join list A and B to a new list, then delete dups."
  (let ((a (if (listp a)
               a
             (list a)))
        (b (if (listp b)
               b
             (list b))))
    (delete-dups `(,@a ,@b))))

(defun pyim-chinese-string-at-point (&optional number)
  "获取光标一个中文字符串，字符数量为：`number'"
  (save-excursion
    (let* ((point (point))
           (begin (- point number))
           (begin (if (> begin 0)
                      begin
                    (point-min)))
           (string (buffer-substring-no-properties
                    point begin)))
      (when (and (stringp string)
                 (= (length string) number)
                 (not (pyim-string-match-p "\\CC" string)))
        string))))

(defun pyim-create-word-at-point (&optional number silent)
  "将光标前字符数为 `number' 的中文字符串添加到个人词库中
当 `silent' 设置为 t 是，不显示提醒信息。"
  (let* ((string (pyim-chinese-string-at-point (or number 2))))
    (when string
      (pyim-create-or-rearrange-word string)
      (unless silent
        (message "将词条: \"%s\" 插入 personal file。" string)))))

(defun pyim-create-word-at-point:2char ()
  "将光标前2个中文字符组成的字符串加入个人词库。"
  (interactive)
  (pyim-create-word-at-point 2))

(defun pyim-create-word-at-point:3char ()
  "将光标前3个中文字符组成的字符串加入个人词库。"
  (interactive)
  (pyim-create-word-at-point 3))

(defun pyim-create-word-at-point:4char ()
  "将光标前4个中文字符组成的字符串加入个人词库。"
  (interactive)
  (pyim-create-word-at-point 4))
;; #+END_SRC

;; **** 删词功能
;; #+BEGIN_SRC emacs-lisp
(defun pyim-create-word-from-selection ()
  "Add the selected text as a Chinese word into the personal dictionary."
  (interactive)
  (when (region-active-p)
    (let ((string (buffer-substring-no-properties (region-beginning) (region-end))))
      (if (> (length string) 6)
          (error "词条太长")
        (if (not (string-match-p "^\\cc+\\'" string))
            (error "不是纯中文字符串")
          (pyim-create-or-rearrange-word string)
          (message "将词条: \"%s\" 插入 personal file。" string))))))

(defun pyim-delete-word ()
  "将高亮选择的词条从 `pyim-personal-dict-cache' 中删除。"
  (interactive)
  (if mark-active
      (let ((string (buffer-substring-no-properties
                     (region-beginning) (region-end))))
        (when (and (< (length string) 6)
                   (> (length string) 0))
          (pyim-delete-word-1 string)
          (message "将词条: \"%s\" 从 personal file中删除。" string)))
    (message "请首先高亮选择需要删除的词条。")))

(defun pyim-delete-word-1 (word)
  "将中文词条 `word' 从 `pyim-personal-dict-cache' 中删除"
  (let* ((pinyins (pyim-hanzi2pinyin word nil "-" t))
         (pinyins-szm (mapcar
                       #'(lambda (pinyin)
                           (mapconcat #'(lambda (x)
                                          (substring x 0 1))
                                      (split-string pinyin "-") "-"))
                       pinyins)))
    (dolist (pinyin pinyins)
      (unless (pyim-string-match-p "[^ a-z-]" pinyin)
        (pyim-dcache-put
          pyim-personal-dict-cache pinyin
          (remove word orig-value))))
    (dolist (pinyin pinyins-szm)
      (unless (pyim-string-match-p "[^ a-z-]" pinyin)
        (pyim-dcache-put
          pyim-personal-dict-cache pinyin
          (remove word orig-value))))))
;; #+END_SRC

;; ** 生成 `pyim-current-key' 并插入 `pyim-current-str'
;; *** 生成拼音字符串 `pyim-current-key'
;; Chinese-pyim 使用函数 `pyim-start' 启动输入法的时候，会将变量
;; `input-method-function' 设置为 `pyim-input-method' ，这个变量
;; 会影响 `read-event' 的行为。

;; 当输入字符时，`read-event' 会被调用，`read-event' 调用的过程中，
;; 会执行 `pyim-input-method' 这个函数。`pyim-input-method' 又调用函数
;; `pyim-start-translation'

;; `pyim-start-translation' 这个函数较复杂，作许多低层工作，但它的一个重
;; 要流程是：
;; 1. 使用函数 `read-key-sequence' 得到 key-sequence
;; 2. 使用函数 `lookup-key' 查询 pyim-mode-map 中，上述 key-sequence 对应
;;    的命令。
;; 3. 如果查询得到的命令是 'pyim-self-insert-command' 时，
;;    `pyim-start-translation' 会调用这个函数。

;; `pyim-self-insert-command' 这个函数的核心工作就是将用户输入的字符，组
;; 合成拼音字符串并保存到变量 `pyim-current-key' 中。

;; 中英文输入模式切换功能也是在 'pyim-self-insert-command' 中实现。

;; 这个部份的代码涉及许多 emacs 低层函数，相对复杂，不容易理解，有兴趣的
;; 朋友可以参考：
;; 1. `quail-input-method' 相关函数。
;; 2. elisp 手册相关章节:
;;    1. Invoking the Input Method
;;    2. Input Methods
;;    3. Miscellaneous Event Input Features
;;    4. Reading One Event

;; *** 在待输入 buffer 中插入 `pyim-current-str'
;; `pyim-self-insert-command' 会调用 `pyim-handle-string' 来处理
;; `pyim-current-key'，得到对应的 `pyim-current-str'，然后，
;; `pyim-start-translation' 返回 `pyim-current-str' 的取值。

;; 在 `pyim-input-method' 函数内部，`pyim-start-translation' 返回值分解为
;; event list。

;; 最后，emacs 低层函数 read-event 将这个 list 插入 *待输入buffer* 。

;; #+BEGIN_SRC emacs-lisp
(defun pyim-input-method (key-or-string)
  (if (or buffer-read-only
          overriding-terminal-local-map
          overriding-local-map)
      (if (characterp key-or-string)
          (list key-or-string)
        (mapcar 'identity key-or-string))
    ;; (message "call with key: %S" key-or-string)
    (pyim-overlays-setup)
    (with-silent-modifications
      (unwind-protect
          (let ((input-string (pyim-start-translation key-or-string)))
            ;; (message "input-string: %s" input-string)
            (setq pyim-guidance-list nil)
            (when (and (stringp input-string)
                       (> (length input-string) 0))
              (if input-method-exit-on-first-char
                  (list (aref input-string 0))
                (mapcar 'identity input-string))))
        (pyim-overlays-delete)))))

(defun pyim-start-translation (key-or-string)
  "Start translation of the typed character KEY by Chinese-pyim.
Return the input string."
  ;; Check the possibility of translating KEY.
  ;; If KEY is nil, we can anyway start translation.
  (if (or (integerp key-or-string)
          (stringp key-or-string)
          (null key-or-string))
      ;; OK, we can start translation.
      (let* ((echo-keystrokes 0)
             (help-char nil)
             (overriding-terminal-local-map pyim-mode-map)
             (generated-events nil)
             (input-method-function nil)
             (modified-p (buffer-modified-p))
             key str last-command-event last-command this-command)

        (if (integerp key-or-string)
            (setq key key-or-string)
          (setq key (string-to-char (substring key-or-string -1)))
          (setq str (substring key-or-string 0 -1)))

        (setq pyim-current-str ""
              pyim-current-key (or str "")
              pyim-translating t)

        (when key
          (setq unread-command-events
                (cons key unread-command-events)))

        (while pyim-translating
          (set-buffer-modified-p modified-p)
          (let* ((prompt (when input-method-use-echo-area
                           (format "[%s]: %s"
                                   (replace-regexp-in-string "-" "" pyim-current-key)
                                   (plist-get pyim-guidance-list :words))))
                 (keyseq (read-key-sequence prompt nil nil t))
                 (cmd (lookup-key pyim-mode-map keyseq)))
            ;; (message "key: %s, cmd:%s\nlcmd: %s, lcmdv: %s, tcmd: %s"
            ;;          key cmd last-command last-command-event this-command)
            (if (if key
                    (commandp cmd)
                  (eq cmd 'pyim-self-insert-command))
                (progn
                  ;; (message "keyseq: %s" keyseq)
                  (setq last-command-event (aref keyseq (1- (length keyseq)))
                        last-command this-command
                        this-command cmd)
                  (setq key t)
                  (condition-case-unless-debug err
                      (call-interactively cmd)
                    (error (message "Chinese-pyim 出现错误: %s , 开启 debug-on-error 后可以了解详细情况。"
                                    (cdr err)) (beep))))
              ;; KEYSEQ is not defined in the translation keymap.
              ;; Let's return the event(s) to the caller.
              (setq unread-command-events
                    (string-to-list (this-single-command-raw-keys)))
              ;; (message "unread-command-events: %s" unread-command-events)
              (pyim-terminate-translation))))
        ;; (message "return: %s" pyim-current-str)
        pyim-current-str)
    ;; Since KEY doesn't start any translation, just return it.
    ;; But translate KEY if necessary.
    (char-to-string key-or-string)))

(defun pyim-auto-switch-english-input-p ()
  "判断是否 *根据环境自动切换* 为英文输入模式，这个函数处理变量：
`pyim-english-input-switch-functions'"
  (let* ((func-or-list pyim-english-input-switch-functions))
    (and (cl-some #'(lambda (x)
                      (if (functionp x)
                          (funcall x)
                        nil))
                  (cond ((functionp func-or-list) (list func-or-list))
                        ((listp func-or-list) func-or-list)
                        (t nil)))
         (setq current-input-method-title
               (concat pyim-title
                       (if pyim-input-ascii
                           "-英文"
                         "-AU英"))))))

(defun pyim-input-chinese-p ()
  "确定 Chinese-pyim 是否启动中文输入模式"
  (let* ((scheme-name pyim-default-scheme)
         (first-chars (pyim-scheme-get-option scheme-name :first-chars))
         (rest-chars (pyim-scheme-get-option scheme-name :rest-chars)))
    (and (or pyim-force-input-chinese
             (and (not pyim-input-ascii)
                  (not (pyim-auto-switch-english-input-p))))
         (if (pyim-string-emptyp pyim-current-key)
             (member last-command-event
                     (mapcar 'identity first-chars))
           (member last-command-event
                   (mapcar 'identity rest-chars)))
         (setq current-input-method-title pyim-title))))

(defun pyim-string-emptyp (str)
  (not (string< "" str)))

(defun pyim-self-insert-command ()
  "如果在 pyim-first-char 列表中，则查找相应的词条，否则停止转换，插入对应的字符"
  (interactive "*")
  ;; (message "%s" (current-buffer))
  (if (pyim-input-chinese-p)
      (progn (setq pyim-current-key
                   (concat pyim-current-key (char-to-string last-command-event)))
             (pyim-handle-string))
    (pyim-append-string (pyim-translate last-command-event))
    (pyim-terminate-translation)))

(defun pyim-terminate-translation ()
  "Terminate the translation of the current key."
  (setq pyim-translating nil)
  (pyim-delete-region)
  (setq pyim-current-choices nil)
  (setq pyim-guidance-list nil)
  (when (and (eq pyim-use-tooltip 'pos-tip)
             (pyim-tooltip-pos-tip-usable-p))
    (pos-tip-hide)))
;; #+END_SRC

;; ** 处理拼音字符串 `pyim-current-key'
;; *** 拼音字符串 -> 待选词列表
;; 从一个拼音字符串获取其待选词列表，大致可以分成3个步骤：
;; 1. 分解这个拼音字符串，得到一个拼音列表。
;;    #+BEGIN_EXAMPLE
;;    woaimeinv -> (("w" . "o") ("" . "ai") ("m" . "ei") ("n" . "v"))
;;    #+END_EXAMPLE
;; 2. 将拼音列表排列组合，得到多个词语的拼音，并用列表表示。
;;    #+BEGIN_EXAMPLE
;;    (("p" . "in") ("y" . "in") ("sh" . "") ("r" . ""))
;;    => ("pin-yin"  ;; 完整的拼音
;;        ("p-y-sh" ("p" . "in") ("y" . "in") ("sh" . "")) ;; 不完整的拼音
;;        ("p-y-sh-r" ("p" . "in") ("y" . "in") ("sh" . "") ("r" . "")) ;; 不完整的拼音
;;        )
;;    #+END_EXAMPLE
;; 3. 递归的查询上述多个词语拼音，将得到的结果合并为待选词列表。
;; **** 分解拼音字符串
;; 拼音字符串操作主要做两方面的工作：
;; 1. 将拼音字符串分解为拼音列表。
;; 2. 将拼音列表合并成拼音字符串。

;; 在这之前，Chinese-pyim 定义了三个变量：
;; 1. 声母表： `pyim-pinyin-shen-mu'
;; 2. 韵母表：`pyim-pinyin-yun-mu'
;; 3. 有效韵母表： `pyim-pinyin-valid-yun-mu'

;; Chinese-pyim 使用函数 `pyim-code-split' 将拼音字符串分解为一个由声母和韵母组成的拼音列表，比如：

;; #+BEGIN_EXAMPLE
;; (pyim-code-split "woaimeinv" 'quanpin)
;; #+END_EXAMPLE

;; 结果为:
;; : ((("w" . "o") ("" . "ai") ("m" . "ei") ("n" . "v")))

;; 这个过程通过递归的调用 `pyim-pinyin-get-charpy' 来实现，整个过程类似用菜刀切黄瓜片，将一个拼音字符串逐渐切开。比如：

;; #+BEGIN_EXAMPLE
;; (pyim-pinyin-get-charpy "woaimeinv")
;; #+END_EXAMPLE

;; 结果为:
;; : (("w" . "o") . "aimeinv")

;; 一个完整的递归过程类似：
;; #+BEGIN_EXAMPLE
;; "woaimeinv"
;; (("w" . "o") . "aimeinv")
;; (("w" . "o") ("" . "ai") . "meinv")
;; (("w" . "o") ("" . "ai") ("m" . "ei" ) . "nv")
;; (("w" . "o") ("" . "ai") ("m" . "ei" ) ("n" . "v"))
;; #+END_EXAMPLE

;; `pyim-pinyin-get-charpy' 由两个基本函数配合实现：
;; 1. pyim-pinyin-get-sm 从一个拼音字符串中提出第一个声母
;; 2. pyim-pinyin-get-ym 从一个拼音字符串中提出第一个韵母

;; #+BEGIN_EXAMPLE
;; (pyim-pinyin-get-sm "woaimeinv")
;; #+END_EXAMPLE

;; 结果为:
;; : ("w" . "oaimeinv")

;; #+BEGIN_EXAMPLE
;; (pyim-pinyin-get-ym "oaimeinv")
;; #+END_EXAMPLE

;; 结果为:
;; : ("o" . "aimeinv")

;; 当用户输入一个错误的拼音时，`pyim-code-split' 会产生一个声母为空而韵母又不正确的拼音列表 ，比如：

;; #+BEGIN_EXAMPLE
;; (pyim-code-split "ua" 'quanpin)
;; #+END_EXAMPLE

;; 结果为:
;; : ((("" . "ua")))

;; 这种错误可以使用函数 `pyim-spinyin-validp' 来检测。
;; #+BEGIN_EXAMPLE
;; (list (pyim-spinyin-validp (car (pyim-code-split "ua" 'quanpin)))
;;       (pyim-spinyin-validp (car (pyim-code-split "a" 'quanpin)))
;;       (pyim-spinyin-validp (car (pyim-code-split "wa" 'quanpin)))
;;       (pyim-spinyin-validp (car (pyim-code-split "wua" 'quanpin))))
;; #+END_EXAMPLE

;; 结果为:
;; : (nil t t t)

;; Chinese-pyim 使用函数 `pyim-code-concat' 将一个拼音列表合并为拼音
;; 字符串，这个可以认为是 `pyim-code-split' 的反向操作。构建得到的拼音
;; 字符串用于搜索词条。

;; #+BEGIN_EXAMPLE
;; (pyim-code-concat '(("w" . "o") ("" . "ai") ("m" . "ei") ("n" . "v")) nil 'quanpin)
;; #+END_EXAMPLE

;; 结果为:
;; : "wo-ai-mei-nv"

;; 最后： `pyim-pinyin-user-divide-pos' 和 `pyim-pinyin-restore-user-divide' 用来处理隔
;; 音符，比如： xi'an

;; #+BEGIN_SRC emacs-lisp
;; 将汉字的拼音分成声母和其它
(defun pyim-pinyin-get-sm (py)
  "从一个拼音字符串中提出第一个声母。"
  (when (and py (string< "" py))
    (let (shenmu yunmu len)
      (if (< (length py) 2)
          (if (member py pyim-pinyin-shen-mu)
              (cons py "")
            (cons "" py))
        (setq shenmu (substring py 0 2))
        (if (member shenmu pyim-pinyin-shen-mu)
            (setq py (substring py 2))
          (setq shenmu (substring py 0 1))
          (if (member shenmu pyim-pinyin-shen-mu)
              (setq py (substring py 1))
            (setq shenmu "")))
        (cons shenmu py)))))

(defun pyim-pinyin-get-ym (py)
  "从一个拼音字符串中提出第一个韵母"
  (when (and py (string< "" py))
    (let (yunmu len)
      (setq len (min (length py) 5))
      (setq yunmu (substring py 0 len))
      (while (and (not (member yunmu pyim-pinyin-yun-mu))
                  (> len 0))
        (setq yunmu (substring py 0 (setq len (1- len)))))
      (setq py (substring py len))
      (if (and (string< "" py)
               (not (member (substring py 0 1) pyim-pinyin-shen-mu))
               (member (substring yunmu -1) pyim-pinyin-shen-mu)
               (member (substring yunmu 0 -1) pyim-pinyin-yun-mu)
               (not (and (member (substring yunmu -1) '("n" "g"))
                         (or (string= (substring py 0 1) "o")
                             (string= (substring py 0 (min (length py) 2)) "er")))))
          (setq py (concat (substring yunmu -1) py)
                yunmu (substring yunmu 0 -1)))
      (cons yunmu py))))

(defun pyim-pinyin-get-charpy (py)
  "分解一个拼音字符串成声母和韵母。"
  (when (and py (string< "" py))
    (let* ((sm (pyim-pinyin-get-sm py))
           (ym (pyim-pinyin-get-ym (cdr sm)))
           (charpys (mapcar #'(lambda (x)
                                (concat (car x) (cdr x)))
                            (pyim-spinyin-find-fuzzy-1
                             (cons (car sm) (car ym))))))
      (if (or (null ym) ;如果韵母为空
              (and (string< "" (car ym))
                   (not (cl-some
                         #'(lambda (charpy)
                             (or (pyim-pinyin2cchar-get charpy t)
                                 (pyim-dcache-get charpy)))
                         charpys))))

          (cons sm "")
        (cons (cons (car sm) (car ym)) (cdr ym))))))

;;; 处理输入的拼音
(defun pyim-scheme-get (scheme-name)
  "获取名称为 `scheme-name' 的拼音方案。"
  (assoc scheme-name pyim-schemes))

(defun pyim-scheme-get-option (scheme-name option)
  "获取名称为 `scheme-name' 的拼音方案，并提取其属性 `option' 。"
  (let ((scheme (pyim-scheme-get scheme-name)))
    (when scheme
      (plist-get (cdr scheme) option))))

(defun pyim-code-split (code &optional scheme-name)
  "按照 `scheme-name' 对应的输入法方案，把一个 code 字符串分解为一个列表。
得到的列表有类似:

1. pinyin:  (((\"n\" . \"i\") (\"h\" . \"ao\")))
"
  (let ((pinyin-class (pyim-scheme-get-option scheme-name :class)))
    (when pinyin-class
      (funcall (intern (concat "pyim-code-split:"
                               (symbol-name pinyin-class)))
               str scheme-name))))

(defun pyim-code-split:quanpin (py &optional -)
  "把一个拼音字符串分解成由声母和韵母组成的复杂列表。
如果含有 ' 的位置优先处理。"
  (when (and py (string< "" py))
    (pyim-spinyin-find-fuzzy
     (list (apply 'append
                  (mapcar #'(lambda (p)
                              (let (chpy spinyin)
                                (setq p (replace-regexp-in-string "[ -]" "" p))
                                (while (when (string< "" p)
                                         (setq chpy (pyim-pinyin-get-charpy p))
                                         (setq spinyin (append spinyin (list (car chpy))))
                                         (setq p (cdr chpy))))
                                spinyin))
                          (split-string py "'")))))))

;; "nihc" -> (((\"n\" . \"i\") (\"h\" . \"ao\")))
(defun pyim-code-split:shuangpin (str &optional scheme-name)
  "把一个双拼字符串分解成一个声母和韵母组成的复杂列表。"
  (let ((keymaps (pyim-scheme-get-option scheme-name :keymaps))
        (list (string-to-list (replace-regexp-in-string "-" "" str)))
        results)
    (while list
      (let* ((sp-sm (pop list))
             (sp-ym (pop list))
             (sp-sm (when sp-sm (char-to-string sp-sm)))
             (sp-ym (when sp-ym (char-to-string sp-ym)))
             (sm (nth 1 (assoc sp-sm keymaps)))
             (ym (cdr (cdr (assoc sp-ym keymaps)))))
        (push (mapcar
               #'(lambda (x)
                   (let* ((y (concat sp-sm sp-ym))
                          (z (cadr (assoc y keymaps))))
                     (if z (cons "" z) (cons sm x))))
               (or ym (list "")))
              results)))
    (pyim-spinyin-find-fuzzy
     (pyim-permutate-list (nreverse results)))))

(defun pyim-spinyin-find-fuzzy (spinyin-list)
  "用于处理模糊音的函数。"
  (let (fuzzy-spinyin-list result1 result2)
    (dolist (spinyin spinyin-list)
      (setq fuzzy-spinyin-list
            (pyim-permutate-list
             (mapcar 'pyim-spinyin-find-fuzzy-1 spinyin)))
      (push (car fuzzy-spinyin-list) result1)
      (setq result2 (append result2 (cdr fuzzy-spinyin-list))))
    (append result1 result2)))

(defun pyim-spinyin-find-fuzzy-1 (pycons)
  "Find all fuzzy pinyins, for example:

(\"f\" . \"en\") -> ((\"f\" . \"en\") (\"f\" . \"eng\"))"
  (cl-labels ((find-list (str list)
                         (let (result)
                           (dolist (x list)
                             (when (member str x)
                               (setq list nil)
                               (setq result
                                     (delete-dups
                                      `(,str ,@(cl-copy-list x))))))
                           (or result (list str)))))
    (let* ((fuzzy-alist pyim-fuzzy-pinyin-alist)
           (sm-list (find-list (car pycons) fuzzy-alist))
           (ym-list (find-list (cdr pycons) fuzzy-alist))
           result)
      (dolist (a sm-list)
        (dolist (b ym-list)
          (push (cons a b) result)))
      (reverse result))))

(defun pyim-spinyin-validp (spinyin)
  "检查得到的拼音是否含有声母为空，而韵母又不正确的拼音"
  (let ((valid t) py)
    (while (progn
             (setq py (car spinyin))
             (if (and (not (string< "" (car py)))
                      (not (member (cdr py) pyim-pinyin-valid-yun-mu)))
                 (setq valid nil)
               (setq spinyin (cdr spinyin)))))
    valid))

(defun pyim-pinyin-user-divide-pos (py)
  "检测出用户分割的位置"
  (setq py (replace-regexp-in-string "-" "" py))
  (let (poslist (start 0))
    (while (string-match "'" py start)
      (setq start (match-end 0))
      (setq poslist (append poslist (list (match-beginning 0)))))
    poslist))

(defun pyim-pinyin-restore-user-divide (py pos)
  "按检测出的用户分解的位置，重新设置拼音"
  (let ((i 0) (shift 0) cur)
    (setq cur (car pos)
          pos (cdr pos))
    (while (and cur (< i (length py)))
      (if (= (aref py i) ?-)
          (if (= i (+ cur shift))
              (progn
                (aset py i ?')
                (setq cur (car pos)
                      pos (cdr pos)))
            (setq shift (1+ shift))))
      (setq i (1+ i)))
    (if cur (setq py (concat py "'")))  ; the last char is `''
    py))

(defun pyim-code-concat (scode &optional shou-zi-mu scheme-name)
  "按照 `scheme' 对应的输入法方案，将一个 scode (已经分解的 code )
重新合并为字符串，用于搜索。"
  (let ((pinyin-class (pyim-scheme-get-option scheme-name :class)))
    (when pinyin-class
      (funcall (intern (concat "pyim-code-concat:"
                               (symbol-name pinyin-class)))
               scode shou-zi-mu scheme-name))))

(defun pyim-code-concat:quanpin (spinyin &optional shou-zi-mu scheme-name)
  "把一个拼音列表合并为一个全拼字符串，当 `shou-zi-mu' 设置为 t
时，生成拼音首字母字符串，比如 p-y。"
  (mapconcat 'identity
             (mapcar
              #'(lambda (w)
                  (let ((py (concat (car w) (cdr w))))
                    (if shou-zi-mu
                        (substring py 0 1)
                      py)))
              spinyin)
             "-"))

(defun pyim-code-concat:shuangpin (spinyin &optional shou-zi-mu scheme-name)
  "把一个拼音列表合并为一个双拼字符串，当 `shou-zi-mu' 设置为 t 时，
生成双拼首字母字符串，比如 p-y。"
  (when scheme-name
    (let ((keymaps (pyim-scheme-get-option scheme-name :keymaps)))
      (mapconcat 'identity
                 (mapcar
                  #'(lambda (w)
                      (let ((sm (car w))
                            (ym (cdr w)))
                        (if (equal sm "")
                            (car (rassoc (list ym) keymaps))
                          (concat (cl-some
                                   #'(lambda (x)
                                       (when (equal sm (nth 1 x))
                                         (car x))) keymaps)
                                  (unless shou-zi-mu
                                    (cl-some
                                     #'(lambda (x)
                                         (when (or (equal ym (nth 2 x))
                                                   (equal ym (nth 3 x)))
                                           (car x))) keymaps))))))
                  spinyin)
                 "-"))))
;; #+END_SRC

;; **** 获得词语拼音并进一步查询得到备选词列表
;; #+BEGIN_SRC emacs-lisp
(defun pyim-choices-get (spinyin-list)
  "得到可能的词组和汉字。"
  ;; spinyin-list 可以包含多个 spinyin, 从而得到多个子候选词列表，如何将多个 *子候选词列表* 合理的合并，
  ;; 是一个比较麻烦的事情的事情。 注：这个地方需要进一步得改进。
  (let* (personal-words
         pinyin-dict-words
         pinyin-shouzimu-similar-words pinyin-znabc-similar-words
         chars)

    (dolist (spinyin spinyin-list)
      (setq personal-words
            (append personal-words
                    (car (pyim-choices-get:personal spinyin))))
      (setq pinyin-dict-words
            (append pinyin-dict-words
                    (car (pyim-choices-get:dicts spinyin))))
      (setq chars
            (append chars
                    (car (pyim-choices-get:chars spinyin)))))

    ;; Pinyin shouzimu similar words
    (let ((words (pyim-choices-get:pinyin-shouzimu (car spinyin-list))))
      (setq pinyin-shouzimu-similar-words (car (cdr words))))

    ;; Pinyin znabc-style similar words
    (let ((words (pyim-choices-get:pinyin-znabc (car spinyin-list))))
      (setq pinyin-znabc-similar-words (car (cdr words))))

    ;; Debug
    (when pyim-debug
      (princ (list :spinyin-list spinyin-list
                   :personal-words personal-words
                   :pinyin-dict-words pinyin-dict-words
                   :pinyin-shouzimu-words pinyin-shouzimu-similar-words
                   :pinyin-znabc-similar-words pinyin-znabc-similar-words
                   :chars chars)))

    (delete-dups
     (delq nil
           `(,@personal-words
             ,@pinyin-dict-words
             ,@(when (and pinyin-dict-words
                          (not (member (car pinyin-dict-words) pinyin-shouzimu-similar-words)))
                 pinyin-shouzimu-similar-words)
             ,@pinyin-znabc-similar-words
             ,@chars)))))

(defun pyim-choices-get:pinyin-znabc (spinyin)
  ;; 将输入的拼音按照声母和韵母打散，得到尽可能多的拼音组合，
  ;; 查询这些拼音组合，得到的词条做为联想词。
  (when (member 'pinyin-znabc pyim-backends)
    (list nil (pyim-possible-words
               (pyim-possible-words-py spinyin)))))

(defun pyim-choices-get:pinyin-shouzimu (spinyin)
  ;; 如果输入 "ni-hao" ，搜索 code 为 "n-h" 的词条做为联想词。
  ;; 搜索首字母得到的联想词太多，这里限制联想词要大于两个汉字并且只搜索
  ;; 个人文件。
  (when (and (member 'pinyin-shouzimu pyim-backends)
             (> (length spinyin) 1))
    (let ((py-str-shouzimu (pyim-code-concat spinyin t 'quanpin)))
      (list nil (gethash py-str-shouzimu pyim-personal-dict-cache)))))

(defun pyim-choices-get:personal (spinyin)
  (when (member 'personal pyim-backends)
    (let ((py-str (pyim-code-concat spinyin nil 'quanpin)))
      (list (pyim-dcache-get py-str pyim-personal-dict-cache) nil))))

(defun pyim-choices-get:dicts (spinyin)
  (when (member 'dicts pyim-backends)
    (let ((py-str (pyim-code-concat spinyin nil 'quanpin)))
      (list (pyim-dcache-get py-str pyim-dict-cache) nil))))

(defun pyim-choices-get:chars (spinyin)
  (when (member 'chars pyim-backends)
    (let ((py-str (pyim-code-concat spinyin nil 'quanpin)))
      (list (pyim-dcache-get (concat (caar spinyin) (cdar spinyin)))
            nil))))

(defun pyim-sort-words:count (words-list)
  "根据 `pyim-property-file' 提供的信息，对 `words-list' 中的词条进行排序。"
  (sort words-list
        #'(lambda (a b)
            (let ((count-a (or (gethash a pyim-personal-words-count-cache) 0))
                  (count-b (or (gethash b pyim-personal-words-count-cache) 0)))
              (> count-a count-b)))))

(defun pyim-spinyin-build-chinese-regexp (spinyin &optional match-beginning
                                                  first-equal all-equal)
  "这个函数生成一个 regexp ，用这个 regexp 可以搜索到
拼音匹配 `spinyin' 的中文字符串。"
  (let* ((spinyin (mapcar
                   #'(lambda (x)
                       (concat (car x) (cdr x)))
                   spinyin))
         (cchar-list
          (let ((n 0) results)
            (dolist (py spinyin)
              (push
               (mapconcat #'identity
                          (pyim-pinyin2cchar-get
                           py
                           (or all-equal
                               (and first-equal
                                    (= n 0)))) "")
               results)
              (setq n (+ 1 n)))
            (nreverse results)))
         (regexp
          (mapconcat
           #'(lambda (x)
               (when (pyim-string-match-p "\\cc" x)
                 (format "[%s]" x)))
           cchar-list
           "")))
    (unless (equal regexp "")
      (concat (if match-beginning "^" "")
              regexp))))

(defun pyim-flatten-list (my-list)
  (cond
   ((null my-list) nil)
   ((atom my-list) (list my-list))
   (t (append (pyim-flatten-list (car my-list))
              (pyim-flatten-list (cdr my-list))))))

(defun pyim-possible-words (wordspy)
  "根据拼音得到可能的词组。例如：
  (pyim-possible-words '((\"p-y\" (\"p\" . \"in\") (\"y\" . \"\"))))
    => (\"拼音\" \"贫铀\" \"聘用\")
"
  (let (words)
    (dolist (word (reverse wordspy))
      (if (listp word)
          (setq words (append words (pyim-dcache-get (car word))))
        (setq words (append words (pyim-dcache-get word)))))
    words))

(defun pyim-possible-words-py (spinyin)
  "所有可能的词组拼音。从第一个字开始，每个字断开形成一个拼音。如果是
完整拼音，则给出完整的拼音，如果是给出声母，则为一个 CONS CELL，CAR 是
拼音，CDR 是拼音列表。例如：

 (setq foo-spinyin (pyim-code-split \"pin-yin-sh-r\" 'quanpin))
  => ((\"p\" . \"in\") (\"y\" . \"in\") (\"sh\" . \"\") (\"r\" . \"\"))

 (pyim-possible-words-py foo-spinyin)
  => (\"pin-yin\" (\"p-y-sh\" (\"p\" . \"in\") (\"y\" . \"in\") (\"sh\" . \"\")) (\"p-y-sh-r\" (\"p\" . \"in\") (\"y\" . \"in\") (\"sh\" . \"\") (\"r\" . \"\")))
 "
  (let (pys fullpy smpy wordlist (full t))
    (if (string< "" (cdar spinyin))
        (setq fullpy (concat (caar spinyin) (cdar spinyin))
              smpy (pyim-essential-py (car spinyin)))
      (setq smpy (caar spinyin)
            full nil))
    (setq wordlist (list (car spinyin)))
    (dolist (py (cdr spinyin))
      (setq wordlist (append wordlist (list py)))
      (if (and full (string< "" (cdr py)))
          (setq fullpy (concat fullpy "-" (car py) (cdr py))
                smpy (concat smpy "-" (pyim-essential-py py))
                pys (append pys (list fullpy)))
        (setq full nil
              smpy (concat smpy "-" (pyim-essential-py py))
              pys (append pys (list (cons smpy wordlist))))))
    ;; (message "%s: %s" pys wordlist))
    pys))

(defun pyim-essential-py (py)
  "一个拼音中的主要部分，如果有声母返回声母，否则返回韵母"
  (if (string< "" (car py))
      (car py)
    (cdr py)))
;; #+END_SRC

;; *** 核心函数：拼音字符串处理函数
;; `pyim-handle-string' 这个函数是一个重要的 *核心函数* ，其大致工作流程为：
;; 1. 查询拼音字符串 `pyim-current-key' 得到： 待选词列表
;;    `pyim-current-choices' 和 当前选择的词条 `pyim-current-key'
;; 2. 显示备选词条和选择备选词等待用户选择。

;; #+BEGIN_SRC emacs-lisp
(defun pyim-handle-string ()
  (let ((scheme-name pyim-default-scheme)
        (str pyim-current-key)
        userpos wordspy)
    (setq pyim-spinyin-list (pyim-code-split str scheme-name)
          pyim-pinyin-position 0)
    (unless (and (pyim-spinyin-validp (car pyim-spinyin-list))
                 (progn
                   (setq userpos (pyim-pinyin-user-divide-pos str)
                         pyim-current-key (pyim-pinyin-restore-user-divide
                                           (pyim-code-concat (car pyim-spinyin-list) nil scheme-name)
                                           userpos))
                   (setq pyim-current-choices (list (delete-dups (pyim-choices-get pyim-spinyin-list))))
                   (when  (car pyim-current-choices)
                     (setq pyim-current-pos 1)
                     (pyim-update-current-str)
                     (pyim-page-format-page)
                     (pyim-show)
                     t)))
      (setq pyim-current-str (replace-regexp-in-string "-" "" pyim-current-key))
      (setq pyim-guidance-list
            (plist-put pyim-guidance-list
                       :words
                       (format "%s" (replace-regexp-in-string
                                     "-" " " pyim-current-key))))
      (pyim-show))))

;; #+END_SRC

;; ** 处理当前需要插入字符串 `pyim-current-str'
;; Chinese-pyim 使用变量 `pyim-current-str' 保存 *当前需要在 buffer 中插
;; 入的字符串* 。

;; 处理 `pyim-current-str' 的代码分散在多个函数中，可以按照下面的方式分类：
;; 1. 英文字符串：Chinese-pyim 没有找到相应的候选词时（比如：用户输入错
;;    误的拼音），`pyim-current-str' 的值与 `pyim-current-key' 大致相同。
;;    相关代码很简单，分散在 `pyim-handle-string' 或者
;;    `pyim-append-string' 等相关函数。
;; 2. 汉字或者拼音和汉字的混合：当 Chinese-pyim 找到相应的候选词条时，
;;    `pyim-current-str' 的值可以是完全的中文词条，比如：
;;    #+BEGIN_EXAMPLE
;;    你好
;;    #+END_EXAMPLE
;;    或者中文词条＋拼音的混合新式，比如：
;;    #+BEGIN_EXAMPLE
;;    你好bj
;;    #+END_EXAMPLE
;;    这部份代码相对复杂，使用 `pyim-update-current-key' 专门处理。

;; #+BEGIN_SRC emacs-lisp
(defun pyim-append-string (str)
  "append STR to pyim-current-str"
  (setq pyim-current-str (concat pyim-current-str str)))

(defun pyim-update-current-str ()
  "update `pyim-current-str'"
  (let* ((end (pyim-page-end))
         (start (1- (pyim-page-start)))
         (choices (car pyim-current-choices))
         (choice (pyim-subseq choices start end))
         (pos (1- (min pyim-current-pos (length choices))))
         rest)
    (setq pyim-current-str (concat (substring pyim-current-str 0 pyim-pinyin-position)
                                   (pyim-choice (nth pos choices)))
          rest (mapconcat (lambda (py)
                            (concat (car py) (cdr py)))
                          (nthcdr (length pyim-current-str) (car pyim-spinyin-list))
                          "'"))
    (if (string< "" rest)
        (setq pyim-current-str (concat pyim-current-str rest)))))
;; #+END_SRC

;; Chinese-pyim 会使用 emacs overlay 机制在 *待输入buffer* 光标处高亮显示
;; `pyim-current-str'，让用户快速了解当前输入的字符串，具体方式是：
;; 1. 在 `pyim-input-method' 中调用 `pyim-overlays-setup' 创建 overlay ，并
;;    使用变量 `pyim-overlay' 保存，创建时将 overlay 的 face 属性设置为
;;    `pyim-string-face' ，用户可以使用这个变量来自定义 face。
;; 2. 使用函数 `pyim-show' 高亮显示 `pyim-current-str'
;;    1. 清除光标处原来的字符串。
;;    2. 插入 `pyim-current-str'
;;    3. 使用 `move-overlay' 函数调整变量 `pyim-overlay' 中保存的 overlay，
;;       让其符合新插入的字符串。
;; 3. 在 `pyim-input-method' 中调用 `pyim-overlays-delete' ，删除
;;    `pyim-overlay' 中保存的 overlay，这个函数同时也删除了 overlay 中包
;;    含的文本 `pyim-current-str'。

;; 真正在 *待输入buffer* 插入 `pyim-current-str' 字符串的函数是
;; `read-event'，具体见 `pyim-input-method' 相关说明。

;; #+BEGIN_SRC emacs-lisp
(defun pyim-overlays-setup ()
  (let ((pos (point)))
    (if (overlayp pyim-overlay)
        (move-overlay pyim-overlay pos pos)
      (setq pyim-overlay (make-overlay pos pos))
      (if input-method-highlight-flag
          (overlay-put pyim-overlay 'face 'pyim-string-face)))))

(defun pyim-overlays-delete ()
  (if (and (overlayp pyim-overlay) (overlay-start pyim-overlay))
      (delete-overlay pyim-overlay)))
;; #+END_SRC

;; ** 显示和选择备选词条
;; *** 构建词条菜单字符串
;; Chinese-pyim 内建两种方式显示选词框：

;; 1. 使用 `pyim-minibuffer-message' 函数在 minibuffer 中显示选词框。
;; 2. 使用 `pyim-tooltip-show' 函数在光标处创建一个 tooltip 来显示选词框。

;; 两种方式的基本原理相同：通过 *待选词列表* 构建为一个字符串，然后显示这个字符串。
;; 用户可以根据这个字符串的提示，来执行相应的动作，比如按空格确认当前选择的词条或
;; 者按数字选择这个数字对应的词条。比如：

;; #+BEGIN_EXAMPLE
;; "1. 你好 2. 倪皓 3. 你 4.泥 ..."
;; #+END_EXAMPLE

;; Chinese-pyim 使用 `pyim-current-choices' 来保存 *待选词列表* ，我们以
;; "nihao" 对应的 `pyim-current-choices' 的值为例，来说明选词框相关的操作
;; 函数。

;; #+BEGIN_EXAMPLE
;; ("你好" "倪皓" "泥" "你" "呢" "拟" "逆" "腻" "妮" "怩" "溺" "尼" "禰" "齯" "麑" "鲵" "蜺" "衵" "薿" "旎" "睨" "铌" "昵" "匿" "倪" "霓" "暱" "柅" "猊" "郳" "輗" "坭" "惄" "堄" "儗" "伲" "祢" "慝")
;; #+END_EXAMPLE

;; minibuffer 或者 tooltip 选词框中显示的字符串通过
;; `pyim-guidance-format-function' 变量对应的函数生成,
;; chinese-pyim 当前内置了两个 format 函数：

;; 1. pyim-guidance-format-function-two-lines
;; 2. pyim-guidance-format-function-one-line

;; 这些函数会根据 `pyim-guidance-list' 中的信息来得到所需要的字符串。

;;  *待选词列表* 一般都很长，不可能在一行中完全显示，所以 Chinese-pyim 使
;;  用了 page 的概念，比如，上面的 “nihao” 的 *待选词列表* 就可以逻辑的分
;;  成5页：

;; #+BEGIN_EXAMPLE
;; ("你好"  倪皓"  "泥"  "你"  "呢"  "拟"  "逆"  "腻"  "妮"   ;第1页
;;  "怩"    "溺"   "尼"  "禰"  "齯"  "麑"  "鲵"  "蜺"  "衵"   ;第2页
;;  "薿"    "旎"   "睨"  "铌"  "昵"  "匿"  "倪"  "霓"  "暱"   ;第3页
;;  "柅"    "猊"   "郳"  "輗"  "坭"  "惄"  "堄"  "儗"  "伲"   ;第4页
;;  "祢"    "慝"                                              ;第5页)
;; #+END_EXAMPLE

;; 用户可以使用变量 `pyim-page-length' 自定义每一页显示词条的数量，默认设
;; 置为9。

;; `pyim-current-pos' 的取值以及 `pyim-page-length' 的设定值，共同决定了
;; Chinese-pyim 需要显示哪一页，我们以一个表格来表示上述 *待选词列表* ：

;; |       |          |       |         |      |      |      |      |      |          |
;; |-------+----------+-------+---------+------+------+------+------+------+----------|
;; | 第1页 | "你好"   | 倪皓" | "泥"    | "你" | "呢" | "拟" | "逆" | "腻" | "妮"     |
;; | 第2页 | "怩"     | "溺"  | "尼"    | "禰" | "齯" | "麑" | "鲵" | "蜺" | "衵"     |
;; | 第3页 | -B- "薿" | "旎"  | -A-"睨" | "铌" | "昵" | "匿" | "倪" | "霓" | -E- "暱" |
;; | 第4页 | "柅"     | "猊"  | "郳"    | "輗" | "坭" | "惄" | "堄" | "儗" | "伲"     |
;; | 第5页 | "祢"     | "慝"  |         |      |      |      |      |      |          |

;; 假设 `pyim-current-pos' 为 A 所在的位置。那么：
;; 1. 函数 `pyim-page-current-page' 返回值为3， 说明当前 page 为第3页。
;; 2. 函数 `pyim-page-total-page'  返回值为5，说明 page 共有5页。
;; 3. 函数 `pyim-page-start' 返回 B 所在的位置。
;; 4. 函数 `pyim-page-end' 返回 E 所在的位置。
;; 5. 函数 `pyim-page-format-page' 会从 `pyim-current-choices' 中提取一个
;;    sublist:
;;    #+BEGIN_EXAMPLE
;;    ("薿" "旎" "睨" "铌" "昵" "匿" "倪" "霓" "暱")
;;    #+END_EXAMPLE
;;    这个 sublist 的起点为  `pyim-page-start' 的返回值，终点为
;;    `pyim-page-end' 的返回值。然后使用这个 sublist 来构建类似下面的字符
;;    串，并保存到 `pyim-guidance-list'  :words 关键字对应的位置。
;;    #+BEGIN_EXAMPLE
;;    "1. 薿 2.旎 3.睨 4.铌 5.昵 6.匿 7.倪 8.霓 9.暱"
;;    #+END_EXAMPLE

;; `pyim-page-next-page' 这个命令用来翻页，其原理是：改变 `pyim-current-pos'的
;; 取值，假设一次只翻一页，那么这个函数所做的工作就是：
;; 1. 首先将 `pyim-current-pos' 增加 `pyim-page-length' ，确保其指定的位
;;    置在下一页。
;; 2. 然后将 `pyim-current-pos' 的值设定为 `pyim-page-start' 的返回值，确
;;    保 `pyim-current-pos' 的取值为下一页第一个词条的位置。
;; 3. 最后调用 `pyim-page-format-page' 来重新设置 `pyim-guidance-list' 。

;; #+BEGIN_SRC emacs-lisp
;;;  page format
(defun pyim-subseq (list from &optional to)
  (if (null to) (nthcdr from list)
    (butlast (nthcdr from list) (- (length list) to))))

(defun pyim-mod (x y)
  "like `mod', but when result is 0, return Y"
  (let ((base (mod x y)))
    (if (= base 0)
        y
      base)))

(defun pyim-choice (choice)
  (if (consp choice)
      (car choice)
    choice))

(defun pyim-page-current-page ()
  (1+ (/ (1- pyim-current-pos) pyim-page-length)))

(defun pyim-page-total-page ()
  (1+ (/ (1- (length (car pyim-current-choices))) pyim-page-length)))

(defun pyim-page-start ()
  "计算当前所在页的第一个词条的位置"
  (let ((pos (min (length (car pyim-current-choices)) pyim-current-pos)))
    (1+ (- pos (pyim-mod pos pyim-page-length)))))

(defun pyim-page-end (&optional finish)
  "计算当前所在页的最后一个词条的位置，如果 pyim-current-choices 用
完，则检查是否有补全。如果 FINISH 为 non-nil，说明，补全已经用完了"
  (let* ((whole (length (car pyim-current-choices)))
         (len pyim-page-length)
         (pos pyim-current-pos)
         (last (+ (- pos (pyim-mod pos len)) len)))
    (if (< last whole)
        last
      (if finish
          whole
        (pyim-page-end t)))))

(defun pyim-page-format-page (&optional hightlight-current)
  "按当前位置，生成候选词条"
  (let* ((end (pyim-page-end))
         (start (1- (pyim-page-start)))
         (choices (car pyim-current-choices))
         (choice (pyim-subseq choices start end))
         (pos (- (min pyim-current-pos (length choices)) start))
         (i 0))
    (setq pyim-guidance-list
          (plist-put pyim-guidance-list
                     :key
                     (replace-regexp-in-string "-" " " pyim-current-key)))
    (setq pyim-guidance-list
          (plist-put pyim-guidance-list
                     :current-page
                     (pyim-page-current-page)))
    (setq pyim-guidance-list
          (plist-put pyim-guidance-list
                     :total-page
                     (pyim-page-total-page)))
    (setq pyim-guidance-list
          (plist-put pyim-guidance-list
                     :words
                     (mapconcat 'identity
                                (mapcar
                                 (lambda (c)
                                   (setq i (1+ i))
                                   (let (str)
                                     (setq str (if (consp c)
                                                   (concat (car c) (cdr c))
                                                 c))
                                     ;; 高亮当前选择的词条，用于 `pyim-page-next-word'
                                     (if (and hightlight-current
                                              (= i pos))
                                         (format "%d[%s]" i
                                                 (propertize str 'face 'pyim-minibuffer-string-face))
                                       (format "%d.%s " i str))))
                                 choice) "")))))

(defun pyim-page-next-page (arg)
  (interactive "p")
  (if (= (length pyim-current-key) 0)
      (progn
        (pyim-append-string (pyim-translate last-command-event))
        (pyim-terminate-translation))
    (let ((new (+ pyim-current-pos (* pyim-page-length arg) 1)))
      (setq pyim-current-pos (if (> new 0) new 1)
            pyim-current-pos (pyim-page-start))
      (pyim-update-current-str)
      (pyim-page-format-page)
      (pyim-show))))

(defun pyim-page-previous-page (arg)
  (interactive "p")
  (pyim-page-next-page (- arg)))

(defun pyim-page-next-word (arg)
  (interactive "p")
  (if (= (length pyim-current-key) 0)
      (progn
        (pyim-append-string (pyim-translate last-command-event))
        (pyim-terminate-translation))
    (let ((new (+ pyim-current-pos arg)))
      (setq pyim-current-pos (if (> new 0) new 1))
      (pyim-update-current-str)
      (pyim-page-format-page t)
      (pyim-show))))

(defun pyim-page-previous-word (arg)
  (interactive "p")
  (pyim-page-next-word (- arg)))
;; #+END_SRC

;; *** 显示选词框
;; 当`pyim-guidance-list' 构建完成后，Chinese-pyim 使用函数 `pyim-show' 重
;; 新显示选词框，`pyim-show' 会根据 `pyim-use-tooltip' 的取值来决定使用
;; 哪种方式来显示选词框（minibuffer 或者 tooltip ）。

;; #+BEGIN_SRC emacs-lisp
(defun pyim-show ()
  (unless enable-multibyte-characters
    (setq pyim-current-key nil
          pyim-current-str nil)
    (error "Can't input characters in current unibyte buffer"))
  (pyim-delete-region)
  (insert pyim-current-str)
  (move-overlay pyim-overlay (overlay-start pyim-overlay) (point))
  ;; Then, show the guidance.
  (when (and (not input-method-use-echo-area)
             (null unread-command-events)
             (null unread-post-input-method-events))
    (if (eq (selected-window) (minibuffer-window))
        ;; Show the guidance in the next line of the currrent
        ;; minibuffer.
        (pyim-minibuffer-message
         (format "  [%s]\n%s"
                 current-input-method-title
                 (plist-get pyim-guidance-list :words)))
      ;; Show the guidance in echo area without logging.
      (let ((message-log-max nil))
        (if pyim-use-tooltip
            (pyim-tooltip-show
             (funcall pyim-guidance-format-function pyim-guidance-list)
             (overlay-start pyim-overlay))
          (message "%s" (pyim-guidance-format-function-minibuffer pyim-guidance-list)))))))

(defun pyim-guidance-format-function-two-lines (guidance-list)
  "将 guidance-list 格式化为类似下面格式的字符串，这个字符串将在
tooltip 选词框中显示。

+----------------------------+
| ni hao [1/9]               |
| 1.你好 2.你号 ...          |
+----------------------------+

guidance-list 的结构与 `pyim-guidance-list' 的结构相同。"
  (format "=> %s [%s/%s]: \n%s"
          (plist-get guidance-list :key)
          (plist-get guidance-list :current-page)
          (plist-get guidance-list :total-page)
          (plist-get guidance-list :words)))

(defun pyim-guidance-format-function-one-line (guidance-list)
  "将 guidance-list 格式化为类似下面格式的字符串，这个字符串将在
tooltip 选词框中显示。

+-----------------------------------+
| [ni hao]: 1.你好 2.你号 ... (1/9) |
+-----------------------------------+

guidance-list 的结构与 `pyim-guidance-list' 的结构相同。"
  (format "[%s]: %s(%s/%s)"
          (replace-regexp-in-string
           " +" ""
           (plist-get guidance-list :key))
          (plist-get guidance-list :words)
          (plist-get guidance-list :current-page)
          (plist-get guidance-list :total-page)))

(defun pyim-guidance-format-function-vertical (guidance-list)
  "将 guidance-list 格式化为类似下面格式的字符串，这个字符串将在
tooltip 选词框中显示。

+--------------+
| ni hao [1/9] |
| 1.你好       |
| 2.你号 ...   |
+--------------+

guidance-list 的结构与 `pyim-guidance-list' 的结构相同。"
  (format "=> %s [%s/%s]: \n%s"
          (plist-get guidance-list :key)
          (plist-get guidance-list :current-page)
          (plist-get guidance-list :total-page)
          (replace-regexp-in-string
           "]" "]\n"
           (replace-regexp-in-string
            " +" "\n"
            (plist-get guidance-list :words)))))

(defun pyim-guidance-format-function-minibuffer (guidance-list)
  "将 guidance-list 格式化为类似下面格式的字符串，这个字符串
将在 minibuffer 中显示。

+----------------------------------+
| ni hao [1/9] 1.你好 2.你号 ...   |
+----------------------------------+

guidance-list 的结构与 `pyim-guidance-list' 的结构相同。"
  (format "%s [%s/%s]: %s"
          (plist-get guidance-list :key)
          (plist-get guidance-list :current-page)
          (plist-get guidance-list :total-page)
          (plist-get guidance-list :words)))

(defun pyim-delete-region ()
  "Delete the text in the current translation region of E+."
  (if (overlay-start pyim-overlay)
      (delete-region (overlay-start pyim-overlay)
                     (overlay-end pyim-overlay))))

(defun pyim-tooltip-show (string position)
  "在 `position' 位置，使用 pos-tip 或者 popup 显示字符串 `string' 。"
  (let ((frame (window-frame (selected-window)))
        (length (* pyim-page-length 10))
        (tooltip pyim-use-tooltip)
        (pos-tip-usable-p (pyim-tooltip-pos-tip-usable-p)))
    (cond ((or (eq tooltip t)
               (eq tooltip 'popup)
               (and (eq tooltip 'pos-tip)
                    (not pos-tip-usable-p)))
           (popup-tip string :point position :margin 1))
          ((and pos-tip-usable-p
                (eq tooltip 'pos-tip))
           (pos-tip-show-no-propertize string
                                       nil
                                       position nil 15
                                       (round (* (pos-tip-tooltip-width length (frame-char-width frame))
                                                 pyim-tooltip-width-adjustment))
                                       (pos-tip-tooltip-height 2 (frame-char-height frame) frame)
                                       nil nil 35))
          (t (error "`pyim-use-tooltip' 设置不对，请重新设置。")))))

(defun pyim-minibuffer-message (string)
  (message nil)
  (let ((point-max (point-max))
        (inhibit-quit t))
    (save-excursion
      (goto-char point-max)
      (insert string))
    (sit-for 1000000)
    (delete-region point-max (point-max))
    (when quit-flag
      (setq quit-flag nil
            unread-command-events '(7)))))

(defun pyim-tooltip-pos-tip-usable-p ()
  "测试当前环境下 pos-tip 是否可用。"
  (not (or noninteractive
           emacs-basic-display
           (not (display-graphic-p))
           (not (fboundp 'x-show-tip)))))
;; #+END_SRC

;; *** 选择备选词
;; #+BEGIN_SRC emacs-lisp
(defun pyim-page-select-word ()
  (interactive)
  (if (null (car pyim-current-choices))  ; 如果没有选项，输入空格
      (progn
        (setq pyim-current-str (pyim-translate last-command-event))
        (pyim-terminate-translation))
    (let ((str (pyim-choice (nth (1- pyim-current-pos) (car pyim-current-choices))))
          spinyin-list)
      (pyim-create-or-rearrange-word str t)
      (setq pyim-pinyin-position (+ pyim-pinyin-position (length str)))
      (if (>= pyim-pinyin-position (length (car pyim-spinyin-list)))
                                        ; 如果是最后一个，检查
                                        ; 是不是在文件中，没有的话，创
                                        ; 建这个词
          (progn
            (if (not (member pyim-current-str (car pyim-current-choices)))
                (pyim-create-or-rearrange-word pyim-current-str))
            (pyim-terminate-translation)
            ;; Chinese-pyim 使用这个 hook 来处理联想词。
            (run-hooks 'pyim-select-word-finish-hook))
        (setq spinyin-list (delete-dups
                           (mapcar
                            #'(lambda (spinyin)
                                (nthcdr pyim-pinyin-position spinyin))
                            pyim-spinyin-list)))
        (setq pyim-current-choices (list (pyim-choices-get spinyin-list))
              pyim-current-pos 1)
        (pyim-update-current-str)
        (pyim-page-format-page)
        (pyim-show)))))

(defun pyim-page-select-word-by-number ()
  "如果没有可选项，插入数字，否则选择对应的词条"
  (interactive)
  (if (car pyim-current-choices)
      (let ((index (- last-command-event ?1))
            (end (pyim-page-end)))
        (if (> (+ index (pyim-page-start)) end)
            (pyim-show)
          (setq pyim-current-pos (+ pyim-current-pos index))
          (setq pyim-current-str (concat (substring pyim-current-str 0
                                                    pyim-pinyin-position)
                                         (pyim-choice
                                          (nth (1- pyim-current-pos)
                                               (car pyim-current-choices)))))
          (pyim-page-select-word)))
    (pyim-append-string (char-to-string last-command-event))
    (pyim-terminate-translation)))
;; #+END_SRC

;; ** 处理标点符号
;; 常用的标点符号数量不多，所以 Chinese-pyim 没有使用文件而是使用一个变量
;; `pyim-punctuation-dict' 来设置标点符号对应表，这个变量是一个 alist 列表。

;; Chinese-pyim 在运行过程中调用函数 `pyim-translate' 进行标点符号格式的转换。

;; #+BEGIN_SRC emacs-lisp
(defun pyim-translate-get-trigger-char ()
  "检查 `pyim-translate-trigger-char' 是否为一个合理的 trigger char 。

Chinese-pyim 的 translate-trigger-char 要占用一个键位，为了防止用户
自定义设置与输入法冲突，这里需要检查一下这个键位设置的是否合理，
如果不合理，就返回输入法默认设定。"
  (let* ((user-trigger-char pyim-translate-trigger-char)
         (user-trigger-char
          (if (characterp user-trigger-char)
              (char-to-string user-trigger-char)
            (when (= (length user-trigger-char) 1)
              user-trigger-char)))
         (first-char (pyim-scheme-get-option
                      pyim-default-scheme
                      :first-chars))
         (prefer-trigger-chars (pyim-scheme-get-option
                                pyim-default-scheme
                                :prefer-trigger-chars)))
    (if (pyim-string-match-p user-trigger-char first-char)
        (progn
          ;; (message "注意：pyim-translate-trigger-char 设置和当前输入法冲突，使用推荐设置：\"%s\""
          ;;          prefer-trigger-chars)
          prefer-trigger-chars)
      user-trigger-char)))

(defun pyim-translate (char)
  (let* ((str (char-to-string char))
         ;; 注意：`str' 是 *待输入* 的字符对应的字符串。
         (str-before-1 (pyim-char-before-to-string 0))
         (str-before-2 (pyim-char-before-to-string 1))
         (str-before-3 (pyim-char-before-to-string 2))
         (str-before-4 (pyim-char-before-to-string 3))
         ;; 从标点词库中搜索与 `str' 对应的标点列表。
         (punc-list (assoc str pyim-punctuation-dict))
         ;; 从标点词库中搜索与 `str-before-1' 对应的标点列表。
         (punc-list-before-1
          (cl-some (lambda (x)
                     (when (member str-before-1 x) x))
                   pyim-punctuation-dict))
         ;; `str-before-1' 在其对应的标点列表中的位置。
         (punc-posit-before-1
          (cl-position str-before-1 punc-list-before-1
                       :test #'equal))
         (trigger-str (pyim-translate-get-trigger-char)))
    (cond
     ;; 空格之前的字符什么也不输入。
     ((< char ? ) "")

     ;; 这个部份与标点符号处理无关，主要用来快速保存用户自定义词条。
     ;; 比如：在一个中文字符串后输入 2v，可以将光标前两个中文字符
     ;; 组成的字符串，保存到个人词库。
     ((and (member (char-before) (number-sequence ?2 ?9))
           (pyim-string-match-p "\\cc" str-before-2)
           (equal str trigger-str))
      (delete-char -1)
      (pyim-create-word-at-point
       (string-to-number str-before-1))
      "")

     ;; 光标前面的字符为中文字符时，按 v 清洗当前行的内容。
     ((and (not (numberp punc-posit-before-1))
           (pyim-string-match-p "\\cc" str-before-1)
           (equal str trigger-str))
      (funcall pyim-wash-function)
      "")

     ;; 关闭标点转换功能时，只插入英文标点。
     ((not (pyim-punctuation-full-width-p))
      str)

     ;; 当前字符属于 `pyim-punctuation-escape-list'时，
     ;; 插入英文标点。
     ((member (char-before)
              pyim-punctuation-escape-list)
      str)

     ;; 当 `pyim-punctuation-half-width-functions' 中
     ;; 任意一个函数返回值为 t 时，插入英文标点。
     ((cl-some #'(lambda (x)
                   (if (functionp x)
                       (funcall x char)
                     nil))
               pyim-punctuation-half-width-functions)
      str)

     ;; 当光标前面为英文标点时， 按 `pyim-translate-trigger-char'
     ;; 对应的字符后， 自动将其转换为对应的中文标点。
     ((and (numberp punc-posit-before-1)
           (= punc-posit-before-1 0)
           (equal str trigger-str))
      (pyim-punctuation-translate-last-n-punctuations 'full-width)
      "")

     ;; 当光标前面为中文标点时， 按 `pyim-translate-trigger-char'
     ;; 对应的字符后， 自动将其转换为对应的英文标点。
     ((and (numberp punc-posit-before-1)
           (> punc-posit-before-1 0)
           (equal str trigger-str))
      (pyim-punctuation-translate-last-n-punctuations 'half-width)
      "")

     ;; 正常输入标点符号。
     (punc-list
      (pyim-punctuation-return-proper-punct punc-list))

     ;; 当输入的字符不是标点符号时，原样插入。
     (t str))))

(defun pyim-char-before-to-string (num)
  "得到光标前第 `num' 个字符，并将其转换为字符串。"
  (let* ((point (point))
         (point-before (- point num)))
    (when (and (> point-before 0)
               (char-before point-before))
      (char-to-string (char-before point-before)))))

(defun pyim-wash-current-line-function ()
  "清理当前行的内容，比如：删除不必要的空格，等。"
  (interactive)
  (let* ((begin (line-beginning-position))
         (end (point))
         (string (buffer-substring-no-properties begin end))
         new-string)
    (when (> (length string) 0)
      (delete-region begin end)
      (setq new-string
            (with-temp-buffer
              (insert string)
              (goto-char (point-min))
              (while (re-search-forward "\\([，。；？！；、）】]\\)  +\\([[:ascii:]]\\)" nil t)
                (replace-match (concat (match-string 1) (match-string 2))  nil t))
              (goto-char (point-min))
              (while (re-search-forward "\\([[:ascii:]]\\)  +\\([（【]\\)" nil t)
                (replace-match (concat (match-string 1) (match-string 2))  nil t))
              (goto-char (point-min))
              (while (re-search-forward "\\([[:ascii:]]\\)  +\\(\\cc\\)" nil t)
                (replace-match (concat (match-string 1) " " (match-string 2))  nil t))
              (goto-char (point-min))
              (while (re-search-forward "\\(\\cc\\)  +\\([[:ascii:]]\\)" nil t)
                (replace-match (concat (match-string 1) " " (match-string 2))  nil t))
              (buffer-string)))
      (insert new-string))))

;; #+END_SRC

;; 当用户使用 org-mode 以及 markdown 等轻量级标记语言撰写文档时，常常需要输入数字列表，比如：

;; #+BEGIN_EXAMPLE
;; 1. item1
;; 2. item2
;; 3. item3
;; #+END_EXAMPLE

;; 在这种情况下，数字后面输入句号必须是半角句号而不是全角句号，Chinese-pyim 调用 `pyim-translate' 时，
;; 会检测光标前面的字符，如果这个字符属于 `pyim-punctuation-escape-list' ，Chinese-pyim 将输入
;; 半角标点，具体细节见：`pyim-translate'

;; 输入标点的样式的改变（全角或者半角）受三个方面影响：

;; 1. 用户是否手动切换了标点样式？
;; 2  用户是否手动切换到英文输入模式？
;; 3. Chinese-pyim 是否根据环境自动切换到英文输入模式？

;; 三方面的综合结果为： 只要当前的输入模式是英文输入模式，那么输入的标点符号 *必定* 是半角标点，
;; 如果当前输入模式是中文输入模式，那么，输入标点的样式用户可以使用 `pyim-toggle-full-width-punctuation'
;; 手动控制，具体请参考 `pyim-punctuation-full-width-p'。

;; #+BEGIN_SRC emacs-lisp
;;; 切换中英文标点符号
(defun pyim-punctuation-full-width-p ()
  "判断是否需要切换到全角标点输入模式"
  (cl-case (car pyim-punctuation-translate-p)
    (yes t)
    (no nil)
    (auto
     ;; 如果用户手动或者根据环境自动切换为英文输入模式，
     ;; 那么标点符号也要切换为半角模式。
     (and (not pyim-input-ascii)
          (not (pyim-auto-switch-english-input-p))))))

(defun pyim-toggle-full-width-punctuation ()
  (interactive)
  (setq pyim-punctuation-translate-p
        `(,@(cdr pyim-punctuation-translate-p)
          ,(car pyim-punctuation-translate-p)))
  (message
   (cl-case (car pyim-punctuation-translate-p)
     (yes "开启全角标点输入模式。")
     (no "开启半角标点输入模式。")
     (auto "开启全半角标点自动转换模式。"))))
;; #+END_SRC

;; 每次运行 `pyim-toggle-full-width-punctuation' 命令，都会反转变量 `pyim-punctuation-translate-p'
;; 的取值，`pyim-translate' 会检测 `pyim-punctuation-full-width-p' 函数的返回值，当返回值为 t 时，
;; `pyim-translate' 转换标点符号，从而输入全角标点，反之，`pyim-translate' 忽略转换，
;; 从而输入半角标点。

;; 用户也可以使用命令 `pyim-punctuation-translate-at-point' 来切换 *光标前* 标点符号的样式。


;; #+BEGIN_SRC emacs-lisp
;; 切换光标处标点的样式（全角 or 半角）
(defun pyim-punctuation-translate-at-point ()
  (interactive)
  (let* ((current-char (char-to-string (preceding-char)))
         (punc-list
          (cl-some (lambda (x)
                     (when (member current-char x) x))
                   pyim-punctuation-dict)))
    (when punc-list
      (delete-char -1)
      (if (equal current-char (car punc-list))
          (insert (pyim-punctuation-return-proper-punct punc-list))
        (insert (car punc-list))))))

(defun pyim-punctuation-translate-last-n-punctuations (&optional punct-style)
  "将光标前面连续的n个标点符号进行全角/半角转换，当 `punct-style' 设置为 `full-width' 时，
所有的标点符号转换为全角符号，设置为 `half-width' 时，转换为半角符号。"
  (interactive)
  (let ((punc-list (pyim-flatten-list pyim-punctuation-dict))
        (punct-style
         (or punct-style
             (intern (completing-read
                      "将光标前的标点转换为" '("full-width" "half-width")))))
        (count 0)
        number last-puncts result)
    (while count
      (let ((str (pyim-char-before-to-string count)))
        (if (member str punc-list)
            (progn
              (push str last-puncts)
              (setq count (+ count 1)))
          (setq number count)
          (setq count nil))))
    ;; 删除旧的标点符号
    (delete-char (- 0 number))
    (dolist (punct last-puncts)
      (dolist (puncts pyim-punctuation-dict)
        (let ((position (cl-position punct puncts :test #'equal)))
          (when position
            (cond
             ((eq punct-style 'full-width)
              (if (= position 0)
                  (push (pyim-punctuation-return-proper-punct puncts) result)
                (push punct result)))
             ((eq punct-style 'half-width)
              (if (= position 0)
                  (push punct result)
                (push (car puncts) result))))))))
    (insert (mapconcat #'identity (reverse result) ""))))
;; #+END_SRC

;; 使用上述命令切换光标前标点符号的样式时，我们使用函数 `pyim-punctuation-return-proper-punct'
;; 来处理成对的全角标点符号， 比如：

;; #+BEGIN_EXAMPLE
;; “”
;; ‘’
;; #+END_EXAMPLE
;; 这个函数的参数是一个标点符号对应表，类似：

;; #+BEGIN_EXAMPLE
;; ("." "。")
;; #+END_EXAMPLE

;; 第一个元素为半角标点，第二个和第三个元素（如果有）为对应的全角标点。

;; #+BEGIN_EXAMPLE
;; (list (pyim-punctuation-return-proper-punct '("'" "‘" "’"))
;;       (pyim-punctuation-return-proper-punct '("'" "‘" "’")))
;; #+END_EXAMPLE

;; 结果为:
;; : ("’" "‘")

;; 简单来说，定义这个函数的目的是为了实现类似的功能：如果第一次输入的标点是：（‘）时，
;; 那么下一次输入的标点就是（’）。


;; #+BEGIN_SRC emacs-lisp
;; 处理标点符号
(defun pyim-punctuation-return-proper-punct (punc-list &optional before)
  "返回合适的标点符号，`punc-list'为标点符号列表，其格式类似：
      `(\",\" \"，\") 或者：`(\"'\" \"‘\" \"’\")
当 `before' 为 t 时，只返回切换之前的结果，这个用来获取切换之前
的标点符号。"
  (let* ((str (car punc-list))
         (punc (cdr punc-list))
         (switch-p (cdr (assoc str pyim-punctuation-pair-status))))
    (if (= (safe-length punc) 1)
        (car punc)
      (if before
          (setq switch-p (not switch-p))
        (setf (cdr (assoc str pyim-punctuation-pair-status))
              (not switch-p)))
      (if switch-p
          (car punc)
        (nth 1 punc)))))

;; #+END_SRC

;; 函数 `pyim-punctuation-return-proper-punct' 内部，我们使用变量 `pyim-punctuation-pair-status'
;; 来记录“成对”中文标点符号的状态。

;; ** 处理特殊功能触发字符（单字符快捷键）
;; 输入中文的时候，我们需要快速频繁的执行一些特定的命令，
;; 最直接的方法就是将上述命令绑定到一个容易按的快捷键上，但遗憾的是 emacs 大多数容易按
;; 的快捷键都 *名花有主* 了，甚至找一个 “Ctrl＋单字符”的快捷键都不太容易，特殊功能触发
;; 字符，可以帮助我们实现“单字符”快捷键，类似 org-mode 的 speed key。

;; 默认情况下，我们可以使用特殊功能触发字符执行下面两个操作：
;; 1. 快速切换中英文标点符号的样式：当光标前的字符是一个标点符号时，按"v"可以切换这个标点的样式。
;;    比如：光标在A处的时候，按 "v" 可以将A前面的全角逗号转换为半角逗号。
;;    #+BEGIN_EXAMPLE
;;    你好，-A-
;;    #+END_EXAMPLE
;;    按 "v" 后
;;    #+BEGIN_EXAMPLE
;;    你好,-A-
;;    #+END_EXAMPLE
;; 2. 快速将光标前的词条添加到词库：当光标前的字符是中文字符时，按 "num" + "v" 可以将光标前 num 个中文汉字
;;    组成的词条添加到个人词频文件中，比如：当光标在A处时，按"4v"可以将“的红烧肉”这个词条加入个人词频文件，默认
;;    num不超过9。
;;    #+BEGIN_EXAMPLE
;;    我爱吃美味的红烧肉-A-
;;    #+END_EXAMPLE

;; 值得注意的是，这种方式如果添加的功能太多，会造成许多潜在的冲突。

;; 用户可以使用变量 `pyim-translate-trigger-char' 来设置触发字符，
;; 默认的触发字符是："v", 选择这个字符的理由是：

;; 1. "v" 不是有效的声母，不会对中文输入造成太大的影响。
;; 2. "v" 字符很容易按。

;; Chinese-pyim 使用函数 `pyim-translate' 来处理特殊功能触发字符。
;; 当待输入的字符是触发字符时，`pyim-translate' 根据光标前的字符的不同
;; 来调用不同的功能，具体见 `pyim-translate' ：


;; ** 与拼音输入相关的用户命令
;; *** 删除拼音字符串最后一个字符
;; #+BEGIN_SRC emacs-lisp
(defun pyim-delete-last-char ()
  (interactive)
  (if (> (length pyim-current-key) 1)
      (progn
        (setq pyim-current-key (substring pyim-current-key 0 -1))
        (pyim-handle-string))
    (setq pyim-current-str "")
    (pyim-terminate-translation)))
;; #+END_SRC

;; *** 删除拼音字符串最后一个拼音
;; #+BEGIN_SRC emacs-lisp
(defun pyim-backward-kill-py ()
  (interactive)
  (if (string-match "['-][^'-]+$" pyim-current-key)
      (progn (setq pyim-current-key
                   (replace-match "" nil nil pyim-current-key))
             (pyim-handle-string))
    (setq pyim-current-key "")
    (setq pyim-current-str "")
    (pyim-terminate-translation)))
;; #+END_SRC

;; *** 将光标前的拼音字符串转换为中文
;; #+BEGIN_SRC emacs-lisp
(defun pyim-convert-pinyin-at-point ()
  (interactive)
  (unless (equal input-method-function 'pyim-input-method)
    (toggle-input-method))
  (let* ((case-fold-search nil)
         (pyim-force-input-chinese t)
         (string (if mark-active
                     (buffer-substring-no-properties
                      (region-beginning) (region-end))
                   (buffer-substring (point) (line-beginning-position))))
         pinyin length)
    (and (string-match "[a-z'-]+ *$" string)
         (setq pinyin (match-string 0 string))
         (setq length (length pinyin))
         (setq pinyin (replace-regexp-in-string " +" "" pinyin)))
    (when (and length (> length 0))
      (delete-char (- 0 length))
      (insert (mapconcat #'char-to-string
                         (pyim-input-method pinyin) "")))))
;; #+END_SRC

;; *** 取消当前输入
;; #+BEGIN_SRC emacs-lisp
(defun pyim-quit-clear ()
  (interactive)
  (setq pyim-current-str "")
  (pyim-terminate-translation))
;; #+END_SRC
;; *** 字母上屏
;; #+BEGIN_SRC emacs-lisp
(defun pyim-quit-no-clear ()
  (interactive)
  (setq pyim-current-str (replace-regexp-in-string "-" ""
                                                   pyim-current-key))
  (pyim-terminate-translation))
;; #+END_SRC

;; *** Chinese-pyim 取消激活
;; #+BEGIN_SRC emacs-lisp
(defun pyim-inactivate ()
  (interactive)
  (mapc 'kill-local-variable pyim-local-variable-list))
;; #+END_SRC

;; *** 切换中英文输入模式
;; #+BEGIN_SRC emacs-lisp
(defun pyim-toggle-input-ascii ()
  "Chinese-pyim 切换中英文输入模式。同时调整标点符号样式。"
  (interactive)
  (setq pyim-input-ascii
        (not pyim-input-ascii)))
;; #+END_SRC

;; *** 为 isearch 添加拼音搜索功能
;; #+BEGIN_SRC emacs-lisp
(defun pyim-isearch-build-search-regexp (pystr)
  "这个函数用于 isearch 中文 *拼音* 搜索，
根据 str 构建一个 regexp, 比如：

\"nihao\" -> \"[你呢...][好号...] \\| nihao\""
  (if (pyim-string-match-p "[^a-z']+" pystr)
      pystr
    (let* ((spinyin-list
            ;; Slowly operating, need to improve.
            (pyim-code-split pystr pyim-default-scheme))
           (regexp-list
            (mapcar
             #'(lambda (spinyin)
                 (pyim-spinyin-build-chinese-regexp spinyin))
             spinyin-list))
           (regexp
            (when regexp-list
              (mapconcat #'identity
                         (delq nil regexp-list)
                         "\\|")))
           (regexp
            (if (> (length regexp) 0)
                (concat pystr "\\|" regexp)
              pystr)))
      regexp)))

(defun pyim-isearch-pinyin-search-function ()
  "这个函数为 isearch 相关命令添加中文拼音搜索功能，
用于 `isearch-search-fun-function' 。"
  (if pyim-isearch-enable-pinyin-search
      ;; Return the function to use for pinyin search
      `(lambda (string &optional bound noerror count)
         (if (pyim-string-match-p "[^a-z]+" string)
             (funcall (isearch-search-fun-default) string bound noerror count)
           (funcall (if ,isearch-forward
                        're-search-forward
                      're-search-backward)
                    (pyim-isearch-build-search-regexp string) bound noerror count)))
    ;; Return default function
    (isearch-search-fun-default)))

(setq isearch-search-fun-function 'pyim-isearch-pinyin-search-function)
;; #+END_SRC


;; * Footer
;; #+BEGIN_SRC emacs-lisp
(provide 'chinese-pyim-core)

;;; chinese-pyim-core.el ends here
;; #+END_SRC
