role Jupyter::Chatbook::Response {
    method output { ... }
    method output-mime-type { ... }
    method exception { ... }
    method incomplete { ... }
    method output-raw { ... }
}

class Jupyter::Chatbook::Response::Abort does Jupyter::Chatbook::Response {
    method output { "[got sigint on thread {$*THREAD.id}]" }
    method output-mime-type { 'text/plain' }
    method exception { True }
    method incomplete { False }
    method output-raw { 'aborted' }
}
