unit class Jupyter::Chatbook::Magics;
use Jupyter::Chatbook::Response;
use Jupyter::Chatbook::Magic::Grammar;
use WWW::Gemini;
use WWW::LLaMA;
use WWW::MistralAI;
use WWW::OpenAI;
use WWW::PaLM;
use WWW::MermaidInk;
use WWW::WolframAlpha;
use Clipboard;  # copy-to-clipboard
use Text::SubParsers;
use LLM::Functions;
use LLM::Prompts;
use Image::Markup::Utilities; # image-from-base64
use Lingua::Translation::DeepL;
use JSON::Tiny; # That has to be refactored out, and use "JSON::Fast".

my class Result does Jupyter::Chatbook::Response {
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

# See the INIT block below
my %chats;

my @dalle-images;

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
    has $.output-mime-type is rw = 'text/plain';
    method pre-process-args() {
        my $ep = exact-parser([{.Numeric}, {.Str}]);

        %!args = %!args.map({ $_.key => to-unquoted($_.value) }).Hash;

        %!args = $ep.process(%!args);

        return %!args;
    }
}


my class Magic::LLaMA is Magic::LLM {
    method preprocess($code) {
        # This is the same implementation as Magic::OpenAI::preprocess,
        # except llama-completion is called instead of openai-completion.
        # But I consider it better to be a separate one.
        # Also, in principle Magic::OpenAI can be used if relevant base-url is given.
        # (LLaMA chat completion should adhere to OpenAI's chat completion.)
        # Process arguments
        self.pre-process-args;

        self.args = %(max-tokens => 2048, format => 'values') , self.args;

        # Call LLM's interface function
        my $res;
        try {
            $res = llama-completion($code, |self.args);
        }

        if $! {
            $res = "Cannot process request.";
            if $! ~~ X::AdHoc {
                $res ~= "\n" ~ $!.Str;
            }
        }

        # Copy to clipboard
        if $*DISTRO eq 'macos' {
            copy-to-clipboard($res);
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => self.output-mime-type,
                stdout => $res,
                stdout-mime-type => self.output-mime-type,
                ;
    }
}

my class Magic::MistralAI is Magic::LLM {
    method preprocess($code) {
        # Process arguments
        self.pre-process-args;

        self.args = %(max-tokens => 900, format => 'values') , self.args;

        # Call LLM's interface function
        my $res;
        try {
            $res = mistralai-chat-completion($code, |self.args);
        }

        if $! {
            $res = "Cannot process request.";
            if $! ~~ X::AdHoc {
                $res ~= "\n" ~ $!.Str;
            }
        }

        # Copy to clipboard
        if $*DISTRO eq 'macos' {
            copy-to-clipboard($res);
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => self.output-mime-type,
                stdout => $res,
                stdout-mime-type => self.output-mime-type,
                ;
    }
}

my class Magic::OpenAI is Magic::LLM {
    method preprocess($code) {
        # Process arguments
        self.pre-process-args;

        self.args = %(max-tokens => 900, format => 'values') , self.args;

        # Call LLM's interface function
        my $res;
        try {
            $res = openai-completion($code, |self.args);
        }

        if $! {
            $res = "Cannot process request.";
            if $! ~~ X::AdHoc {
                $res ~= "\n" ~ $!.Str;
            }
        }

        # Copy to clipboard
        if $*DISTRO eq 'macos' {
            copy-to-clipboard($res);
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => self.output-mime-type,
                stdout => $res,
                stdout-mime-type => self.output-mime-type,
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
                  size => Whatever,
                  format => 'values',
                  method => 'tiny') , self.args;

        my $prompt = self.args<prompt> // '';
        $prompt = to-unquoted($prompt);

        my $res = '';
        my @imgResB64;
        # Call LLM's interface function
        if $code.trim.starts-with('@') && $code.trim.substr(1).IO.f {

            try {
                my $file = $code.trim.substr(1).IO.absolute.Str;
                if $prompt {
                    self.args<prompt>:delete;
                    @imgResB64 = |openai-edit-image($file, $prompt, |self.args);
                } else {
                    @imgResB64 = |openai-variate-image($file, |self.args);
                }
            }

            if $! || !(@imgResB64.all ~~ Str) {
                $res = "Cannot process file -- non-image result:\n" ~ @imgResB64.raku;
                @imgResB64 = Empty;
            }

        } else {
            if self.args<response-format> eq 'b64_json' {
                try {
                    @imgResB64 = |openai-create-image($code, |self.args);
                }

                if $! || !(@imgResB64.all ~~ Str) {
                    $res = "Cannot process request.";
                    if $! ~~ X::AdHoc {
                        $res ~= "\n" ~ $!.Str;
                    }
                    @imgResB64 = Empty;
                }
            } else {
                try {
                    $res = openai-create-image($code, |self.args);
                }

                if $! {
                    $res = "Cannot process request.";
                    if $! ~~ X::AdHoc {
                        $res ~= "\n" ~ $!.Str;
                    }
                    @imgResB64 = Empty;
                } else {
                    # Copy to clipboard
                    if $*DISTRO eq 'macos' {
                        copy-to-clipboard($res);
                    }
                }
            }
        }

        # Transform base64 images into HTML images
        if @imgResB64 {
            @dalle-images.append(@imgResB64);
            $res = @imgResB64.map({ image-from-base64($_) }).join("\n\n");
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => 'text/html',
                stdout => $res,
                stdout-mime-type => 'text/html',
                ;
    }
}

my class Magic::OpenAIDallEMeta is Magic::LLM {
    has $.meta-command is rw;
    method preprocess($code) {

        my $mimeType = 'text/plain';

        # Process arguments
        self.pre-process-args;

        # Redirecting to drop or clear
        if $.meta-command eq 'meta' {
            if $code.trim ∈ <drop delete> {
                $.meta-command = 'drop'
            } elsif $code.trim ∈ <clear empty> {
                $.meta-command = 'clear'
            }
        }

        my $index = self.args<index> // Whatever;
        my $sep = self.args<sep> // ' ';
        my $prefix = self.args<prefix> // 'dalle';

        # Process commands
        my $res;
        given $.meta-command {
            when 'meta' {
                if @dalle-images {

                    my @knownMethods = <elems gist raku show>;
                    $res = do given $code.trim {
                        when $_ ∈ ['elems', '.elems', '».elems', '>>.elems'] {
                            @dalle-images.elems;
                        }
                        when $_ ∈ <show show-all display display-all> {
                            $mimeType = 'text/html';
                            @dalle-images.map({ image-from-base64($_) }).join($sep);
                        }
                        when $_ ∈ @knownMethods {
                            @dalle-images."$_"();
                        }
                        default {
                            "Do not know how to process {$_.raku}. The known DALL-E images object methods are: {@knownMethods.raku}.\nContinuing with .elems.\n\n" ~ @dalle-images.elems;
                        }
                    }

                } else {
                    $res = "No stored DALL-E images.";
                }
            }

            when 'export' {
                if @dalle-images {
                    my $path = $code.trim;
                    $path .= subst(/ ^ '@'/);

                    if $path.chars == 0 {
                        $path = $*CWD ~ "/$prefix-" ~ now.DateTime.Str.subst(':','.', :g) ~ '.png';
                    }
                    my $copyToClipboard = False;
                    try {
                        if $index.isa(Whatever) {
                            $res = image-export($path, @dalle-images.tail);
                        } elsif $index ~~ Str:D && $index.lc eq 'all' {
                            $res = do for ^@dalle-images.elems -> $k {
                                my $path2 = $path.subst(/ '.png' $ /, "-$k.png");
                                image-export($path2, @dalle-images[$k]);
                            }
                            $copyToClipboard = True;
                        } elsif $index ~~ Int:D && 0 ≤ $index ≤ @dalle-images.elems {
                            $res = image-export($path, @dalle-images[$index]);
                            $copyToClipboard = True;
                        } elsif $index ~~ Numeric:D {
                            $res = "The value of the option index is expeced to be Whatever or an integer between 0 and {@dalle-images.elems}.";
                        } else {
                            $res = 'Do not know how to process the given index.';
                        }
                    }
                    if $! ~~ X::AdHoc {
                        $res ~= "\n" ~ $!.Str;
                    } elsif $copyToClipboard {
                        # Copy to clipboard
                        if $*DISTRO eq 'macos' {
                            copy-to-clipboard($res);
                        }
                    }
                } else {
                    $res = 'No images to export.';
                }
            }

            when 'drop' {
                if @dalle-images {
                    @dalle-images.pop;
                    $res = "Deleted the last image; {@dalle-images.elems} " ~ (@dalle-images.elems == 1 ?? 'is' !! 'are')  ~ ' left.';
                } else {
                    $res = "No stored images -- nothing to drop.";
                }
            }

            when 'clear' {
                if @dalle-images {
                    $res = "Cleared {@dalle-images.elems} images.";
                    @dalle-images = [];
                } else {
                    $res = "No stored images -- nothing to clear.";
                }
            }

            default {
                $res = "Do not know how to process the chat meta command $_.";
            }
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => $mimeType,
                stdout => $res,
                stdout-mime-type => $mimeType,
                ;
    }
}

my class Magic::PaLM is Magic::LLM {
    method preprocess($code) {

        # Process arguments
        self.pre-process-args;

        self.args = %(max-tokens => 900, format => 'values') , self.args;

        # Call LLM's interface function
        my $res;
        try {
            $res = palm-generate-text( $code, |self.args);
        }

        if $! {
            $res = "Cannot process request.";
            if $! ~~ X::AdHoc {
                $res ~= "\n" ~ $!.Str;
            }
        }

        # Copy to clipboard
        if $*DISTRO eq 'macos' {
            copy-to-clipboard($res);
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => self.output-mime-type,
                stdout => $res,
                stdout-mime-type => self.output-mime-type,
                ;
    }
}


my class Magic::Gemini is Magic::LLM {
    method preprocess($code) {

        # Process arguments
        self.pre-process-args;

        self.args = %(max-tokens => 2048, format => 'values') , self.args;

        # Call LLM's interface function
        my $res;
        try {
            $res = gemini-generate-content( $code, |self.args);
        }

        if $! {
            $res = "Cannot process request.";
            if $! ~~ X::AdHoc {
                $res ~= "\n" ~ $!.Str;
            }
        }

        # Copy to clipboard
        if $*DISTRO eq 'macos' {
            copy-to-clipboard($res);
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => self.output-mime-type,
                stdout => $res,
                stdout-mime-type => self.output-mime-type,
                ;
    }
}

my class Magic::Chat is Magic::LLM {
    has $.chat-id is rw;
    method preprocess($code) {

        # Process arguments
        self.pre-process-args;

        self.chat-id = self.chat-id // self.args<chat-id> // 'NONE';

        # Expand the prompt if given
        my $prompt = self.args<prompt> // '';
        if $prompt {
            # I am not sure is this better:
            # $prompt = llm-prompt-expand($prompt, messages => %chats{self.chat-id}.messages.map({ $_.<content> }).Array // Empty, sep => "\n");
            $prompt = llm-prompt-expand($prompt);
            self.args<prompt> = $prompt;
        }

        # Warn if an existing chat-id is used and are also given a prompt and configuration spec
        if ( (self.args<prompt> // False) || (self.args<conf> // False) ) && (%chats{self.chat-id}:exists) {
            note "No new chat object is created.\nUsing chat object with id: ⎡{self.chat-id}⎦, and number of messages: {%chats{self.chat-id}.messages.elems}.";
        }

        # Merge magic arguments with defaults
        self.args = %(conf => 'ChatGPT', chat-id => self.chat-id) , self.args;

        # Get chat object
        my $chatObj = %chats{self.chat-id} // llm-chat(|self.args);

        # We get a  delimiter from the configuration
        # my $sep = $chatObj.llm-evaluator.conf.prompt-delimiter;
        # But for prompt expansions it is most like better to use new line
        my $sep = "\n";

        # Call LLM's interface function
        my $res;
        try {
            $res = $chatObj.eval(llm-prompt-expand($code, messages => $chatObj.messages.map({ $_<content> }).Array, :$sep));
        }

        if $! {
            note "Cannot process the input with chat object's LLM evaluator.";
            $res = $!.payload;
        }

        # Make sure it is registered
        %chats{self.chat-id} = $chatObj;

        # Copy to clipboard
        if $*DISTRO eq 'macos' {
            copy-to-clipboard($res);
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => self.output-mime-type,
                stdout => $res,
                stdout-mime-type => self.output-mime-type,
                ;
    }
}

my class Magic::ChatMeta is Magic::Chat {
    has $.meta-command is rw;
    method preprocess($code) {

        # Process arguments
        self.pre-process-args;

        self.chat-id = self.chat-id // self.args<chat-id> // 'NONE';

        # Redirecting to drop or clear
        if $.meta-command eq 'meta' {
            if $code.trim ∈ <drop delete> {
                $.meta-command = 'drop'
            } elsif $code.trim ∈ <clear empty> {
                $.meta-command = 'clear'
            }
        }

        # Process commands
        my $res;
        given $.meta-command {
            when 'meta' {
                if %chats{self.chat-id}:exists {
                    # Get chat object
                    my $chatObj = %chats{self.chat-id};

                    my @knownMethods = <Str gist raku say chat-id drop llm-evaluator llm-configuration conf messages prompt examples>;
                    $res = do given $code.trim {
                        when 'raku' {
                            $chatObj.raku
                        }
                        when 'messages' {
                            $chatObj.messages.map({ $_.Str }).List
                        }
                        when 'llm-evaluator' {
                            $chatObj.llm-evaluator.raku
                        }
                        when $_ ∈ <llm-configuration conf> {
                            $chatObj.llm-evaluator.conf.raku
                        }
                        when $_ ∈ @knownMethods {
                            $chatObj."$_"().raku;
                        }
                        default {
                            "Do not know how to process '{$_.raku}'. The known chat object methods are: {@knownMethods.raku}.\nContinuing with .gist.\n\n" ~ $chatObj.gist;
                        }
                    }
                } else {
                    $res = "Cannot find a chat object with ID: {self.chat-id}.";
                }
            }

            when 'prompt' {
                my $code2 = llm-prompt-expand($code);

                self.args = %(prompt => $code2, conf => 'ChatGPT', chat-id => self.chat-id) , self.args;

                my $chatObj = llm-chat(|self.args);

                %chats{self.chat-id} = $chatObj;

                $res = "Chat object created with ID : {self.chat-id}.";
                if $code ne $code2 {
                    $res ~= "\nExpanded prompt:\n⎡$code2⎦";
                }
            }

            when 'drop' {
                if %chats{self.chat-id}:exists {
                    $res = "Deleted: { self.chat-id }\nGist: { %chats{self.chat-id}.gist }";
                    %chats{self.chat-id}:delete;
                } else {
                    $res = "Cannot find chat with ID : { self.chat-id }";
                }
            }

            when 'clear' {
                if %chats{self.chat-id}:exists {
                    %chats{self.chat-id}.messages = [];
                    $res = "Cleared messages of: { self.chat-id }\nGist: { %chats{self.chat-id}.gist }";
                } else {
                    $res = "Cannot find chat with ID : { self.chat-id }";
                }
            }

            when 'all' {
                if %chats {

                    my @knownMethods = <keys values pairs Str gist>;
                    $res = do given $code.trim {
                        when 'values' {
                            %chats.values.map({ $_.Str }).List
                        }
                        when 'pairs' {
                            %chats.map({ $_.key => $_.value.Str }).List
                        }
                        when $_ ∈ @knownMethods {
                            %chats."$_"();
                        }
                        default {
                            "Do not know how to process {$_.raku} over the Hash of known chat objects.\nContinuing with .gist.\n\n" ~ %chats.gist;
                        }
                    }
                } else {
                    $res = "No chat objects.";
                }
            }

            default {
                $res = "Do not know how to process the chat meta command $_.";
            }
        }


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
    has %.args;
    has $.output-mime-type is rw = 'text/html';
    method preprocess($code) {

        my $format = self.args<format> // 'svg';

        my $background = self.args<background> // 'FFFFFF';

        my $res = do given $format {
            when $_.lc ∈ <md-image image img base64 markdown-image> {
                my $imgResB64 = mermaid-ink($code, format => 'md-image', :$background);
                # Is this needed?
                image-from-base64($imgResB64);
            }

            when $_.lc ∈ <svg vector scalable-vector-graphics url md-url> {
                mermaid-ink($code, :$format, :$background);
            }

            when $_.lc ∈ <hash raku> {
                mermaid-ink($code, :$format, :$background);
            }

            default {
                "Unknown format. Known formats: <image svg hash>."
            }
        };

        return Result.new:
                output => $res,
                output-mime-type => self.output-mime-type,
                stdout => $res,
                stdout-mime-type => self.output-mime-type,
                ;
    }
}

my class Magic::DeepL is Magic {
    has %.args;
    has $.output-mime-type is rw = 'text/html';
    method preprocess($code) {

        # Process arguments
        my $format = self.args<format> // 'text';
        my $format2 = ($format.lc ∈ <values value text> ?? 'hash' !! $format);

        self.args<format> = $format2;

        # Call DeepL's interface function
        my $res;
        try {
            $res = deepl-translation( $code, |self.args);
        }

        if $! {
            $res = "Cannot process request.";
            if $! ~~ X::AdHoc {
                $res ~= "\n" ~ $!.Str;
            }
        }

        # Post process
        $res = do given $format.lc {
            when $_ ∈ <hash raku> { $res.raku }
            when $_ ∈ <values value text> {
                if $res ~~ Iterable && $res.elems > 0 && $res.head ~~ Map && ($res.head<text>:exists) {
                    $res.head<text>;
                } else {
                    $res.raku;
                }
            }
            default { $res; }
        }

        # Copy to clipboard
        if $*DISTRO eq 'macos' {
            copy-to-clipboard($res);
        }

        # Result
        return Result.new:
                output => $res,
                output-mime-type => self.output-mime-type,
                stdout => $res,
                stdout-mime-type => self.output-mime-type,
                ;
    }
}

my class Magic::WolframAlpha is Magic {
    has %.args;
    has $.output-mime-type is rw = 'text/html';
    method preprocess($code) {

        my $path = self.args<path> // self.args<type> // 'simple';

        my %args = self.args.grep({ $_.key ∉ <path type format header-level plaintext> });

        my $mimeType = self.output-mime-type;

        my $res = do given $path {
            when $_.lc ∈ <result short> {
                $mimeType = 'text/plain';
                wolfram-alpha-result($code, |%args);
            }

            when $_.lc ∈ <simple> {
                my $imgResB64 = wolfram-alpha-simple($code, format => 'md-image', |%args);
                image-from-base64($imgResB64);
            }

            when $_.lc ∈ <query pods> {
                $mimeType = 'text/markdown';

                my $header-level = self.args<header-level> // 4;
                $header-level = try { $header-level.Int };
                if $! { $header-level = 4; }

                my $plaintext = self.args<plaintext> // "False";
                $plaintext = $plaintext.Str.lc ∈ <yes true> ?? True !! False;

                my $res = wolfram-alpha-query($code, |%args);
                try {
                   $res = wolfram-alpha-pods-to-markdown($res, :$header-level, :$plaintext);
                }
                if $! { "No available answer." } else { $res }
            }

            default {
                "Unknown type (aka path). Known types: <result simple query>."
            }
        };

        return Result.new:
                output => $res,
                output-mime-type => $mimeType,
                stdout => $res,
                stdout-mime-type => $mimeType,
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
        my $magic-action = Jupyter::Chatbook::Magics.new.parse-magic($code);
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

class Magic::Actions {
    method TOP($/) { $/.make: $<magic>.made }
    method magic($/) {
        $/.make:
                $<simple>.made // $<filter>.made // $<llm-args>.made // $<mermaid-args>.made // $<deepl-args>.made //
                        $<wolfram-alpha-args>.made // $<args>.made // $<chat-id-spec>.made // $<chat-meta-spec>.made //
                        $<dalle-meta-spec>.made // $<always>.made;
    }
    method simple($/) {
        given "$<key>" {
            when 'javascript' {
                $/.make: Magic::JS.new;
            }
            when 'bash' {
                $/.make: Magic::Bash.new;
            }
        }
    }
    method args($/) {
        given ("$<key>") {
            when 'run' {
                $/.make: Magic::Run.new(file => trim ~$<rest>);
            }
        }
    }
    method mermaid-args($/) {
        my %args = $<magic-list-of-params>.made // %();
        my $output-mime-type = $<output-mime>.made.mime-type // 'text/html';
        $/.make: Magic::MermaidInk.new(:%args, :$output-mime-type);
    }
    method deepl-args($/) {
        my %args = $<magic-list-of-params>.made // %();
        my $output-mime-type = $<output-mime>.made.mime-type // 'text/plain';
        $/.make: Magic::DeepL.new(:%args, :$output-mime-type);
    }
    method wolfram-alpha-args($/) {
        my %args = $<magic-list-of-params>.made // %();
        my $output-mime-type = $<output-mime>.made.mime-type // 'text/html';
        $/.make: Magic::WolframAlpha.new(:%args, :$output-mime-type);
    }
    method llm-args($/) {
        my %args = $<magic-list-of-params>.made // %();
        my $output-mime-type = $<output-mime>.made.mime-type // 'text/plain';

        given ("$<key>") {
            when 'gemini' {
                $/.make: Magic::Gemini.new(:%args, :$output-mime-type);
            }
            when 'llama' {
                $/.make: Magic::LLaMA.new(:%args, :$output-mime-type);
            }
            when 'mistralai' {
                $/.make: Magic::MistralAI.new(:%args, :$output-mime-type);
            }
            when 'openai' {
                $/.make: Magic::OpenAI.new(:%args, :$output-mime-type);
            }
            when 'dalle' {
                $/.make: Magic::OpenAIDallE.new(:%args, :$output-mime-type);
            }
            when 'palm' {
                $/.make: Magic::PaLM.new(:%args, :$output-mime-type);
            }
            when 'chat' {
                my $chat-id = 'NONE';
                $/.make: Magic::Chat.new(:%args, :$chat-id, :$output-mime-type);
            }
        }
    }
    method chat-id-spec($/) {
        my $chat-id = $<chat-id>.Str;
        my %args = $<magic-list-of-params>.made // %();
        my $output-mime-type = $<output-mime>.made.mime-type // 'text/plain';
        $/.make: Magic::Chat.new(:%args, :$chat-id, :$output-mime-type);
    }
    method chat-meta-spec($/) {
        my $chat-id = $<chat-id> ?? $<chat-id>.Str !! 'NONE';
        my %args = $<magic-list-of-params>.made // %();

        my $meta-command = $<meta-command>.Str;
        $/.make: Magic::ChatMeta.new(:%args, :$chat-id, :$meta-command);
    }
    method dalle-meta-spec($/) {
        my %args = $<magic-list-of-params>.made // %();

        my $meta-command = $<meta-command>.Str;
        $/.make: Magic::OpenAIDallEMeta.new(:%args, :$meta-command);
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
    my $match = Jupyter::Chatbook::Magic::Grammar.new.parse($magic-line,:$actions) or return Nil;
    # Parse full cell if always
    if $match<magic><always> {
        $match = Jupyter::Chatbook::Magic::Grammar.new.parse($code,:$actions);
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

INIT {
    my $base = %*ENV<XDG_HOME> // $*HOME.child('.local');
    $base = $base.child('share').child('raku').child('Chatbook') // $*HOME.child('.local');
    my $conf-file = %*ENV<CHATBOOK_LLM_PERSONAS_CONF> // $base.child('llm-personas.json');
    if $conf-file.IO.e {
        #note "Reading configuration from $conf-file";
        try {
            my @specs = |from-json($conf-file.IO.slurp);
            if @specs ~~ (List:D | Array:D | Seq:D) && @specs.all ~~ Map:D {
                # Merge magic arguments with defaults
                my %personas = do for @specs.kv -> $i, %p {
                    # Merge with defaults
                    my %h = %(conf => 'ChatGPT', chat-id => "p$i" ), %p;
                    # Expand prompt
                    if %h<prompt>:exists {
                        %h<prompt> = llm-prompt-expand(%h<prompt>)
                    }
                    # Make a chat object
                    %h<chat-id> => llm-chat(|%h);
                }
                %chats = %personas;
            }
        }
    }
}