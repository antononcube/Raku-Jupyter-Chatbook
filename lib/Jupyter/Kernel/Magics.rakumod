unit class Jupyter::Kernel::Magics;
use Jupyter::Kernel::Response;
use WWW::OpenAI;
use WWW::PaLM;
use WWW::MermaidInk;
use Clipboard;  # copy-to-clipboard
use Text::Plot; # from-base64
use Text::SubParsers;
use LLM::Functions;

my class Result does Jupyter::Kernel::Response {
    has $.output is default(Nil);
    method output-raw { $.output }
    has $.output-mime-type is rw;
    has $.stdout;
    has $.stdout-mime-type;
    has $.stderr;
    has $.exception;
    has $.incomplete;
    method Bool {
        True;
    }
}

#| Container of always magics registered
my class Always {
    has @.prepend is rw;
    has @.append is rw;
}

#| Globals
my $always = Always.new;

my %chats;

#===========================================================

our sub to-single-quoted(Str $s) {
    '\'' ~ $s ~ '\''
}

our sub to-unquoted(Str $ss is copy) {
    if $ss ~~ / ^ '\'' (.*) '\'' $ / { return ~$0; }
    if $ss ~~ / ^ '"' (.*) '"' $ / { return ~$0; }
    if $ss ~~ / ^ '{' (.*) '}' $ / { return ~$0; }
    if $ss ~~ / ^ '⎡' (.*) '⎦' $ / { return ~$0; }
    return $ss;
}

#===========================================================
class Magic::Filter {
    method transform($str) {
        # no transformation by default
        $str;
    }
    method mime-type {
        # text/plain by default
        'text/plain';
    }
}
class Magic::Filter::HTML is Magic::Filter {
    has $.mime-type = 'text/html';
}
class Magic::Filter::Markdown is Magic::Filter {
    has $.mime-type = 'text/markdown';
}
class Magic::Filter::Javascript is Magic::Filter {
    has $.mime-type = 'application/javascript';
}
class Magic::Filter::Latex is Magic::Filter {
    has $.mime-type = 'text/latex';
    has Str $.enclosure;
    method transform($str) {
        if $.enclosure {
            return
                    '\begin{' ~ $.enclosure ~ "}\n"
                            ~ $str ~ "\n" ~
                            '\end{' ~ $.enclosure  ~ "}\n";
        }
        return $str;
    }
}

class Magic {
    method preprocess($code is rw) { Nil }
    method postprocess(:$result! ) { $result }
}

my class Magic::JS is Magic {
    method preprocess($code) {
        return Result.new:
                output => $code,
                output-mime-type => 'application/javascript';
    }
}

my class Magic::Bash is Magic {
    method preprocess($code) {
        my $cmd = (shell $code, :out, :err);

        return Result.new:
                output => $cmd.out.slurp(:close),
                output-mime-type => 'text/plain',
                stdout => $cmd.err.slurp(:close),
                stdout-mime-type => 'text/plain',
                ;
    }
}

my class Magic::LLM is Magic {
    has %.args;
    method pre-process-args() {
        my $ep = exact-parser([{.Numeric}, {.Str}]);

        %!args = %!args.map({ $_.key => to-unquoted($_.value) }).Hash;

        %!args = $ep.process(%!args);

        return %!args;
    }
}

my class Magic::OpenAI is Magic::LLM {
    method preprocess($code) {
        # Process arguments
        self.pre-process-args;

        self.args = %(max-tokens => 300, format => 'values') , self.args;

        # Call LLM's interface function
        my $res = openai-completion($code, type => 'text', |self.args);

        # Copy to clipboard
        if $*DISTRO eq 'macos' {
            copy-to-clipboard($res);
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => 'text/plain',
                stdout => $res,
                stdout-mime-type => 'text/plain',
                ;
    }
}

my class Magic::OpenAIDallE is Magic::LLM {
    method preprocess($code) {

        # Process arguments
        self.pre-process-args;

        self.args =
                %(response-format => 'b64_json',
                  n => 1,
                  size => 'small',
                  format => 'values',
                  method => 'tiny') , self.args;

        # Call LLM's interface function
        my @imgResB64 = |openai-create-image($code, |self.args);

        # Transform base64 images into HTML images
        my $res = @imgResB64.map({ from-base64($_) }).join("\n\n");

        # Result
        return Result.new:
                output => $res,
                output-mime-type => 'text/html',
                stdout => $res,
                stdout-mime-type => 'text/html',
                ;
    }
}

my class Magic::PaLM is Magic::LLM {
    method preprocess($code) {

        # Process arguments
        self.pre-process-args;

        self.args = %(max-tokens => 300, format => 'values') , self.args;

        # Call LLM's interface function
        my $res = palm-generate-text( $code, |self.args);

        # Copy to clipboard
        if $*DISTRO eq 'macos' {
            copy-to-clipboard($res);
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => 'text/plain',
                stdout => $res,
                stdout-mime-type => 'text/plain',
                ;
    }
}

my class Magic::Chat is Magic::LLM {
    has $.chat-id is rw;
    method preprocess($code) {

        # Process arguments
        self.pre-process-args;

        self.chat-id = self.args<chat-id> // 'NONE';

        self.args = %(conf => 'ChatPaLM', chat-id => self.chat-id) , self.args;

        #note 'self.args.raku : ' , self.args.raku;

        # Get chat object
        my $chatObj = %chats{self.chat-id} // llm-chat(|self.args);

        #note $chatObj;

        # Call LLM's interface function
        my $res = $chatObj.eval($code);

        # Make sure it is registered
        %chats{self.chat-id} = $chatObj;

        # Copy to clipboard
        if $*DISTRO eq 'macos' {
            copy-to-clipboard($res);
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => 'text/plain',
                stdout => $res,
                stdout-mime-type => 'text/plain',
                ;
    }
}

my class Magic::MermaidInk is Magic {
    method preprocess($code) {
        my $imgResB64 = mermaid-ink($code, format => 'md-image');

        my $res = from-base64($imgResB64);

        return Result.new:
                output => $res,
                output-mime-type => 'text/html',
                stdout => $res,
                stdout-mime-type => 'text/html',
                ;
    }
}

my class Magic::Run is Magic {
    has Str:D $.file is required;
    method preprocess($code is rw) {
        $.file or return Result.new:
                stdout => "Missing filename to run.",
                stdout-mime-type => 'text/plain';
        $.file.IO.e or
                return Result.new:
                        stdout => "Could not find file: {$.file}",
                        stdout-mime-type => 'text/plain';
        given $code {
            $_ = $.file.IO.slurp
                    ~ ( "\n" x so $_ )
                    ~ ( $_ // '')
        }
        return;
    }
}
class Magic::Filters is Magic {
    # Attributes match magic-params in grammar.
    has Magic::Filter $.out;
    has Magic::Filter $.stdout;
    method postprocess(:$result) {
        my $out = $.out;
        my $stdout = $.stdout;
        return $result but role {
            method stdout-mime-type { $stdout.mime-type }
            method output-mime-type { $out.mime-type }
            method output { $out.transform(callsame) }
            method stdout { $stdout.transform(callsame) }
        }
    }
}

class Magic::Always is Magic {
    has Str:D $.subcommand = '';
    has Str:D $.rest = '';

    method preprocess($code is rw) {
        my $output = '';
        given $.subcommand {
            when 'prepend' { $always.prepend.push($.rest.trim); }
            when 'append' { $always.append.push($.rest.trim); }
            when 'clear' {
                $always = Always.new;
                $output = 'Always actions cleared';
            }
            when 'show' {
                for $always.^attributes -> $attr {
                    $output ~= $attr.name.substr(2)~" = "~$attr.get_value($always).join('; ')~"\n";
                }
            }
        }
        return Result.new:
                output => $output,
                output-mime-type => 'text/plain';
    }
}

class Magic::AlwaysWorker is Magic {
    #= Applyer for always magics on each line
    method unmagicify($code is rw) {
        my $magic-action = Jupyter::Kernel::Magics.new.parse-magic($code);
        return $magic-action.preprocess($code) if $magic-action;
        return Nil;
    }

    method preprocess($code is rw) {
        my $pre = ''; my $post = '';
        for $always.prepend -> $magic-code {
            my $container = $magic-code;
            self.unmagicify($container);
            $pre ~= $container ~ ";\n";
        }
        for $always.append -> $magic-code {
            my $container = $magic-code;
            self.unmagicify($container);
            $post ~= ";\n" ~ $container;
        }
        $code = $pre ~ $code ~ $post;
        return Nil;
    }
}

grammar Magic::Grammar {
    rule TOP { <magic> }
    rule magic {
        [ '%%' | '#%' ]
        [ <args> || <simple> || <filter> || <always> ]
    }
    token simple {
        $<key>=[ 'javascript' | 'bash' | <mermaid> ]
    }
    token args {
        #|| $<key>=[ 'openai' | 'dalle' | 'palm' | 'chat' [ ['-' | '_' | ':'] <-[,;\s]>* ]? ] [\h* ',' \h* <magic-list-of-params> \h*]?
        || $<key>=[ 'openai' | 'dalle' | 'palm' | 'chat' ] [\h* ',' \h* <magic-list-of-params> \h*]?
        || $<key>='run' $<rest>=.*
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
    regex magic-list-of-params { <magic-assign-pair>+ % [ \h* ',' \h* ] }

    # Magic pair assignment
    regex magic-assign-pair { $<param>=([<.alpha> | '.' | '_' | '-']+) \h* '=' \h* $<value>=(<-[{},\s]>* | '{' ~ '}' <-[{}]>* | '⎡' ~ '⎦' <-[⎡⎦]>* ) }
}

class Magic::Actions {
    method TOP($/) { $/.make: $<magic>.made }
    method magic($/) {
        $/.make: $<simple>.made // $<filter>.made // $<args>.made // $<always>.made;
    }
    method simple($/) {
        given "$<key>" {
            when 'javascript' {
                $/.make: Magic::JS.new;
            }
            when 'bash' {
                $/.make: Magic::Bash.new;
            }
            when $_ ∈ <mermaid mmd> {
                $/.make: Magic::MermaidInk.new;
            }
        }
    }
    method args($/) {
        given ("$<key>") {
            when 'run' {
                $/.make: Magic::Run.new(file => trim ~$<rest>);
            }
            when 'openai' {
                my %args = $<magic-list-of-params>.made // %();
                $/.make: Magic::OpenAI.new(:%args);
            }
            when 'dalle' {
                my %args = $<magic-list-of-params>.made // %();
                $/.make: Magic::OpenAIDallE.new(:%args);
            }
            when 'palm' {
                my %args = $<magic-list-of-params>.made // %();
                $/.make: Magic::PaLM.new(:%args);
            }
            when 'chat' {
                my %args = $<magic-list-of-params>.made // %();
                my $chat-id = 'NONE';
                $/.make: Magic::Chat.new(:%args, :$chat-id);
            }
            when $_ ~~ / ^ chat ['-' | '_' | ':' ] .* / {
                my %args = $<magic-list-of-params>.made // %();
                my $chat-id = do with $_ ~~ / ^ chat ['-' | '_' | ':' ] (.*) $ / { $0.Str.trim; }
                $/.make: Magic::Chat.new(:%args, :$chat-id);
            }
        }
    }
    method always($/) {
        my $subcommand = ~$<subcommand> || 'prepend';
        my $rest = $<rest> ?? ~$<rest> !! '';
        $/.make: Magic::Always.new(
                subcommand => $subcommand,
                rest => $rest);
    }
    method filter($/) {
        my %args =
                |($<out>    ?? |(out => $<out>.made) !! Empty),
                |($<stdout> ?? |(stdout => $<stdout>.made) !! Empty);
        $/.make: Magic::Filters.new: |%args;
    }
    method mime($/) {
        $/.make: $<html>.made // $<markdown>.made // $<latex>.made // $<javascript>.made;
    }
    method html($/) {
        $/.make: Magic::Filter::HTML.new;
    }
    method markdown($/) {
        $/.make: Magic::Filter::Markdown.new;
    }
    method javascript($/) {
        $/.make: Magic::Filter::Javascript.new;
    }
    method latex($/) {
        my %args = :enclosure('');
        %args<enclosure> = ~$_ with $<enclosure>;
        $/.make: Magic::Filter::Latex.new(|%args);
    }

    method magic-list-of-params($/) {
        my %args = |$<magic-assign-pair>>>.made;
        make %args;
    }

    method magic-assign-pair($/) {
        make $<param>.Str => $<value>.Str;
    }
}

method parse-magic($code is rw) {
    my $magic-line = $code.lines[0] or return Nil;
    $magic-line ~~ /^ [ '#%' | '%%' ] / or return Nil;
    my $actions = Magic::Actions.new;
    my $match = Magic::Grammar.new.parse($magic-line,:$actions) or return Nil;
    # Parse full cell if always
    if $match<magic><always> {
        $match = Magic::Grammar.new.parse($code,:$actions);
        $code = '';
        # Parse only first line otherwise
    } else {
        $code .= subst( $magic-line, '');
        $code .= subst( /\n/, '');
    }
    return $match.made;
}

method find-magic($code is rw) {
    # Parse
    my $magic-action = self.parse-magic($code);
    # If normal line and there is always magics -> activate them
    if !$magic-action && ($always.prepend || $always.append) {
        return Magic::AlwaysWorker.new;
    }
    return $magic-action;
}
