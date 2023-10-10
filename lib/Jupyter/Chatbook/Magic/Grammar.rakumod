grammar Jupyter::Chatbook::Magic::Grammar {
    rule TOP { <magic> }
    rule magic {
        [ '%%' | '#%' ]
        [ <chat-meta-spec> || <chat-id-spec> || <llm-args> || <args> || <simple> || <filter> || <always> ]
    }
    token simple {
        $<key>=[ 'javascript' | 'bash' | <mermaid> ]
    }
    token param-sep { \h* ',' \h* | \h+ }
    token args {
        $<key>='run' $<rest>=.*
    }
    regex llm-args {
        $<key>=[ 'openai' | 'dalle' | 'palm' | 'chat' ] [\h* '>' \h* $<output-mime>=<mime> | \h* ] [ <.param-sep> <magic-list-of-params> \h*]? \h*
    }
    token chat-id-spec {
        <chat> [ '-' | '_' | ':' | \h+ ] $<chat-id>=(<.alnum> <-[,;\s]>*) [\h* '>' \h* $<output-mime>=<mime>]? [<.param-sep> <magic-list-of-params> \h*]? \h*
    }
    token chat-meta-spec {
        || <chat> \h+ ['meta' \h+]? $<meta-command>='all'
        || <chat> [ '-' | '_' | ':' | \h+ ] $<chat-id>=(<-[,;\s]>*) \h+ $<meta-command>= [ 'meta' | 'prompt' | 'drop' | 'clear' | 'all' ] [<.param-sep> <magic-list-of-params> \h*]? \h*
    }
    rule filter {
        [
        | $<out>=<mime> ['>' $<stdout>=<mime>]?
           | '>' $<stdout>=<mime>
       ]
    }
    token always {
        $<key>='always' <.ws> $<subcommand>=[ '' | 'prepend' | 'append' | 'show' | 'clear' ] $<rest>=.*
    }
    token mime {
        | <html>
        | <markdown>
        | <latex>
        | <javascript>
        | <openai>
        | <dalle>
        | <palm>
        | <mermaid>
        | <chat>
    }
    token html {
        'html'
    }
    token markdown {
        'markdown' || 'md'
    }
    token javascript {
        'javascript' || 'js'
    }
    token latex {
        'latex' [ '(' $<enclosure>=[ \w | '*' ]+ ')' ]?
    }
    token openai {
        'openai'
    }
    token dalle {
        'dalle'
    }
    token palm {
        'palm'
    }
    token mermaid {
        'mermaid' || 'mmd'
    }
    token chat {
        'chat'
    }

    # Magic list of assignments
    regex magic-list-of-params { <magic-assign-pair>+ % [\h* ',' \h*] }

    # Quoted string, mostly for prompts
    regex quoted-string { '\'' ~ '\'' <-[']>*  || '"' ~ '"' <-["]>*  || '{' ~ '}' <-[{}]>* || '⎡' ~ '⎦' <-[⎡⎦]>* || '«' ~ '»' <-[«»]>* }

    # Magic pair assignment
    regex magic-assign-pair { $<param>=([<.alpha> | '.' | '_' | '-']+) \h* '=' \h* $<value>=(<quoted-string> || <-[{},\s]>*) }
}

