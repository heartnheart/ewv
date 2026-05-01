;; -*- lexical-binding: t; -*-

(require 'url)
(require 'json)

;;; load ewv.dll
;; 先在根目录放一个 debug 版本的 ewv.dll, 方便其他人使用
;; TODO 应该分发 release dll, 特别是后面增加 make-pipe-process 之后还需要针对 ucrt 和 gnu 分发两个不同的 dll
(defvar ec//src-dir (file-name-directory (or load-file-name (buffer-file-name))))
(defvar ec//dll-path (expand-file-name "target/debug/ewv_native.dll" ec//src-dir))

(defun ec//download-ewv-dll ()
  "Download ewv_native.dll from latest GitHub release."
  (let* ((api-url "https://api.github.com/repos/heartnheart/ewv/releases/latest")
         (json-object-type 'alist)
         (json-array-type 'list)
         (json-key-type 'symbol)
         (buf (url-retrieve-synchronously api-url t t 10)))
    (unless buf
      (error "Failed to fetch release info"))
    (with-current-buffer buf
      (goto-char (point-min))
      (re-search-forward "^$")
      (let* ((json (json-read))
             (assets (alist-get 'assets json))
             (dll-asset
              (seq-find
               (lambda (asset)
                 (string= (alist-get 'name asset) "ewv_native.dll"))
               assets)))
        (kill-buffer buf)
        (unless dll-asset
          (error "ewv_native.dll not found in latest release"))
        (let ((download-url (alist-get 'browser_download_url dll-asset)))
          (message "Downloading ewv_native.dll...")
          (url-copy-file download-url ec//dll-path t)
          (message "Downloaded ewv_native.dll to %s" ec//dll-path))))))

(unless (file-exists-p ec//dll-path)
  (setq ec//dll-path (expand-file-name "ewv_native.dll" ec//src-dir)))
(unless (file-exists-p ec//dll-path)
  (if (y-or-n-p "[ewv] Download `ewv_native.dll' file")
      (ec//download-ewv-dll)
    (user-error "[ewv] Quit, `ewv' require `ewv_native.dll'.")))

(load ec//dll-path)




(defun ec//get-window-edges(&optional window)
  (window-body-pixel-edges window))

;; 配合 dynamic module 处理异步事件 https://nullprogram.com/blog/2017/02/14/
(define-key special-event-map [language-change]
            (lambda ()
              (interactive)
              (ent/process-events)))

;;; core
(defun ec//get-frame-hwnd (&optional frame)
  "Emasc frame to win32 HWND"
  (string-to-number (frame-parameter (or frame (selected-frame)) 'window-id) 10))


(defun ec//eval-string (string)
  "Called from js. Always convert result to string"
  (condition-case err
      (format "%s" (eval (car (read-from-string (format "(progn %s)" string)))))
    (error (ec//print "ewv--eval-string error: %S" err))
    ))


;;; debug
(defun ec/open-task-manager()
  (interactive)
  (ent/webview-open-task-manager)
  )
(defun ec//print(format-exp &rest args)
  (ent/print (apply #'format format-exp args)))

;; https://www.reddit.com/r/emacs/comments/8pbbpe/comment/e0an4xy/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
(defmacro ec//with-struct-slots (spec-list type inst &rest body)
  (declare (indent 3) (debug (sexp sexp def-body)))
  ;; Transform the spec-list into a cl-symbol-macrolet spec-list.
  (macroexp-let2 nil inst inst
    `(cl-symbol-macrolet
         ,(mapcar (lambda (entry)
                    (let* ((slot-var  (if (listp entry) (car entry) entry))
			   (slot (if (listp entry) (cadr entry) entry))
			   (idx (cl-struct-slot-offset type slot)))
                      (list slot-var `(aref ,inst ,idx))))
                  spec-list)

       (unless (cl-typep ,inst ',type)
	 (error "%s is not a %s" ',inst ',type))

       ,@body)))


(ent/init-frame-thread-hook)

;;; end
(provide 'ewv-core)


;; Local Variables:
;; read-symbol-shorthands: (("ec//" . "ewv-core--")
;;                          ("ec/" . "ewv-core-")
;;                          ("ent/" . "ewv-native-")
;;                          )
;; coding: utf-8-unix
;; End:
