use emacs::{Env, Value, defun};
use std::rc::Rc;
use unchecked_refcell::UncheckedRefCell as RefCell;
use windows::{
    Win32::{
        Foundation::{HINSTANCE, HMODULE, HWND, LPARAM, LRESULT, WPARAM},
        System::{
            Com::{COINIT_APARTMENTTHREADED, CoInitializeEx},
            LibraryLoader::{
                GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
                GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, GetModuleHandleExW,
            },
            Threading::GetCurrentThreadId,
            WinRT::{RO_INIT_SINGLETHREADED, RoInitialize},
        },
        UI::{
            Input::KeyboardAndMouse::{GetActiveWindow, SetFocus},
            WindowsAndMessaging::{self, GetWindowThreadProcessId, MSG},
        },
    },
    core::{Interface, PCWSTR, PWSTR},
};
emacs::plugin_is_GPL_compatible!();

include!("webview.rs");
include!("lisp.rs");
include!("hooks.rs");

struct Callback {
    rcb: Box<dyn FnOnce(&Env, Value) -> LispResult<()>>,
    gcb: Rc<GlobalRef>,
}

thread_local! {
    static WEBVIEWS: RefCell<Vec<Webview>> = RefCell::new(Vec::new());
    static EVENTS: RefCell<Vec<Box<dyn FnOnce(&Env)>>> = RefCell::new(Vec::new());
    static CALLBACKS: RefCell<Vec<Callback>> = RefCell::new(Vec::new());
}

pub fn initialize_com() {
    unsafe {
        // should be paired with RoUnintialize, but emacs dynamic module has no unload mechanism
        let _ = RoInitialize(RO_INIT_SINGLETHREADED).unwrap();
        // RoInitialize should be sufficient, but sometimes I see CoInitialize not called error
        let _ = CoInitializeEx(None, COINIT_APARTMENTTHREADED).unwrap();
        // let _ = CoInitialize(None);
        let id = GetCurrentThreadId();
        println!("lisp thread id = {id}");
    }
}

